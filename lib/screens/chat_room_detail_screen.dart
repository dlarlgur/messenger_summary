import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../services/local_db_service.dart';
import '../services/llm_service.dart';
import '../services/notification_settings_service.dart';
import '../services/profile_image_service.dart';
import '../services/privacy_masking_service.dart';
import '../config/constants.dart';
import 'summary_history_screen.dart';

class ChatRoomDetailScreen extends StatefulWidget {
  final ChatRoom room;

  const ChatRoomDetailScreen({super.key, required this.room});

  @override
  State<ChatRoomDetailScreen> createState() => _ChatRoomDetailScreenState();
}

class _ChatRoomDetailScreenState extends State<ChatRoomDetailScreen> with WidgetsBindingObserver {
  final LocalDbService _localDb = LocalDbService();
  final ProfileImageService _profileService = ProfileImageService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _chatInputBarKey = GlobalKey();
  static const MethodChannel _methodChannel = MethodChannel('com.example.chat_llm/notification');
  static const EventChannel _eventChannel = EventChannel('com.example.chat_llm/notification_stream');
  
  double _chatInputBarHeight = 0;

  List<MessageItem> _messages = [];
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  // 실시간 메시지 동기화
  StreamSubscription? _notificationSubscription;
  int _newMessageCount = 0;  // 새로 온 메시지 개수
  String? _latestNewMessageSender;  // 가장 최근 새 메시지 보낸사람
  String? _latestNewMessageContent;  // 가장 최근 새 메시지 내용
  bool _isAtBottom = true;   // 스크롤이 맨 아래에 있는지
  bool _hasReceivedNewMessage = false;  // 화면에 있는 동안 새 메시지를 받았는지 여부
  
  // 스크롤 날짜 인디케이터
  DateTime? _visibleDate;  // 현재 화면에 보이는 메시지의 날짜

  // 요약 모드 상태
  bool _isSummaryMode = false;  // 요약 모드 활성화 여부
  int _selectedMessageCount = 0;  // 선택된 메시지 개수 (최신 메시지부터 위로 N개)
  int _defaultSummaryCount = 5;  // 기본 요약 개수

  // 카톡 스타일 메시지 선택 상태
  int? _selectionStartIndex;  // 선택 시작 메시지 인덱스
  bool _isDraggingSelection = false;  // 드래그 중인지 여부
  bool _isDragHandleVisible = false;  // 드래그 핸들 표시 여부

  // 검색 모드 상태
  bool _isSearchMode = false;  // 검색 모드 활성화 여부
  String? _selectedSender;  // 선택된 사용자 (null이면 전체 검색)
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<int> _searchResults = [];  // 검색 결과 인덱스 리스트
  int _currentSearchIndex = -1;  // 현재 검색 결과 인덱스
  DateTime? _lastSelectedDate;  // 마지막으로 선택한 날짜 (날짜 선택 다이얼로그에서 사용)

  // 채팅 입력창
  final TextEditingController _chatInputController = TextEditingController();

  static const int _pageSize = 50;

  /// 메시지 높이 추정 (메시지 내용 길이 기반)
  double _estimateMessageHeight(MessageItem message) {
    // 기본 높이: 프로필(40) + 패딩(16) + 이름(18) + 기본 버블(40)
    const double baseHeight = 80.0;
    // 글자 수에 따른 추가 높이 (한 줄당 약 20자, 줄당 20px)
    final int charCount = message.message.length;
    final int estimatedLines = (charCount / 25).ceil().clamp(1, 20);
    final double textHeight = (estimatedLines - 1) * 20.0;
    return baseHeight + textHeight;
  }

  /// 인덱스까지의 누적 스크롤 오프셋 계산
  double _calculateScrollOffset(int targetIndex) {
    double offset = 0.0;
    for (int i = 0; i < targetIndex && i < _messages.length; i++) {
      offset += _estimateMessageHeight(_messages[i]);
      // 날짜 구분선이 있으면 추가 높이
      if (_shouldShowDate(i)) {
        offset += 40.0; // 날짜 구분선 높이
      }
    }
    return offset;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initProfileService();
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(_checkScrollPosition);
    _loadMessages();
    _startListeningNotifications();
    
    // 개인정보 마스킹 서비스 세션 초기화 (채팅방이 바뀔 때마다)
    PrivacyMaskingService().resetSession();
    
    // 채팅 입력창 높이 측정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureChatInputBarHeight();
    });
  }
  
  void _measureChatInputBarHeight() {
    if (!mounted) return;
    if (_chatInputBarKey.currentContext != null) {
      final RenderBox? renderBox = _chatInputBarKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final height = renderBox.size.height;
        if (height != _chatInputBarHeight) {
          if (mounted) {
            setState(() {
              _chatInputBarHeight = height;
            });
          }
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 앱이 포그라운드로 돌아올 때 새 메시지 확인
    if (state == AppLifecycleState.resumed) {
      if (!mounted) return;
      debugPrint('🔄 ChatRoomDetailScreen: 앱 포그라운드 복귀 - 새 메시지 확인');
      _loadNewMessages();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 대화방을 나갈 때 무조건 읽음 처리 (카카오톡처럼 들어갔다 나오면 읽음)
    // 화면에 있는 동안 새 메시지가 왔으면, 확인하지 않아도 읽음 처리
    // 비동기 작업이지만 fire-and-forget으로 실행
    debugPrint('🔄 dispose 시 읽음 처리 시도 (roomId: ${widget.room.id})');
    _localDb.markRoomAsRead(widget.room.id).then((_) {
      debugPrint('✅ dispose 시 읽음 처리 완료');
    }).catchError((e) {
      debugPrint('❌ dispose 시 읽음 처리 실패: $e');
    });
    
    _notificationSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.removeListener(_checkScrollPosition);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _chatInputController.dispose();
    super.dispose();
  }

  Future<void> _initProfileService() async {
    try {
      await _profileService.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ ProfileImageService 초기화 실패: $e');
    }
  }

  /// 스크롤 위치 확인 (맨 아래인지, 현재 보이는 날짜)
  void _checkScrollPosition() {
    if (!_scrollController.hasClients || _messages.isEmpty) return;
    
    // reverse: true이므로 position.pixels가 0에 가까우면 맨 아래(최신 메시지)
    final isAtBottom = _scrollController.position.pixels < 100;
    
    // 현재 스크롤 위치에서 보이는 메시지 인덱스 계산
    // reverse: true이므로 offset이 클수록 위로 스크롤 (오래된 메시지)
    // 화면 중앙에 보이는 메시지를 찾기 위해 화면 높이의 절반을 더함
    final scrollOffset = _scrollController.position.pixels;
    final screenHeight = MediaQuery.of(context).size.height;
    final viewportCenter = scrollOffset + (screenHeight * 0.5);
    
    int visibleIndex = 0;
    double accumulatedHeight = 0.0;
    
    // reverse: true이므로 index 0부터 시작하여 누적 높이 계산
    for (int i = 0; i < _messages.length; i++) {
      final messageHeight = _estimateMessageHeight(_messages[i]);
      final dateHeight = _shouldShowDate(i) ? 40.0 : 0.0;
      final totalHeight = messageHeight + dateHeight;
      
      accumulatedHeight += totalHeight;
      
      // 누적 높이가 뷰포트 중앙을 넘으면 해당 메시지가 화면 중앙에 보임
      if (accumulatedHeight >= viewportCenter) {
        visibleIndex = i;
        break;
      }
      
      // 마지막 메시지까지 도달한 경우
      if (i == _messages.length - 1) {
        visibleIndex = i;
      }
    }
    
    // 보이는 메시지의 날짜 추출
    final visibleMessage = _messages[visibleIndex.clamp(0, _messages.length - 1)];
    final newVisibleDate = DateTime(
      visibleMessage.createTime.year,
      visibleMessage.createTime.month,
      visibleMessage.createTime.day,
    );
    
    if (isAtBottom != _isAtBottom || _visibleDate != newVisibleDate) {
      if (!mounted) return;
      final wasAtBottom = _isAtBottom;
      setState(() {
        _isAtBottom = isAtBottom;
        _visibleDate = newVisibleDate;
        // 맨 아래로 스크롤하면 새 메시지 정보 초기화
        if (isAtBottom) {
          _newMessageCount = 0;
          _latestNewMessageSender = null;
          _latestNewMessageContent = null;
        }
      });
      
      // 스크롤이 맨 아래로 내려갔을 때 읽음 처리
      if (!wasAtBottom && isAtBottom) {
        _checkAndMarkAsReadIfAtBottom();
      }
    }
  }

  /// 알림 스트림 구독 시작
  void _startListeningNotifications() {
    _notificationSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final data = Map<String, dynamic>.from(event);
          final eventType = data['type'] ?? 'notification';
          
          if (eventType == 'room_updated') {
            _handleRoomUpdate(data);
          } else if (eventType == 'notification') {
            // 일반 알림도 처리하여 현재 대화방 메시지 자동 업데이트
            _handleNotification(data);
          }
        }
      },
      onError: (error) {
        debugPrint('알림 스트림 에러: $error');
      },
    );
  }

  /// 일반 알림 처리 (현재 대화방에 대한 알림인지 확인 후 메시지 업데이트)
  void _handleNotification(Map<String, dynamic> data) {
    final packageName = data['packageName'] ?? '';
    final subText = data['subText'] ?? '';
    final sender = data['title'] ?? '';
    
    // 현재 대화방과 같은 패키지인지 확인
    if (packageName != widget.room.packageName) return;
    
    // roomName 추출 (개인톡: sender, 그룹톡: subText)
    final roomName = subText.isNotEmpty ? subText : sender;
    
    // 현재 대화방에 대한 알림인지 확인
    if (roomName != widget.room.roomName) return;
    
    debugPrint('📩 현재 대화방에 새 알림 도착: $roomName');
    
    // 새 메시지 로드 (DB에 이미 저장되어 있을 것)
    _loadNewMessages();
  }

  /// 채팅방 업데이트 처리
  void _handleRoomUpdate(Map<String, dynamic> data) {
    final roomName = data['roomName'] as String? ?? '';
    
    // 현재 대화방에 대한 업데이트인지 확인
    if (roomName != widget.room.roomName) return;
    
    debugPrint('📩 현재 대화방에 새 메시지 도착: $roomName');
    
    // 새 메시지 로드
    _loadNewMessages();
  }

  /// 새 메시지만 로드 (최신 메시지 가져오기)
  Future<void> _loadNewMessages() async {
    if (_isLoading || _isLoadingMore) return;
    
    try {
      final response = await _localDb.getRoomMessages(
        widget.room.id,
        page: 0,
        size: 20,  // 최신 20개만 가져오기
      );
      
      if (response == null || response.messages.isEmpty) return;
      if (!mounted) return;
      
      // 현재 메시지 ID 집합 (중복 체크용)
      final existingMessageIds = _messages.map((msg) => msg.messageId).toSet();
      
      // 현재 가장 최신 메시지의 시간 (시간 비교용)
      final latestTime = _messages.isNotEmpty ? _messages.first.createTime : DateTime(1970);
      
      // 새로운 메시지만 필터링 (ID 중복 체크 + 시간 비교)
      final newMessages = response.messages.where((msg) {
        // ID로 중복 체크 (더 정확함)
        if (existingMessageIds.contains(msg.messageId)) return false;
        // 시간 비교 (같은 시간도 포함하도록 >= 사용)
        return msg.createTime.compareTo(latestTime) >= 0;
      }).toList();
      
      if (newMessages.isEmpty) return;
      
      debugPrint('📩 새 메시지 ${newMessages.length}개 추가');
      
      if (!mounted) return;
      setState(() {
        // 새 메시지를 맨 앞에 추가 (reverse 리스트이므로)
        _messages.insertAll(0, newMessages);

        // 프로필 캐시 무효화 (새 프로필 이미지 반영)
        for (final msg in newMessages) {
          _profileService.invalidateSenderProfile(
            widget.room.packageName,
            widget.room.roomName,
            msg.sender,
          );
        }

        // 새 메시지를 받았음을 표시 (dispose 시 읽음 처리용)
        _hasReceivedNewMessage = true;

        // 스크롤이 맨 아래가 아니면 새 메시지 카운트 증가 및 최신 메시지 정보 저장
        if (!_isAtBottom) {
          _newMessageCount += newMessages.length;
          // 가장 최근 새 메시지 정보 저장 (newMessages의 첫 번째가 가장 최신)
          final latestMsg = newMessages.first;
          _latestNewMessageSender = latestMsg.sender;
          _latestNewMessageContent = latestMsg.message;
        }
      });
      
      // 스크롤이 맨 아래에 있으면 자동 스크롤 및 읽음 처리
      if (_isAtBottom && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
            // 스크롤이 맨 아래에 있으므로 읽음 처리
            _checkAndMarkAsReadIfAtBottom();
          }
        });
      }
    } catch (e) {
      debugPrint('새 메시지 로드 실패: $e');
    }
  }

  /// 메시지 전송
  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    
    try {
      // Android 네이티브로 메시지 전송 요청
      final success = await _methodChannel.invokeMethod<bool>(
        'sendMessage',
        {
          'roomId': widget.room.id,
          'message': message,
        },
      );
      
      if (success == true) {
        // 전송 성공 - DB에 메시지 저장
        final now = DateTime.now();
        try {
          await _localDb.saveMessage(
            roomId: widget.room.id,
            sender: '나',
            message: message,
            createTime: now,
            roomName: widget.room.roomName,
          );
          debugPrint('✅ 메시지 DB 저장 완료: $message');
        } catch (e) {
          debugPrint('⚠️ 메시지 DB 저장 실패: $e');
        }
        
        // 전송 성공 - 로컬에 메시지 추가 (임시로 표시)
        final myMessage = MessageItem(
          messageId: -1, // 임시 ID
          sender: '나', // 내가 보낸 메시지 표시
          message: message,
          createTime: now,
        );
        
        if (mounted) {
          setState(() {
            _messages.insert(0, myMessage);
          });
          
          // 입력창 초기화
          _chatInputController.clear();
          
          // 맨 아래로 스크롤
          _scrollToBottom();
        }
        
        debugPrint('✅ 메시지 전송 성공: $message');
      } else {
        debugPrint('❌ 메시지 전송 실패');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('메시지 전송에 실패했습니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ 메시지 전송 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('메시지 전송 중 오류가 발생했습니다: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  /// 맨 아래로 스크롤
  void _scrollToBottom() {
    if (!mounted) return;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      if (mounted) {
        setState(() {
          _newMessageCount = 0;
          _latestNewMessageSender = null;
          _latestNewMessageContent = null;
        });
      }
      // 스크롤이 맨 아래로 내려갔으므로 읽음 처리
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndMarkAsReadIfAtBottom();
        }
      });
    }
  }

  /// 스크롤이 맨 아래에 있으면 읽음 처리
  Future<void> _checkAndMarkAsReadIfAtBottom() async {
    if (_messages.isEmpty) return;
    
    // 스크롤 컨트롤러가 아직 초기화되지 않은 경우 (메시지가 적어서 스크롤이 없는 경우)
    // 또는 스크롤이 맨 아래에 있는 경우 읽음 처리
    bool shouldMarkAsRead = false;
    
    if (!_scrollController.hasClients) {
      // 스크롤 컨트롤러가 없으면 메시지가 적어서 스크롤이 필요 없는 상태
      // 이 경우 화면에 모든 메시지가 보이므로 읽음 처리
      shouldMarkAsRead = true;
    } else {
      // 스크롤이 맨 아래에 있는지 확인 (100px 이내)
      shouldMarkAsRead = _scrollController.position.pixels < 100;
    }
    
    if (shouldMarkAsRead) {
      try {
        await _localDb.markRoomAsRead(widget.room.id);
        debugPrint('✅ 읽음 처리 완료 (스크롤이 맨 아래)');
      } catch (e) {
        debugPrint('❌ 읽음 처리 실패: $e');
      }
    }
  }


  /// 대화방에 들어왔을 때 무조건 읽음 처리 (카카오톡처럼)
  Future<void> _markAsReadImmediately() async {
    if (_messages.isEmpty) return;
    
    try {
      debugPrint('🔄 즉시 읽음 처리 시도 (roomId: ${widget.room.id})');
      await _localDb.markRoomAsRead(widget.room.id);
      debugPrint('✅ 즉시 읽음 처리 완료');
    } catch (e) {
      debugPrint('❌ 즉시 읽음 처리 실패: $e');
    }
  }

  /// 보낸사람 프로필 이미지 가져오기
  /// - 개인 프로필이 있으면 개인 프로필 반환
  /// - 없으면 대화방 프로필로 fallback
  File? _getSenderProfileImage(String sender) {
    return _profileService.getSenderProfile(
      packageName: widget.room.packageName,
      roomName: widget.room.roomName,
      sender: sender,
      fallbackToRoom: true,  // sender 프로필 없으면 대화방 프로필 사용
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 0;
      _messages = [];
      _hasMore = true;
    });
    
    // 프로필 캐시 클리어 (새로운 이미지 반영)
    _profileService.invalidateRoomSenders(widget.room.roomName);

    try {
      final response = await _localDb.getRoomMessages(
        widget.room.id,
        page: 0,
        size: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        _messages = response.messages;
        _hasMore = response.hasMore;
        _currentPage = 0;
        _isLoading = false;
        debugPrint('메시지 로딩 완료: ${_messages.length}개');

        // 안 읽은 메시지가 5개 이상이면 자동으로 요약 모드 진입 (블럭 표시)
        if (widget.room.unreadCount >= 5 && _messages.isNotEmpty && widget.room.summaryEnabled) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            // 자동으로 요약 모드 진입 (안 읽은 메시지 개수만큼 선택)
            final unreadCount = widget.room.unreadCount.clamp(5, 300);
            await _enterSummaryMode(unreadCount);
            debugPrint('🔄 안 읽은 메시지 $unreadCount개 - 자동 요약 모드 진입');
          });
        } else if (widget.room.unreadCount >= 5 && _messages.isNotEmpty) {
          // 요약 기능이 꺼져있으면 스크롤만 이동
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _jumpToUnreadMessages();
          });
        } else if (widget.room.unreadCount > 0 && widget.room.unreadCount < 5 && _messages.isNotEmpty) {
          // 안 읽은 메시지가 1~4개면 읽지 않은 메시지 위치로 이동
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _jumpToUnreadMessages();
          });
        }
        // 안 읽은 메시지가 없으면 스크롤 위치 변경 없음 (기본 위치 유지)
      });
      
      // 초기 로딩 완료 후 새 메시지 체크 (로딩 중에 들어온 메시지가 있을 수 있음)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadNewMessages();
        // 대화방에 들어왔으므로 무조건 읽음 처리 (카카오톡처럼)
        _markAsReadImmediately();
      });
    } catch (e, stackTrace) {
      debugPrint('메시지 로딩 오류: $e');
      debugPrint('스택 트레이스: $stackTrace');
      if (!mounted) return;
      setState(() {
        _error = '대화 내용을 불러오는데 실패했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _localDb.getRoomMessages(
        widget.room.id,
        page: _currentPage + 1,
        size: _pageSize,
      );
      setState(() {
        if (response.messages.isNotEmpty) {
          _messages.addAll(response.messages);
          _hasMore = response.hasMore;
          _currentPage = response.page;
        } else {
          _hasMore = false;
        }
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  String _formatTime(DateTime time) {
    return DateFormat('a h:mm', 'ko_KR').format(time);
  }

  String _formatDate(DateTime time) {
    // "2026년 1월 30일 금요일" 형식으로 표시
    final weekday = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    final weekdayName = weekday[time.weekday - 1];
    return DateFormat('yyyy년 M월 d일', 'ko_KR').format(time) + ' $weekdayName';
  }

  /// 스크롤 인디케이터용 날짜 포맷 ("2026.01.30. 금" 형식)
  String _formatDateForIndicator(DateTime time) {
    final weekday = ['월', '화', '수', '목', '금', '토', '일'];
    final weekdayName = weekday[time.weekday - 1];
    return DateFormat('yyyy.MM.dd.', 'ko_KR').format(time) + ' $weekdayName';
  }

  bool _shouldShowDate(int index) {
    // reverse: true이므로 index 0이 가장 최신 메시지 (맨 아래)
    // 날짜 구분선은 각 날짜의 첫 번째 메시지(시간순 가장 오래된) 위에 표시
    //
    // 예: 1월 29일 메시지들 중 가장 오래된 메시지 위에 "2026년 1월 29일" 표시

    // 가장 오래된 메시지는 항상 날짜 표시
    if (index == _messages.length - 1) {
      return true;
    }

    final current = _messages[index];
    final next = _messages[index + 1]; // 더 오래된 메시지

    // 현재 메시지와 다음(더 오래된) 메시지의 날짜가 다르면,
    // 현재 메시지가 해당 날짜의 첫 번째(가장 오래된) 메시지이므로 날짜 표시
    return current.createTime.day != next.createTime.day ||
        current.createTime.month != next.createTime.month ||
        current.createTime.year != next.createTime.year;
  }

  // 같은 사람이 연속으로 보낸 메시지인지 확인
  // 카카오톡처럼 각 메시지마다 프로필을 보여주므로 항상 false 반환
  bool _isSameSender(int index) {
    // 각 메시지마다 프로필을 표시하므로 항상 false 반환
    return false;
  }

  // 같은 사람이 연속으로 보낸 메시지 그룹의 마지막 메시지인지 확인
  bool _isLastInGroup(int index) {
    if (index == _messages.length - 1) return true; // 마지막 메시지 (가장 오래된)
    // reverse: true이므로 index는 이미 역순
    final current = _messages[index];
    final next = _messages[index + 1];
    return current.sender != next.sender;
  }

  // 시간 차이가 5분 이상인지 확인 (시간 표시 여부 결정)
  bool _shouldShowTime(int index) {
    if (index == 0) return true; // 첫 번째 메시지 (가장 최신)는 항상 시간 표시
    if (_isLastInGroup(index)) return true;
    
    // reverse: true이므로 index는 이미 역순
    final current = _messages[index];
    final prev = _messages[index - 1];
    final diff = current.createTime.difference(prev.createTime);
    return diff.inMinutes >= 5;
  }

  Future<void> _openKakaoTalk() async {
    const kakaoScheme = 'kakaotalk://main';
    final uri = Uri.parse(kakaoScheme);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _openPlayStore();
      }
    } catch (e) {
      _openPlayStore();
    }
  }

  Future<void> _openPlayStore() async {
    const playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.kakao.talk';
    final storeUri = Uri.parse(playStoreUrl);
    await launchUrl(storeUri, mode: LaunchMode.externalApplication);
  }

  /// 대화방 나가기 확인 다이얼로그
  void _showLeaveConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('대화방 나가기'),
        content: const Text('메시지, 요약 전부 사라집니다.\n나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _leaveRoom();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
  }

  /// 안 읽은 메시지 위치로 즉시 이동 (애니메이션 없음)
  void _jumpToUnreadMessages() {
    if (!_scrollController.hasClients || _messages.isEmpty) return;

    final unreadCount = widget.room.unreadCount;
    if (unreadCount < 5) return; // 5개 미만이면 스크롤하지 않음

    // reverse: true ListView에서:
    // - offset = 0 → index 0(최신)이 화면 하단
    // - offset 증가 → 화면이 위로 스크롤 (오래된 메시지가 보임)
    //
    // 블록: index 0 ~ unreadCount-1 (unreadCount개 메시지)
    // 블록의 맨 위 = 가장 오래된 = index unreadCount-1
    // 이 메시지가 화면 상단 25%에 오도록 스크롤
    final blockEndIndex = (unreadCount - 1).clamp(0, _messages.length - 1);

    // index 0부터 blockEndIndex까지의 누적 높이 계산 (blockEndIndex 메시지 포함)
    final blockEndOffset = _calculateScrollOffset(blockEndIndex + 1);
    final blockEndMessageHeight = _estimateMessageHeight(_messages[blockEndIndex]);

    // 화면 상단 25% 위치에 블록 맨 위 메시지가 오도록 조정
    final screenHeight = MediaQuery.of(context).size.height;
    final topMargin = screenHeight * 0.25; // 상단 25% 여백

    // blockEndOffset으로 스크롤하면 blockEndIndex 다음 메시지가 화면 하단에 위치
    // 블록 맨 위 메시지가 화면 상단 25%에 오게 하려면:
    // offset = blockEndOffset - screenHeight + topMargin + 메시지높이
    final adjustedOffset = (blockEndOffset - screenHeight + topMargin + blockEndMessageHeight)
        .clamp(0.0, _scrollController.position.maxScrollExtent);

    // 애니메이션 없이 즉시 이동 (jumpTo)
    _scrollController.jumpTo(adjustedOffset);

    debugPrint('안 읽은 메시지 위치로 즉시 이동: unreadCount=$unreadCount, blockEndIndex=$blockEndIndex, adjustedOffset=$adjustedOffset');
  }

  /// 검색 실행
  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _currentSearchIndex = -1;
      });
      return;
    }

    final results = <int>[];
    final lowerQuery = query.toLowerCase();

    for (int i = 0; i < _messages.length; i++) {
      // 선택된 사용자가 있으면 해당 사용자의 메시지만 검색
      if (_selectedSender != null && _messages[i].sender != _selectedSender) {
        continue;
      }
      
      // 메시지 내용 검색
      if (_messages[i].message.toLowerCase().contains(lowerQuery)) {
        results.add(i);
      }
    }

    setState(() {
      _searchResults = results;
      _currentSearchIndex = results.isNotEmpty ? 0 : -1;
    });

    // 첫 번째 검색 결과로 스크롤
    if (results.isNotEmpty) {
      _scrollToSearchResult(0);
    }
  }
  
  /// 고유한 발신자 목록 가져오기
  List<String> _getUniqueSenders() {
    final senders = <String>{};
    for (var message in _messages) {
      senders.add(message.sender);
    }
    return senders.toList()..sort();
  }
  
  /// 사용자 선택 다이얼로그 표시
  void _showSenderSelectionDialog() {
    final senders = _getUniqueSenders();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          const Text(
            '사용자 선택',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: senders.length + 1, // +1 for "전체" 옵션
              itemBuilder: (context, index) {
                if (index == 0) {
                  // "전체" 옵션
                  return ListTile(
                    leading: const Icon(Icons.people, color: Colors.grey),
                    title: const Text('전체'),
                    onTap: () {
                      setState(() {
                        _selectedSender = null;
                        _searchResults = [];
                        _currentSearchIndex = -1;
                      });
                      Navigator.pop(context);
                      // 검색어가 있으면 다시 검색
                      if (_searchController.text.isNotEmpty) {
                        _performSearch(_searchController.text);
                      }
                    },
                    selected: _selectedSender == null,
                  );
                }

                final sender = senders[index - 1];
                final profileImage = _getSenderProfileImage(sender);

                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF64B5F6),
                    backgroundImage: profileImage != null ? FileImage(profileImage) : null,
                    child: profileImage == null
                        ? Text(
                            sender.isNotEmpty ? sender[0] : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : null,
                  ),
                  title: Text(sender),
                  onTap: () {
                    Navigator.pop(context);
                    _selectSenderAndSearch(sender);
                  },
                  selected: _selectedSender == sender,
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
        ],
      ),
    );
  }

  /// 사용자 선택 후 해당 사용자 메시지 검색
  void _selectSenderAndSearch(String sender) {
    setState(() {
      _selectedSender = sender;
    });

    // 기존 검색어가 있으면 해당 사용자의 메시지 중 검색어 포함된 것만 검색
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    } else {
      // 검색어가 없으면 해당 사용자의 모든 메시지 표시
      final List<int> senderMessages = [];
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].sender == sender) {
          senderMessages.add(i);
        }
      }

      setState(() {
        _searchResults = senderMessages;
        _currentSearchIndex = senderMessages.isNotEmpty ? 0 : -1;
      });

      // 첫 번째 결과로 스크롤
      if (senderMessages.isNotEmpty) {
        _scrollToSearchResult(0);
      }
    }
  }

  /// 검색 결과로 스크롤
  void _scrollToSearchResult(int resultIndex) {
    if (resultIndex < 0 || resultIndex >= _searchResults.length) return;

    final messageIndex = _searchResults[resultIndex];
    if (_scrollController.hasClients) {
      final screenHeight = MediaQuery.of(context).size.height;
      final baseOffset = _calculateScrollOffset(messageIndex);
      final messageHeight = _estimateMessageHeight(_messages[messageIndex]);

      // reverse: true ListView에서:
      // - baseOffset으로 스크롤하면 해당 메시지가 화면 맨 아래에 위치
      // - 메시지를 화면 중앙보다 약간 아래(하단 40% 위치)에 표시
      // - 하단 툴바 높이를 고려하여 조정
      final bottomBarHeight = screenHeight * 0.07; // 하단 바 높이
      final visibleHeight = screenHeight - bottomBarHeight;

      // 메시지가 화면 하단에서 35% 위치에 오도록 (하단바 위 영역 기준)
      final targetPositionFromBottom = visibleHeight * 0.35;

      // offset 조정: baseOffset에서 빼면 메시지가 위로 올라감
      final targetOffset = (baseOffset - targetPositionFromBottom + messageHeight)
          .clamp(0.0, _scrollController.position.maxScrollExtent);

      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// 다음 검색 결과로 이동 (위로 - 오래된 메시지)
  void _goToPreviousSearchResult() {
    if (_searchResults.isEmpty) return;
    setState(() {
      _currentSearchIndex = (_currentSearchIndex + 1) % _searchResults.length;
    });
    _scrollToSearchResult(_currentSearchIndex);
  }

  /// 이전 검색 결과로 이동 (아래로 - 최신 메시지)
  void _goToNextSearchResult() {
    if (_searchResults.isEmpty) return;
    setState(() {
      _currentSearchIndex = (_currentSearchIndex - 1 + _searchResults.length) % _searchResults.length;
    });
    _scrollToSearchResult(_currentSearchIndex);
  }

  /// 검색 모드 종료
  void _exitSearchMode() {
    setState(() {
      _isSearchMode = false;
      _selectedSender = null;
      _searchController.clear();
      _searchResults = [];
      _currentSearchIndex = -1;
    });
  }

  /// 요약 모드 진입
  Future<void> _enterSummaryMode(int messageCount) async {
    if (!widget.room.summaryEnabled) return;

    // 메시지가 없으면 요약 모드 진입 불가
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('요약할 메시지가 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 메시지가 5개 미만이면 요약 모드 진입 불가
    if (_messages.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('메시지가 ${_messages.length}개입니다. 요약은 5개 이상의 메시지가 필요합니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 최대 300개로 제한
    final requestedCount = messageCount.clamp(1, 300);
    
    // 요청된 개수가 현재 로드된 메시지보다 많으면 추가로 로드
    if (requestedCount > _messages.length && _hasMore) {
      // 필요한 만큼 메시지 로드 (최대 300개까지)
      final neededCount = requestedCount - _messages.length;
      final pagesToLoad = (neededCount / _pageSize).ceil();
      
      for (int i = 0; i < pagesToLoad && _hasMore && _messages.length < 300; i++) {
        try {
          final response = await _localDb.getRoomMessages(
            widget.room.id,
            page: _currentPage + 1,
            size: _pageSize,
          );
          
          if (!mounted) return;
          
          setState(() {
            if (response.messages.isNotEmpty) {
              _messages.addAll(response.messages);
              _hasMore = response.hasMore;
              _currentPage = response.page;
            } else {
              _hasMore = false;
            }
          });
          
          // 300개에 도달하면 중단
          if (_messages.length >= 300) break;
        } catch (e) {
          debugPrint('메시지 추가 로드 실패: $e');
          break;
        }
      }
    }
    
    if (!mounted) return;

    setState(() {
      _isSummaryMode = true;
      // 최소 1개, 최대는 실제 메시지 개수 또는 300개 중 작은 값
      final maxCount = _messages.length.clamp(1, 300);
      _selectedMessageCount = requestedCount.clamp(1, maxCount);
      _selectionStartIndex = 0;  // 최신 메시지부터 시작
    });

    // 블록의 시작점(오래된 쪽 = index N-1)이 화면 상단 25%에 오도록 스크롤
    if (_messages.isNotEmpty && _selectedMessageCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          // reverse: true ListView에서:
          // - offset = 0 → index 0(최신)이 화면 하단
          // - offset 증가 → 화면이 위로 스크롤 (오래된 메시지가 보임)
          //
          // 블록: index 0 ~ N-1 (N개 메시지)
          // 블록의 "상단" = 시간순 첫 번째 = 가장 오래된 = index N-1
          // 이 메시지가 화면 상단 25%에 오도록 스크롤

          final blockEndIndex = (_selectedMessageCount - 1).clamp(0, _messages.length - 1);
          final blockEndOffset = _calculateScrollOffset(blockEndIndex + 1);
          final blockEndMessageHeight = _estimateMessageHeight(_messages[blockEndIndex]);

          // 화면 상단 25% 위치에 블록 맨 위 메시지가 오도록 조정
          final screenHeight = MediaQuery.of(context).size.height;
          final topMargin = screenHeight * 0.25; // 상단 25% 여백

          // 블록 맨 위 메시지가 화면 상단 25%에 오게 하려면:
          final adjustedOffset = (blockEndOffset - screenHeight + topMargin + blockEndMessageHeight)
              .clamp(0.0, _scrollController.position.maxScrollExtent);

          _scrollController.animateTo(
            adjustedOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// 메시지 터치로 선택 시작 (실제 메시지 개수에 맞춤)
  void _startSelectionAt(int index) {
    if (!_isSummaryMode) {
      _enterSummaryMode(1); // await 없이 호출 (비동기지만 결과를 기다릴 필요 없음)
    }

    // 최소 1개, 최대는 실제 메시지 개수 또는 300개 중 작은 값
    final maxCount = _messages.length.clamp(1, 300);
    final newCount = (index + 1).clamp(1, maxCount);

    setState(() {
      _selectionStartIndex = index;
      _selectedMessageCount = newCount;
    });

    HapticFeedback.selectionClick();
  }

  /// 드래그로 선택 영역 확장 (실제 메시지 개수에 맞춤)
  void _expandSelectionTo(int index) {
    if (!_isSummaryMode || _selectionStartIndex == null) return;

    // 최소 1개, 최대는 실제 메시지 개수 또는 300개 중 작은 값
    final maxCount = _messages.length.clamp(1, 300);
    final newCount = (index + 1).clamp(1, maxCount);

    if (newCount != _selectedMessageCount) {
      setState(() {
        _selectedMessageCount = newCount;
      });
      HapticFeedback.selectionClick();
    }
  }

  /// 요약 모드 종료
  void _exitSummaryMode() {
    debugPrint('🔄 _exitSummaryMode 호출 (현재 _isSummaryMode: $_isSummaryMode)');
    if (!mounted) {
      debugPrint('❌ _exitSummaryMode: mounted가 false');
      return;
    }
    setState(() {
      _isSummaryMode = false;
      _selectedMessageCount = 0;
      _selectionStartIndex = null;
      _isDraggingSelection = false;
      _isDragHandleVisible = false;  // 드래그 핸들도 숨김
    });
    debugPrint('✅ _exitSummaryMode 완료 (_isSummaryMode: $_isSummaryMode)');
  }

  /// 요약 개수 변경 (실제 메시지 개수에 맞춤)
  Future<void> _updateSummaryCount(int newCount) async {
    // 최대 300개로 제한
    final requestedCount = newCount.clamp(1, 300);
    
    // 요청된 개수가 현재 로드된 메시지보다 많으면 추가로 로드
    if (requestedCount > _messages.length && _hasMore) {
      // 필요한 만큼 메시지 로드 (최대 300개까지)
      final neededCount = requestedCount - _messages.length;
      final pagesToLoad = (neededCount / _pageSize).ceil();
      
      for (int i = 0; i < pagesToLoad && _hasMore && _messages.length < 300; i++) {
        try {
          final response = await _localDb.getRoomMessages(
            widget.room.id,
            page: _currentPage + 1,
            size: _pageSize,
          );
          
          if (!mounted) return;
          
          setState(() {
            if (response.messages.isNotEmpty) {
              _messages.addAll(response.messages);
              _hasMore = response.hasMore;
              _currentPage = response.page;
            } else {
              _hasMore = false;
            }
          });
          
          // 300개에 도달하면 중단
          if (_messages.length >= 300) break;
        } catch (e) {
          debugPrint('메시지 추가 로드 실패: $e');
          break;
        }
      }
    }
    
    if (!mounted) return;
    
    // 최소 1개, 최대는 실제 메시지 개수 또는 300개 중 작은 값
    final maxCount = _messages.length.clamp(1, 300);
    setState(() {
      _selectedMessageCount = requestedCount.clamp(1, maxCount);
    });

    // 스크롤 위치 업데이트 (블럭 시작점이 상단 25%에 오도록)
    if (_messages.isNotEmpty && _selectedMessageCount > 0) {
      if (_scrollController.hasClients) {
        // 블록의 "상단" = 가장 오래된 메시지 = index N-1
        final blockEndIndex = (_selectedMessageCount - 1).clamp(0, _messages.length - 1);
        final blockEndOffset = _calculateScrollOffset(blockEndIndex + 1);
        final blockEndMessageHeight = _estimateMessageHeight(_messages[blockEndIndex]);

        // 화면 상단 25% 위치에 블록 맨 위 메시지가 오도록 조정
        final screenHeight = MediaQuery.of(context).size.height;
        final topMargin = screenHeight * 0.25;
        final adjustedOffset = (blockEndOffset - screenHeight + topMargin + blockEndMessageHeight)
            .clamp(0.0, _scrollController.position.maxScrollExtent);

        _scrollController.animateTo(
          adjustedOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
  }

  /// 개수 직접 입력 다이얼로그 (안전한 버전)
  Future<void> _showCountInputDialog() async {
    if (!mounted) return;

    // 다이얼로그 호출 전 필요한 데이터 미리 계산
    final int currentMessageCount = _messages.length;
    const int maxCount = 300; // 최대 300개 고정
    final int currentSelected = _selectedMessageCount;

    final TextEditingController controller = TextEditingController(
      text: currentSelected.toString(),
    );
    final FocusNode focusNode = FocusNode();

    final result = await showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        String? errorMessage;

        return StatefulBuilder(
          builder: (BuildContext stateContext, StateSetter setDialogState) {
            // 포커스 해제 후 안전하게 닫기
            void safeClose([int? value]) {
              focusNode.unfocus();
              Future.delayed(const Duration(milliseconds: 50), () {
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop(value);
                }
              });
            }

            void validateAndPop() {
              final count = int.tryParse(controller.text);

              // 유효성 검사
              if (count == null || count < 5 || count > maxCount) {
                setDialogState(() {
                  errorMessage = '5 ~ 300 사이의 숫자를 입력해주세요.';
                });
                return; // 에러 발생 시 다이얼로그 유지
              }

              safeClose(count);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(AppColors.summaryPrimary),
                          Color(AppColors.summaryPrimary).withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '메시지 개수 입력',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '최대 300개까지 가능 (현재 $currentMessageCount개)',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: '개수 입력',
                      suffixText: '개',
                      errorText: errorMessage,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (_) => validateAndPop(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => safeClose(),
                  child: Text('취소', style: TextStyle(color: Colors.grey[600])),
                ),
                ElevatedButton(
                  onPressed: validateAndPop,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(AppColors.summaryPrimary),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('확인'),
                ),
              ],
            );
          },
        );
      },
    );

    // 다이얼로그가 완전히 닫힌 후 dispose
    controller.dispose();
    focusNode.dispose();

    // mounted 체크 후 안전하게 setState
    if (!mounted) return;
    
    if (result != null) {
      // postFrameCallback로 현재 프레임 완료 후 setState 실행
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          await _updateSummaryCount(result);
          HapticFeedback.mediumImpact();
        }
      });
    }
  }

  /// 선택 범위 끝부분 표시 위젯
  Widget _buildSelectionEdgeIndicator({required bool isTop}) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Color(AppColors.summaryPrimary).withOpacity(0.25),
            Color(AppColors.summaryPrimary).withOpacity(0.35),
            Color(AppColors.summaryPrimary).withOpacity(0.25),
            Colors.transparent,
          ],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Color(AppColors.summaryPrimary),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Color(AppColors.summaryPrimary).withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isTop ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                isTop ? '선택 시작' : '선택 끝',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 고정 토글
  Future<void> _togglePinned() async {
    final newPinned = !widget.room.pinned;
    final result = await _localDb.updateRoomSettings(widget.room.id, pinned: newPinned);

    if (result != null && mounted) {
      // 부모 화면에 변경사항 전달
      Navigator.pop(context, {'pinned': newPinned});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newPinned ? '상단에 고정되었습니다.' : '고정이 해제되었습니다.'),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('고정 설정 변경에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 알림 토글
  Future<void> _toggleNotification(NotificationSettingsService notificationService) async {
    await notificationService.toggleNotification(widget.room.roomName);
    if (mounted) {
      final isMuted = notificationService.isMuted(widget.room.roomName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMuted
                ? '${widget.room.roomName} 알림이 꺼졌습니다.'
                : '${widget.room.roomName} 알림이 켜졌습니다.',
          ),
        ),
      );
    }
  }

  /// 요약 기능 토글
  Future<void> _toggleSummaryEnabled() async {
    final newSummaryEnabled = !widget.room.summaryEnabled;
    final result = await _localDb.updateRoomSettings(
      widget.room.id,
      summaryEnabled: newSummaryEnabled,
    );

    if (result != null && mounted) {
      // 부모 화면에 변경사항 전달
      Navigator.pop(context, {'summaryEnabled': newSummaryEnabled});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newSummaryEnabled
                ? '✨ AI 요약 기능이 켜졌습니다.'
                : 'AI 요약 기능이 꺼졌습니다.',
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('요약 기능 설정 변경에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 대화방 나가기 (삭제)
  Future<void> _leaveRoom() async {
    final success = await _localDb.deleteRoom(widget.room.id);
    if (success && mounted) {
      Navigator.pop(context, true); // true를 반환하여 목록 화면에서 삭제된 방을 제거하도록 함
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.room.roomName} 대화방에서 나갔습니다.'),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('대화방 나가기에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSearchMode && !_isSummaryMode,
      onPopInvokedWithResult: (didPop, result) {
        // 화면이 실제로 나갈 때 읽음 처리 (새 메시지가 왔든 안 왔든 무조건)
        if (didPop) {
          debugPrint('🔄 화면 나갈 때 읽음 처리 시도 (roomId: ${widget.room.id})');
          _localDb.markRoomAsRead(widget.room.id).then((_) {
            debugPrint('✅ 화면 나갈 때 읽음 처리 완료');
          }).catchError((e) {
            debugPrint('❌ 화면 나갈 때 읽음 처리 실패: $e');
          });
          return;
        }
        // 검색 모드나 요약 모드가 활성화되어 있으면 모드 종료
        if (_isSearchMode) {
          _exitSearchMode();
        } else if (_isSummaryMode) {
          _exitSummaryMode();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE8F4FC), // 밝은 하늘색 배경 (앱 테마와 조화)
        appBar: AppBar(
        backgroundColor: const Color(AppColors.primaryValue), // 앱 테마 파란색
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // 검색 모드나 요약 모드가 활성화되어 있으면 모드 종료
            if (_isSearchMode) {
              _exitSearchMode();
            } else if (_isSummaryMode) {
              _exitSummaryMode();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: _isSearchMode || _isSummaryMode
            ? _buildAppBarSearchBar()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.room.roomName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.room.participantCount > 0)
                    Text(
                      '${widget.room.participantCount}명',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
        actions: [
          // 검색 모드나 요약 모드가 아닐 때만 검색/요약 버튼 표시
          if (!_isSearchMode && !_isSummaryMode) ...[
            // 검색 버튼 (돋보기)
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
              onPressed: () {
                setState(() {
                  _isSearchMode = true;
                });
                // 검색창에 포커스 주기
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _searchFocusNode.requestFocus();
                });
              },
            ),
            // 요약 버튼
            if (widget.room.summaryEnabled)
              IconButton(
                icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
              onPressed: () async {
                if (_messages.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('요약할 메시지가 없습니다.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (_messages.length < 5) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('메시지가 ${_messages.length}개입니다. 요약은 5개 이상의 메시지가 필요합니다.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                await _enterSummaryMode(_defaultSummaryCount);
              },
            ),
          ],
          // 검색/요약 모드가 아닐 때만 메뉴 버튼 표시
          if (!_isSearchMode && !_isSummaryMode)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'summary_history') {
                  _showSummaryHistory();
                } else if (value == 'open_kakao') {
                  _openKakaoTalk();
                } else if (value == 'leave_room') {
                  _showLeaveConfirmDialog();
                }
              },
              itemBuilder: (context) => [
                if (widget.room.summaryEnabled)
                  const PopupMenuItem(
                    value: 'summary_history',
                    child: Row(
                      children: [
                        Icon(Icons.history, color: Colors.amber),
                        SizedBox(width: 12),
                        Text('AI 요약 히스토리'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'open_kakao',
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble, color: Color(0xFFFFE812)),
                      SizedBox(width: 12),
                      Text('카카오톡 열기'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'leave_room',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app, color: Colors.red),
                      SizedBox(width: 12),
                      Text('대화방 나가기', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3C1E1E)),
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadMessages,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    Column(
                      children: [
                        // 메시지 리스트
                        Expanded(
                      child: _messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble_outline,
                                      size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    '아직 대화가 없습니다',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Stack(
                              children: [
                                RefreshIndicator(
                                  onRefresh: _loadMessages,
                                  color: const Color(0xFF3C1E1E),
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    reverse: true,
                                    padding: const EdgeInsets.only(
                                        left: 0,
                                        right: 0,
                                        top: 0,
                                        bottom: 8),
                                    itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                          if (_isLoadingMore && index == _messages.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF3C1E1E)),
                                ),
                              ),
                            );
                          }

                          // reverse: true이므로 index는 이미 역순
                          // index 0 = 가장 최신 메시지 (맨 아래 표시)
                          // index가 커질수록 오래된 메시지 (맨 위 표시)
                          final message = _messages[index];
                          final showDate = _shouldShowDate(index);
                          final isSameSender = _isSameSender(index);
                          final isLastInGroup = _isLastInGroup(index);
                          final showTime = _shouldShowTime(index);

                          // reverse: true이므로 index 0이 맨 아래(최신 메시지)에 표시됨
                          // 날짜 구분선은 메시지 위에 표시되어야 하므로 먼저 배치
                          
                          // 요약 모드일 때 선택된 범위에 포함되는지 확인
                          // 안 읽은 메시지 5개 이상이면 자동으로 요약 모드로 진입하므로
                          // isUnreadRange는 필요 없음 (요약 모드에서 블럭 표시)
                          final isInSelectedRange = _isSummaryMode && index < _selectedMessageCount;

                          // 검색 결과인지 확인 - 현재 선택된 것만 하이라이트
                          final isCurrentSearchResult = _isSearchMode &&
                                                        _currentSearchIndex >= 0 &&
                                                        _currentSearchIndex < _searchResults.length &&
                                                        _searchResults[_currentSearchIndex] == index;

                          // "여기까지 읽으셨습니다" 구분선 표시 여부
                          // reverse: true이므로 index 0이 최신, unreadCount번째 메시지 위에 구분선
                          final showUnreadDivider = widget.room.unreadCount > 0 && index == widget.room.unreadCount;

                          // 사용자 검색 모드 여부 (검색어 없이 사용자만 선택된 경우)
                          final isSenderSearch = _selectedSender != null && _searchController.text.isEmpty;

                          // 메시지 위젯 생성 (현재 선택된 검색 결과만 하이라이트)
                          Widget messageWidget = _buildMessageBubble(
                            message,
                            showProfile: !isSameSender,
                            showName: !isSameSender,
                            showTime: showTime,
                            isLastInGroup: isLastInGroup,
                            isSearchResult: false, // 모든 검색 결과에 테두리 표시하지 않음
                            isCurrentSearchResult: isCurrentSearchResult, // 현재 선택된 것만 표시
                            searchQuery: isCurrentSearchResult && _isSearchMode && _searchController.text.isNotEmpty
                                ? _searchController.text
                                : null, // 현재 선택된 것만 단어 하이라이트
                            isSenderSearch: false,
                          );

                          // 요약 모드에서 선택 범위의 끝부분에 확장 표시 추가
                          if (_isSummaryMode && isInSelectedRange) {
                            // 선택 범위 전체에 배경색 추가 (블럭이 더 잘 보이도록)
                            messageWidget = Stack(
                              children: [
                                // 배경색 레이어
                                Positioned.fill(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: Color(AppColors.summaryPrimary).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                // 메시지 위젯
                                messageWidget,
                              ],
                            );
                            
                            // 선택 범위의 첫 번째 메시지 (가장 최신)
                            if (index == 0) {
                              messageWidget = Stack(
                                children: [
                                  messageWidget,
                                  // 하단 모서리 표시 - 터치 영역 확장
                                  Positioned(
                                    bottom: -24, // 영역 대폭 확장 (-12 -> -24)
                                    left: 12,
                                    right: 12,
                                    child: _buildSelectionEdgeIndicator(isTop: false),
                                  ),
                                ],
                              );
                            }
                            // 선택 범위의 마지막 메시지 (가장 오래된)
                            else if (index == _selectedMessageCount - 1) {
                              messageWidget = Stack(
                                children: [
                                  messageWidget,
                                  // 상단 모서리 표시 - 터치 영역 확장
                                  Positioned(
                                    top: -24, // 영역 대폭 확장 (-12 -> -24)
                                    left: 12,
                                    right: 12,
                                    child: _buildSelectionEdgeIndicator(isTop: true),
                                  ),
                                ],
                              );
                            }
                          }

                          // 요약 모드일 때 제스처 감지 추가
                          if (_isSummaryMode) {
                            messageWidget = GestureDetector(
                              onTap: () => _startSelectionAt(index),
                              onLongPressStart: (details) {
                                _startSelectionAt(index);
                                setState(() {
                                  _isDraggingSelection = true;
                                });
                              },
                              onLongPressMoveUpdate: (details) {
                                if (_isDraggingSelection) {
                                  // 현재 드래그 위치의 메시지 인덱스 계산
                                  // 위로 이동할수록 인덱스 증가 (더 오래된 메시지)
                                  final scrollDelta = details.localOffsetFromOrigin.dy;
                                  // 대략 메시지 하나당 80px 높이 기준
                                  final indexDelta = (-scrollDelta / 60).round();
                                  final newIndex = ((_selectionStartIndex ?? 0) + indexDelta)
                                      .clamp(0, _messages.length - 1);
                                  _expandSelectionTo(newIndex);
                                }
                              },
                              onLongPressEnd: (_) {
                                setState(() {
                                  _isDraggingSelection = false;
                                });
                              },
                              child: messageWidget,
                            );
                          }

                          return Column(
                            children: [
                              // 날짜 구분선 (메시지 위에 표시)
                              if (showDate) _buildDateDivider(message.createTime),
                              messageWidget,
                              // "여기까지 읽었습니다" 구분선 (안 읽은 메시지 블록 바로 아래)
                              if (showUnreadDivider) _buildUnreadDivider(),
                            ],
                          );
                                    },
                                  ),
                                ),
                                // 새 메시지 알림 (카카오톡 스타일, 하단에 붙어서 내용 표시)
                                if (_newMessageCount > 0 && !_isAtBottom && _latestNewMessageSender != null)
                                  Positioned(
                                    bottom: _chatInputBarHeight > 0 ? _chatInputBarHeight + 8 : 80, // 입력창 높이 + 여유 공간
                                    left: 12,
                                    right: 12,
                                    child: GestureDetector(
                              onTap: () {
                                _scrollToBottom();
                                HapticFeedback.lightImpact();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B3B3B),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // 프로필 영역
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[600],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: _getSenderProfileImage(_latestNewMessageSender!) != null
                                            ? Image.file(
                                                _getSenderProfileImage(_latestNewMessageSender!)!,
                                                fit: BoxFit.cover,
                                              )
                                            : const Icon(
                                                Icons.person,
                                                color: Colors.white70,
                                                size: 20,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // 메시지 내용
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _latestNewMessageSender!,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _latestNewMessageContent ?? '',
                                            style: TextStyle(
                                              color: Colors.grey[300],
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // 새 메시지 개수 배지
                                    if (_newMessageCount > 1)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(AppColors.primaryValue),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '+${_newMessageCount - 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 4),
                                    // 아래 화살표
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white70,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                                // 스크롤 날짜 인디케이터 (오른쪽에 고정, 카카오톡 스타일)
                                if (_visibleDate != null && !_isAtBottom)
                                  Positioned(
                                    right: 8,
                                    top: MediaQuery.of(context).size.height * 0.5 - 20, // 화면 중앙
                                    child: IgnorePointer(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _formatDateForIndicator(_visibleDate!),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        // 하단 채팅 입력창 (검색/요약 모드가 아닐 때만 표시)
                        if (!_isSearchMode && !_isSummaryMode)
                          Builder(
                            builder: (context) {
                              // 레이아웃 완료 후 높이 측정
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _measureChatInputBarHeight();
                              });
                              return _buildChatInputBar();
                            },
                          ),
                        // 검색/요약 모드일 때 하단 바
                        if (_isSearchMode)
                          _buildSearchResultBar(),
                        if (_isSummaryMode)
                          _buildSummaryBottomBar(),
                      ],
                    ),
                  ],
                ),
      ),
    );
  }

  /// AppBar에 표시할 검색창/요약 타이틀 (카카오톡 스타일)
  Widget _buildAppBarSearchBar() {
    // 요약 모드일 때는 간단한 타이틀 표시 (조절 기능은 하단 바에)
    if (_isSummaryMode) {
      return Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: Colors.white.withOpacity(0.9),
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            'AI 요약 모드',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    // 검색 모드일 때는 검색창만 표시 (사람 검색/날짜 이동은 하단 바에)
    return StatefulBuilder(
      builder: (context, setState) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Container(
          height: screenWidth * 0.1,
          margin: EdgeInsets.only(right: screenWidth * 0.03),
          child: Container(
            height: screenWidth * 0.09,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(screenWidth * 0.045),
            ),
            child: Row(
              children: [
                SizedBox(width: screenWidth * 0.03),
                Icon(
                  Icons.search_rounded,
                  color: Color(AppColors.summaryPrimary),
                  size: screenWidth * 0.05,
                ),
                SizedBox(width: screenWidth * 0.02),
                // 선택된 사용자 태그 표시
                if (_selectedSender != null)
                  Container(
                    margin: EdgeInsets.only(right: screenWidth * 0.02),
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.02,
                      vertical: screenWidth * 0.01,
                    ),
                    decoration: BoxDecoration(
                      color: Color(AppColors.summaryPrimary).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(screenWidth * 0.02),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedSender!,
                          style: TextStyle(
                            fontSize: screenWidth * 0.032,
                            fontWeight: FontWeight.w600,
                            color: Color(AppColors.summaryPrimary),
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.01),
                        GestureDetector(
                          onTap: () {
                            this.setState(() {
                              _selectedSender = null;
                            });
                            setState(() {});
                            // 검색어가 있으면 전체 검색으로 다시 실행
                            if (_searchController.text.isNotEmpty) {
                              _performSearch(_searchController.text);
                            } else {
                              this.setState(() {
                                _searchResults = [];
                                _currentSearchIndex = -1;
                              });
                            }
                          },
                          child: Icon(
                            Icons.close,
                            size: screenWidth * 0.035,
                            color: Color(AppColors.summaryPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: '대화 검색',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: (value) {
                      setState(() {}); // X 버튼 표시 업데이트
                      this.setState(() {}); // 외부 상태 업데이트
                    },
                    onSubmitted: (value) {
                      // 검색 실행
                      if (value.trim().isNotEmpty) {
                        _performSearch(value.trim());
                        _searchFocusNode.unfocus(); // 키보드 내리기
                      }
                    },
                  ),
                ),
                // 닫기 버튼 (텍스트가 있을 때만 표시)
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: screenWidth * 0.045),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Colors.grey[600],
                    onPressed: () {
                      this.setState(() {
                        _searchController.clear();
                        _searchResults = [];
                        _currentSearchIndex = -1;
                      });
                      setState(() {}); // StatefulBuilder 업데이트
                    },
                  ),
                SizedBox(width: screenWidth * 0.02),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 상단 검색창 (레거시 - 사용 안 함)
  Widget _buildTopSearchBar() {
    // 요약 모드일 때는 요약 모드 패널만 표시
    if (_isSummaryMode) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // 취소 버튼
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.11,
                  height: MediaQuery.of(context).size.width * 0.11,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 22),
                      color: Colors.grey[700],
                      onPressed: () {
                        _exitSummaryMode();
                        if (widget.room.unreadCount == 0) {
                          setState(() {
                            _isDragHandleVisible = false;
                          });
                        }
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                // 개수 조절
                Expanded(
                  child: Container(
                    height: MediaQuery.of(context).size.width * 0.11,
                    decoration: BoxDecoration(
                      color: Color(AppColors.summaryPrimary).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.remove_circle,
                            color: _selectedMessageCount > 1
                                ? Color(AppColors.summaryPrimary)
                                : Colors.grey[400],
                          ),
                          onPressed: _selectedMessageCount > 5
                              ? () async {
                                  await _updateSummaryCount(_selectedMessageCount - 1);
                                  HapticFeedback.selectionClick();
                                }
                              : null,
                        ),
                        GestureDetector(
                          onTap: () => _showCountInputDialog(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$_selectedMessageCount',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(AppColors.summaryPrimary),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '개',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(AppColors.summaryPrimary).withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.edit_rounded,
                                  size: 14,
                                  color: Color(AppColors.summaryPrimary).withOpacity(0.6),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.add_circle,
                            color: _selectedMessageCount < _messages.length.clamp(1, 300)
                                ? Color(AppColors.summaryPrimary)
                                : Colors.grey[400],
                          ),
                          onPressed: _selectedMessageCount < _messages.length.clamp(1, 300)
                              ? () async {
                                  await _updateSummaryCount(_selectedMessageCount + 1);
                                  HapticFeedback.selectionClick();
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                // 요약하기 버튼
                Container(
                  height: MediaQuery.of(context).size.width * 0.11,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(AppColors.summaryPrimary),
                        Color(AppColors.summaryPrimary).withOpacity(0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Color(AppColors.summaryPrimary).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      _requestSummary();
                      HapticFeedback.mediumImpact();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 18),
                        SizedBox(width: 6),
                        Text(
                          '요약',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 검색창
              Expanded(
                child: Container(
                  height: MediaQuery.of(context).size.width * 0.11,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _isSearchMode 
                          ? Color(AppColors.summaryPrimary).withOpacity(0.3)
                          : Colors.grey[200]!,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(
                        Icons.search_rounded,
                        color: _isSearchMode 
                            ? Color(AppColors.summaryPrimary)
                            : Colors.grey[500],
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText: '대화 검색',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          onChanged: (value) {
                            _performSearch(value);
                            if (value.isNotEmpty && !_isSearchMode) {
                              setState(() {
                                _isSearchMode = true;
                              });
                            } else if (value.isEmpty && _isSearchMode) {
                              setState(() {
                                _isSearchMode = false;
                              });
                            }
                          },
                          onSubmitted: (value) {
                            if (_searchResults.isNotEmpty) {
                              _goToPreviousSearchResult();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // AI 요약 버튼
              if (widget.room.summaryEnabled)
                _buildAISummaryButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// 키보드 위 검색 툴바
  Widget _buildKeyboardSearchToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // 선택된 사용자 표시
              if (_selectedSender != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(AppColors.summaryPrimary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 14,
                        color: Color(AppColors.summaryPrimary),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedSender!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(AppColors.summaryPrimary),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSender = null;
                          });
                          // 검색어가 있으면 다시 검색
                          if (_searchController.text.isNotEmpty) {
                            _performSearch(_searchController.text);
                          }
                        },
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: Color(AppColors.summaryPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_selectedSender != null) const SizedBox(width: 12),
              // 검색 결과 개수
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _searchResults.isEmpty
                      ? Colors.red.withOpacity(0.1)
                      : Color(AppColors.summaryPrimary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _searchResults.isEmpty
                      ? '0개'
                      : '${_currentSearchIndex + 1}/${_searchResults.length}',
                  style: TextStyle(
                    color: _searchResults.isEmpty
                        ? Colors.red[700]
                        : Color(AppColors.summaryPrimary),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              // 이전 결과
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                color: _searchResults.isNotEmpty
                    ? Color(AppColors.summaryPrimary)
                    : Colors.grey[400],
                onPressed: _searchResults.isNotEmpty
                    ? _goToPreviousSearchResult
                    : null,
              ),
              // 다음 결과
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                color: _searchResults.isNotEmpty
                    ? Color(AppColors.summaryPrimary)
                    : Colors.grey[400],
                onPressed: _searchResults.isNotEmpty
                    ? _goToNextSearchResult
                    : null,
              ),
              const SizedBox(width: 4),
              // 닫기 버튼
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                color: Colors.grey[600],
                onPressed: _exitSearchMode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 검색 결과 네비게이션 바 (카카오톡 스타일, 채팅 입력창 위에 표시)
  Widget _buildSearchResultBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // 왼쪽: 사람 검색 버튼
              _buildSearchToolbarButton(
                icon: Stack(
                  children: [
                    Icon(
                      Icons.person,
                      size: 18,
                      color: _selectedSender != null
                          ? Colors.white
                          : Colors.grey[700],
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Icon(
                        Icons.search,
                        size: 10,
                        color: _selectedSender != null
                            ? Colors.white
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                isActive: _selectedSender != null,
                onTap: _showSenderSelectionDialog,
              ),
              const SizedBox(width: 8),
              // 날짜 이동 버튼
              _buildSearchToolbarButton(
                icon: Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey[700],
                ),
                isActive: false,
                onTap: _showDatePickerDialog,
              ),
              // 중앙: 검색 결과 개수
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _searchResults.isEmpty
                          ? Colors.grey[100]
                          : Color(AppColors.summaryPrimary).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _searchResults.isEmpty
                          ? '결과 없음'
                          : '${_currentSearchIndex + 1} / ${_searchResults.length}',
                      style: TextStyle(
                        color: _searchResults.isEmpty
                            ? Colors.grey[500]
                            : Color(AppColors.summaryPrimary),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              // 오른쪽: 위/아래 화살표
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 26),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                color: _searchResults.isNotEmpty
                    ? Color(AppColors.summaryPrimary)
                    : Colors.grey[300],
                onPressed: _searchResults.isNotEmpty
                    ? _goToPreviousSearchResult
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 26),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                color: _searchResults.isNotEmpty
                    ? Color(AppColors.summaryPrimary)
                    : Colors.grey[300],
                onPressed: _searchResults.isNotEmpty
                    ? _goToNextSearchResult
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 검색 툴바 버튼 위젯
  Widget _buildSearchToolbarButton({
    required Widget icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive
              ? Color(AppColors.summaryPrimary)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(child: icon),
      ),
    );
  }

  /// 날짜 선택 다이얼로그
  Future<void> _showDatePickerDialog() async {
    if (_messages.isEmpty) return;

    // 키보드 숨기기
    FocusScope.of(context).unfocus();
    _searchFocusNode.unfocus();

    // 메시지의 날짜 범위 계산
    final oldestDate = _messages.last.createTime;
    final newestDate = _messages.first.createTime;

    // 이전에 선택한 날짜가 있으면 그것을 사용, 없으면 최신 날짜 사용
    final initialDate = _lastSelectedDate ?? newestDate;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: oldestDate,
      lastDate: newestDate,
      helpText: '이동할 날짜 선택',
      cancelText: '취소',
      confirmText: '이동',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(AppColors.summaryPrimary),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      _lastSelectedDate = selectedDate;  // 선택한 날짜 저장
      _scrollToDate(selectedDate);
    }
  }

  /// 특정 날짜로 스크롤
  void _scrollToDate(DateTime targetDate) {
    if (!_scrollController.hasClients || _messages.isEmpty) return;
    
    // 선택한 날짜에 해당하는 첫 번째 메시지 찾기 (가장 오래된 메시지, 즉 해당 날짜의 첫 번째 메시지)
    // reverse: true이므로 index가 클수록 오래된 메시지
    int targetIndex = -1;
    for (int i = _messages.length - 1; i >= 0; i--) {
      final messageDate = _messages[i].createTime;
      if (messageDate.year == targetDate.year &&
          messageDate.month == targetDate.month &&
          messageDate.day == targetDate.day) {
        targetIndex = i;
        break;  // 첫 번째(가장 오래된) 메시지를 찾으면 즉시 종료
      }
    }

    if (targetIndex != -1) {
      // reverse: true ListView에서:
      // - offset = 0 → index 0(최신)이 화면 하단
      // - offset 증가 → 화면이 위로 스크롤 (오래된 메시지가 보임)
      //
      // targetIndex 메시지가 화면 상단에 오도록 스크롤
      final baseOffset = _calculateScrollOffset(targetIndex);
      final messageHeight = _estimateMessageHeight(_messages[targetIndex]);
      final screenHeight = MediaQuery.of(context).size.height;
      final topMargin = screenHeight * 0.1; // 상단 10% 여백
      
      // 메시지가 화면 상단 10% 위치에 오도록 조정
      // baseOffset으로 스크롤하면 메시지가 화면 하단에 위치하므로,
      // 화면 높이만큼 빼고 상단 여백을 더하면 상단에 위치
      final adjustedOffset = (baseOffset - screenHeight + topMargin + messageHeight)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      
      _scrollController.animateTo(
        adjustedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      HapticFeedback.selectionClick();
    } else {
      // 해당 날짜의 메시지가 없으면 안내
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${DateFormat('yyyy년 M월 d일').format(targetDate)}의 메시지가 없습니다'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 요약 모드 하단 네비게이션 바
  Widget _buildSummaryBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // 왼쪽: 감소 버튼
              _buildSummaryToolbarButton(
                icon: Icon(
                  Icons.remove,
                  size: 18,
                  color: _selectedMessageCount > 5 ? Colors.grey[700] : Colors.grey[300],
                ),
                isActive: false,
                onTap: _selectedMessageCount > 5
                    ? () async {
                        await _updateSummaryCount(_selectedMessageCount - 1);
                        HapticFeedback.selectionClick();
                      }
                    : null,
              ),
              const SizedBox(width: 8),
              // 중앙: 개수 표시 (터치하면 직접 입력)
              Expanded(
                child: GestureDetector(
                  onTap: _showCountInputDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Color(AppColors.summaryPrimary).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_selectedMessageCount',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(AppColors.summaryPrimary),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '개 메시지 선택됨',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(AppColors.summaryPrimary).withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 오른쪽: 증가 버튼
              _buildSummaryToolbarButton(
                icon: Icon(
                  Icons.add,
                  size: 18,
                  color: _selectedMessageCount < _messages.length.clamp(1, 300)
                      ? Colors.grey[700]
                      : Colors.grey[300],
                ),
                isActive: false,
                onTap: _selectedMessageCount < _messages.length.clamp(1, 300)
                    ? () async {
                        await _updateSummaryCount(_selectedMessageCount + 1);
                        HapticFeedback.selectionClick();
                      }
                    : null,
              ),
              const SizedBox(width: 12),
              // 요약 실행 버튼
              GestureDetector(
                onTap: () {
                  _requestSummary();
                  HapticFeedback.mediumImpact();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Color(AppColors.summaryPrimary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        '요약',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 요약 툴바 버튼 위젯
  Widget _buildSummaryToolbarButton({
    required Widget icon,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive
              ? Color(AppColors.summaryPrimary)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(child: icon),
      ),
    );
  }

  /// 하단 채팅 입력창
  Widget _buildChatInputBar() {
    return Container(
      key: _chatInputBarKey,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
          child: Row(
            children: [
              // 텍스트 입력창
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    maxHeight: 80,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _chatInputController,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: '메시지 입력',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                    ),
                    onChanged: (value) {
                      setState(() {}); // 전송 버튼 상태 업데이트
                    },
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _sendMessage(value.trim());
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 전송 버튼
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _chatInputController.text.trim().isNotEmpty
                      ? const Color(0xFF2196F3)
                      : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, size: 20),
                  color: Colors.white,
                  onPressed: _chatInputController.text.trim().isNotEmpty
                      ? () {
                          _sendMessage(_chatInputController.text.trim());
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 하단바 (검색창 + AI 요약 버튼) - 레거시 (사용 안 함)
  Widget _buildBottomBar() {
    // 요약 모드일 때는 요약 모드 패널만 표시
    if (_isSummaryMode) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // 취소 버튼 (현대적인 디자인)
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.11,
                  height: MediaQuery.of(context).size.width * 0.11,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 22),
                      color: Colors.grey[700],
                      onPressed: () {
                        _exitSummaryMode();
                        if (widget.room.unreadCount == 0) {
                          setState(() {
                            _isDragHandleVisible = false;
                          });
                        }
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                // 개수 조절 (직접 입력 가능)
                Expanded(
                  child: Container(
                    height: MediaQuery.of(context).size.width * 0.11,
                    decoration: BoxDecoration(
                      color: Color(AppColors.summaryPrimary).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 감소 버튼
                        IconButton(
                          icon: Icon(
                            Icons.remove_circle,
                            color: _selectedMessageCount > 1
                                ? Color(AppColors.summaryPrimary)
                                : Colors.grey[400],
                          ),
                          onPressed: _selectedMessageCount > 5
                              ? () async {
                                  await _updateSummaryCount(_selectedMessageCount - 1);
                                  HapticFeedback.selectionClick();
                                }
                              : null,
                        ),
                        // 숫자 입력 (탭하면 다이얼로그)
                        GestureDetector(
                          onTap: () => _showCountInputDialog(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$_selectedMessageCount',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(AppColors.summaryPrimary),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '개',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(AppColors.summaryPrimary).withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.edit_rounded,
                                  size: 14,
                                  color: Color(AppColors.summaryPrimary).withOpacity(0.6),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 증가 버튼
                        IconButton(
                          icon: Icon(
                            Icons.add_circle,
                            color: _selectedMessageCount < _messages.length.clamp(1, 300)
                                ? Color(AppColors.summaryPrimary)
                                : Colors.grey[400],
                          ),
                          onPressed: _selectedMessageCount < _messages.length.clamp(1, 300)
                              ? () async {
                                  await _updateSummaryCount(_selectedMessageCount + 1);
                                  HapticFeedback.selectionClick();
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                // 요약하기 버튼 (그라데이션)
                Container(
                  height: MediaQuery.of(context).size.width * 0.11,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(AppColors.summaryPrimary),
                        Color(AppColors.summaryPrimary).withOpacity(0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Color(AppColors.summaryPrimary).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      _requestSummary();
                      HapticFeedback.mediumImpact();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 18),
                        SizedBox(width: 6),
                        Text(
                          '요약',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 검색창 (더 세련되게)
              Expanded(
                child: Container(
                  height: MediaQuery.of(context).size.width * 0.11,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _isSearchMode 
                          ? Color(AppColors.summaryPrimary).withOpacity(0.3)
                          : Colors.grey[200]!,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(
                        Icons.search_rounded,
                        color: _isSearchMode 
                            ? Color(AppColors.summaryPrimary)
                            : Colors.grey[500],
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: '대화 검색',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          onChanged: (value) {
                            _performSearch(value);
                            if (value.isNotEmpty && !_isSearchMode) {
                              setState(() {
                                _isSearchMode = true;
                              });
                            } else if (value.isEmpty && _isSearchMode) {
                              setState(() {
                                _isSearchMode = false;
                              });
                            }
                          },
                          onSubmitted: (value) {
                            if (_searchResults.isNotEmpty) {
                              _goToPreviousSearchResult();
                            }
                          },
                        ),
                      ),
                      // 검색 결과 표시 및 네비게이션
                      if (_isSearchMode && _searchController.text.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _searchResults.isEmpty
                                ? Colors.red.withOpacity(0.1)
                                : Color(AppColors.summaryPrimary).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _searchResults.isEmpty
                                ? '0개'
                                : '${_currentSearchIndex + 1}/${_searchResults.length}',
                            style: TextStyle(
                              color: _searchResults.isEmpty
                                  ? Colors.red[700]
                                  : Color(AppColors.summaryPrimary),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36),
                          color: _searchResults.isNotEmpty
                              ? Color(AppColors.summaryPrimary)
                              : Colors.grey[400],
                          onPressed: _searchResults.isNotEmpty
                              ? _goToPreviousSearchResult
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36),
                          color: _searchResults.isNotEmpty
                              ? Color(AppColors.summaryPrimary)
                              : Colors.grey[400],
                          onPressed: _searchResults.isNotEmpty
                              ? _goToNextSearchResult
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36),
                          color: Colors.grey[600],
                          onPressed: _exitSearchMode,
                        ),
                      ] else
                        const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // AI 요약 버튼 (요약 기능이 켜져있을 때만 표시)
              if (widget.room.summaryEnabled)
                _buildAISummaryButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// AI 요약 버튼 (읽지 않은 메시지 수에 따라 다른 UI)
  Widget _buildAISummaryButton() {
    final unreadCount = widget.room.unreadCount;
    final hasUnreadMessages = unreadCount >= 5;

    if (hasUnreadMessages) {
      // 읽지 않은 메시지 5개 이상: 눈에 띄는 AI 요약하기 버튼 (그라데이션 + 애니메이션)
      final summaryCount = unreadCount.clamp(1, 300);  // 최대 300개
      return Container(
        height: MediaQuery.of(context).size.width * 0.1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(AppColors.summaryPrimary),
              Color(AppColors.summaryPrimary).withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(AppColors.summaryPrimary).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () async {
            setState(() {
              _isDragHandleVisible = true;
            });
            await _enterSummaryMode(summaryCount);
            HapticFeedback.mediumImpact();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 18),
              const SizedBox(width: 6),
              Text(
                '$summaryCount개 요약',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // 읽지 않은 메시지 없음: 작은 AI 버튼 (현대적인 디자인)
      final buttonSize = MediaQuery.of(context).size.width * 0.11;
      return Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: Color(AppColors.summaryPrimary).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: () async {
            setState(() {
              _isDragHandleVisible = true;
            });
            await _enterSummaryMode(_defaultSummaryCount);
            HapticFeedback.lightImpact();
          },
          padding: EdgeInsets.zero,
          icon: Icon(
            Icons.auto_awesome,
            color: Color(AppColors.summaryPrimary),
            size: 22,
          ),
          tooltip: 'AI 요약',
        ),
      );
    }
  }

  /// 요약 요청 (LLM 서비스 연동)
  Future<void> _requestSummary() async {
    if (!mounted) return;
    if (_selectedMessageCount == 0 || _messages.isEmpty) return;

    // 선택된 메시지들 추출 (최신 메시지부터 위로 N개)
    // ⚠️ ListView.reverse=true이므로 index 0이 최신 메시지
    // 서버에는 오래된 순서(시간순)로 전송해야 LLM 요약 품질이 좋음
    final selectedMessages = _messages
        .take(_selectedMessageCount)
        .toList()
        .reversed
        .toList();

    if (selectedMessages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('요약할 메시지를 선택해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 메시지가 5개 미만이면 요약 불가
    if (selectedMessages.length < 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('메시지가 ${selectedMessages.length}개입니다. 요약은 5개 이상의 메시지가 필요합니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // 메시지를 API 요청 형식으로 변환
    final messagesForApi = selectedMessages.map((m) => {
      'sender': m.sender,
      'message': m.message,
      'createTime': m.createTime.toIso8601String(),
    }).toList();

    // 개인정보 마스킹 처리 (LLM에 보내기 전)
    final privacyMaskingService = PrivacyMaskingService();
    final maskedMessages = privacyMaskingService.maskMessages(messagesForApi);

    // 로딩 표시
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final llmService = LlmService();
      final result = await llmService.summarizeMessages(
        messages: maskedMessages,
        roomName: widget.room.roomName,
      );

      // 로딩 다이얼로그 안전하게 닫기
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      if (result != null) {
        // 서버 응답 필드명: summaryMessage, summarySubject
        final summaryMessage = result['summaryMessage'] ?? result['summary'] ?? '';
        final summarySubject = result['summarySubject'] ?? '${selectedMessages.length}개 메시지 요약';
        
        debugPrint('📝 요약 저장: $summarySubject');
        debugPrint('📝 요약 내용: $summaryMessage');
        
        // 요약 결과 로컬 DB에 저장
        await _localDb.saveSummary(
          roomId: widget.room.id,
          summaryName: summarySubject,
          summaryMessage: summaryMessage,
          summaryDetailMessage: result['summaryDetailMessage'],
          summaryFrom: selectedMessages.first.createTime,
          summaryTo: selectedMessages.last.createTime,
        );

        // 선택된 메시지들에서 고유한 발신자 수 계산
        final uniqueSenders = selectedMessages
            .map((m) => m.sender)
            .where((sender) => sender.isNotEmpty && sender != '나')
            .toSet();
        final participantCount = uniqueSenders.length;
        
        // 시간 형식 변환 (HH:mm 형식)
        final startTime = DateFormat('HH:mm').format(selectedMessages.first.createTime);
        final endTime = DateFormat('HH:mm').format(selectedMessages.last.createTime);
        
        // 요약 모드 먼저 종료 (블럭 선택 해제)
        debugPrint('🔵 요약 완료 - _exitSummaryMode 호출 전');
        _exitSummaryMode();
        debugPrint('🔵 요약 완료 - _exitSummaryMode 호출 후, _isSummaryMode: $_isSummaryMode');
        
        // 요약 결과 표시
        _showSummaryBottomSheet({
          'summaryMessage': summaryMessage,
          'summaryDetailMessage': result['summaryDetailMessage'], // 상세 메시지 추가
          'summarySubject': summarySubject,
          'messageCount': selectedMessages.length,
          'participantCount': participantCount, // 참여자 수 추가
          'startTime': startTime, // 시작 시간 추가
          'endTime': endTime, // 종료 시간 추가
          'summaryFrom': selectedMessages.first.createTime.toIso8601String(),
          'summaryTo': selectedMessages.last.createTime.toIso8601String(),
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('요약 생성에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on RateLimitException catch (e) {
      // 로딩 다이얼로그 닫기
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('분당 요청 횟수를 초과했습니다. ${e.retryAfterSeconds}초 후 다시 시도해주세요.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on AuthException catch (e) {
      // 로딩 다이얼로그 닫기
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on TimeoutException {
      // 로딩 다이얼로그 닫기
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('요청 시간이 초과되었습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      // 로딩 다이얼로그 안전하게 닫기
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('요약 요청 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 요약 결과 BottomSheet 표시 (완전히 새로운 디자인)
  /// 요약 결과 BottomSheet 표시 (ListView 구조로 오버플로우 방지)
  void _showSummaryBottomSheet(Map<String, dynamic> summaryData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            physics: const BouncingScrollPhysics(),
            children: [
              // 핸들바
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 14, bottom: 8),
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              
              // 헤더
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(AppColors.summaryPrimary).withOpacity(0.1),
                      Color(AppColors.summaryPrimary).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Color(AppColors.summaryPrimary).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(AppColors.summaryPrimary),
                            Color(AppColors.summaryPrimary).withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Color(AppColors.summaryPrimary).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI 요약',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(AppColors.summaryPrimary).withOpacity(0.8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            summaryData['summarySubject'] ?? '대화 요약',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A1A),
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 20),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // 정보 카드들
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.05,
                ),
                child: SizedBox(
                  height: 100, // 높이를 더 넉넉하게 (오버플로우 방지)
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          Icons.chat_bubble_rounded,
                          '${summaryData['messageCount'] ?? 0}개',
                          '메시지',
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          Icons.people_rounded,
                          '${summaryData['participantCount'] ?? 0}명',
                          '참여자',
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          Icons.schedule_rounded,
                          _formatTimeRange(
                            summaryData['startTime'] ?? '',
                            summaryData['endTime'] ?? '',
                          ),
                          '시간',
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // 요약 내용 (상세보기 기능 포함)
              _buildSummaryContentCard(
                summaryMessage: summaryData['summaryMessage'] ?? '',
                summaryDetailMessage: summaryData['summaryDetailMessage'],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      // BottomSheet가 닫힐 때 선택 모드 확실하게 해제
      debugPrint('🟢 BottomSheet whenComplete 호출, mounted: $mounted, _isSummaryMode: $_isSummaryMode');
      if (mounted) {
        _exitSummaryMode();
        debugPrint('🟢 BottomSheet whenComplete 후 _isSummaryMode: $_isSummaryMode');
      }
    });
  }

  /// 정보 카드 위젯
  Widget _buildInfoCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // 최소 크기만 사용
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color.withOpacity(0.9),
              letterSpacing: -0.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 요약 내용 카드 (상세보기 기능 포함) - BottomSheet용
  Widget _buildSummaryContentCard({
    required String summaryMessage,
    String? summaryDetailMessage,
  }) {
    bool _showDetail = false; // builder 밖에서 선언하여 상태 유지
    
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[200]!, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 요약 메시지 (마크다운 렌더링)
              Padding(
                padding: const EdgeInsets.all(24),
                child: MarkdownBody(
                  data: summaryMessage,
                  selectable: true,
                  softLineBreak: true,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                      fontSize: 16,
                      height: 1.8,
                      color: Color(0xFF2A2A2A),
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                    pPadding: const EdgeInsets.only(bottom: 8),
                    h1: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                      color: Color(0xFF2A2A2A),
                    ),
                    h1Padding: const EdgeInsets.only(bottom: 12, top: 8),
                    h2: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                      color: Color(0xFF2A2A2A),
                    ),
                    h2Padding: const EdgeInsets.only(bottom: 10, top: 8),
                    h3: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: Color(0xFF2A2A2A),
                    ),
                    h3Padding: const EdgeInsets.only(bottom: 8, top: 6),
                    strong: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A2A2A),
                    ),
                    em: const TextStyle(
                      fontStyle: FontStyle.italic,
                    ),
                    blockSpacing: 12,
                    listIndent: 24,
                    listBullet: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2196F3),
                    ),
                    listBulletPadding: const EdgeInsets.only(right: 8),
                    code: TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                      backgroundColor: Colors.grey[200],
                      color: Colors.black87,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    codeblockPadding: const EdgeInsets.all(12),
                    blockquote: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[700],
                    ),
                    blockquoteDecoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: const Color(0xFF2196F3),
                          width: 4,
                        ),
                      ),
                    ),
                    blockquotePadding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                  ),
                ),
              ),
              
              // 상세보기 버튼 (상세 메시지가 있을 때만 표시)
              if (summaryDetailMessage != null && summaryDetailMessage.isNotEmpty) ...[
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey[200]!,
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _showDetail = !_showDetail;
                    });
                  },
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    decoration: BoxDecoration(
                      color: _showDetail 
                          ? const Color(0xFF2196F3).withOpacity(0.05)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _showDetail ? '상세보기 접기' : '상세보기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _showDetail 
                                ? const Color(0xFF2196F3)
                                : const Color(0xFF2196F3),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: _showDetail ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: const Color(0xFF2196F3),
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // 상세 메시지 (펼쳐질 때)
                if (_showDetail)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.02),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        // 상세 메시지 제목
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: const Color(0xFF2196F3).withOpacity(0.7),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '상세 내용',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2196F3).withOpacity(0.8),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 상세 메시지 내용 (마크다운 렌더링)
                        MarkdownBody(
                          data: summaryDetailMessage,
                          selectable: true,
                          softLineBreak: true,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              fontSize: 15,
                              height: 1.7,
                              color: Color(0xFF2A2A2A),
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.2,
                            ),
                            pPadding: const EdgeInsets.only(bottom: 8),
                            h1: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                              color: Color(0xFF2A2A2A),
                            ),
                            h1Padding: const EdgeInsets.only(bottom: 10, top: 6),
                            h2: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                              color: Color(0xFF2A2A2A),
                            ),
                            h2Padding: const EdgeInsets.only(bottom: 8, top: 6),
                            h3: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                              color: Color(0xFF2A2A2A),
                            ),
                            h3Padding: const EdgeInsets.only(bottom: 6, top: 4),
                            strong: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2A2A2A),
                            ),
                            em: const TextStyle(
                              fontStyle: FontStyle.italic,
                            ),
                            blockSpacing: 10,
                            listIndent: 24,
                            listBullet: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF2196F3),
                            ),
                            listBulletPadding: const EdgeInsets.only(right: 8),
                            code: TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                              backgroundColor: Colors.grey[200],
                              color: Colors.black87,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            codeblockPadding: const EdgeInsets.all(12),
                            blockquote: TextStyle(
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[700],
                            ),
                            blockquoteDecoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: const Color(0xFF2196F3),
                                  width: 4,
                                ),
                              ),
                            ),
                            blockquotePadding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 시간 범위 포맷팅
  String _formatTimeRange(String startTime, String endTime) {
    if (startTime.isEmpty || endTime.isEmpty) return '-';
    // "09:30 - 14:42" 형태로 반환
    return '$startTime~$endTime';
  }

  /// 요약 히스토리 화면으로 이동
  Future<void> _showSummaryHistory() async {
    if (!mounted) return;

    // 검색 모드 종료 (노란색 하이라이트 제거)
    if (_isSearchMode) {
      _exitSearchMode();
    }

    // 요약 모드 종료 (선택 범위 하이라이트 제거)
    if (_isSummaryMode) {
      setState(() {
        _isSummaryMode = false;
        _selectedMessageCount = 0;
        _selectionStartIndex = null;
      });
    }

    // 요약 히스토리 화면으로 이동
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SummaryHistoryScreen(
          roomId: widget.room.id,
          roomName: widget.room.roomName,
        ),
      ),
    );
  }

  Widget _buildDateDivider(DateTime date) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF8BA4B8).withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDate(date),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// "여기까지 읽으셨습니다" 구분선 (카카오톡 스타일)
  Widget _buildUnreadDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFF8BA4B8).withOpacity(0.4),
                  ],
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF8BA4B8).withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '여기까지 읽었습니다',
              style: TextStyle(
                color: Color(0xFF6B8599),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF8BA4B8).withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 검색어를 하이라이트한 텍스트 위젯 생성
  Widget _buildHighlightedText(String text, String? searchQuery) {
    if (searchQuery == null || searchQuery.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF1A1A1A),
          height: 1.4,
          letterSpacing: -0.2,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = searchQuery.toLowerCase();
    final queryIndex = lowerText.indexOf(lowerQuery);

    if (queryIndex == -1) {
      // 검색어가 없으면 일반 텍스트
      return Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF1A1A1A),
          height: 1.4,
          letterSpacing: -0.2,
        ),
      );
    }

    // 검색어를 하이라이트한 TextSpan 리스트 생성
    final spans = <TextSpan>[];
    int lastIndex = 0;
    int currentIndex = queryIndex;

    while (currentIndex != -1) {
      // 검색어 이전 텍스트
      if (currentIndex > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, currentIndex),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1A1A1A),
            height: 1.4,
            letterSpacing: -0.2,
          ),
        ));
      }

      // 검색어 하이라이트 (원본 텍스트에서 해당 부분 추출)
      final highlightText = text.substring(
        currentIndex,
        currentIndex + searchQuery.length,
      );
      spans.add(TextSpan(
        text: highlightText,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF1A1A1A),
          height: 1.4,
          letterSpacing: -0.2,
          backgroundColor: Color(0xFFFFEB3B), // 노란색 배경으로 하이라이트
        ),
      ));

      lastIndex = currentIndex + searchQuery.length;
      currentIndex = lowerText.indexOf(lowerQuery, lastIndex);
    }

    // 마지막 검색어 이후 텍스트
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF1A1A1A),
          height: 1.4,
          letterSpacing: -0.2,
        ),
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }

  Widget _buildMessageBubble(
    MessageItem message, {
    required bool showProfile,
    required bool showName,
    required bool showTime,
    required bool isLastInGroup,
    bool isSearchResult = false,
    bool isCurrentSearchResult = false,
    String? searchQuery,
    bool isSenderSearch = false,
  }) {
    final profileFile = _getSenderProfileImage(message.sender);
    
    // 내가 보낸 메시지인지 확인 (정확한 매칭만 허용)
    final isSentByMe = message.sender == '나';
    
    // 배경색 결정 - 내가 보낸 메시지는 연한 노란색, 다른 사람은 흰색
    final Color bubbleColor = isSentByMe 
        ? const Color(0xFFFFF176)  // 연한 노란색 (조금 더 진하게)
        : Colors.white;

    return Padding(
      padding: EdgeInsets.only(
        left: 10,
        right: 10,
        bottom: isLastInGroup ? 10 : 2,
        top: showName ? 8 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // 내가 보낸 메시지가 아니면 프로필 이미지 표시
          if (!isSentByMe) ...[
            if (showName)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: profileFile != null
                    ? ClipOval(
                        child: Image.file(
                          profileFile,
                          key: ValueKey(profileFile.path),
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                          cacheWidth: 76,
                          cacheHeight: 76,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar(message.sender);
                          },
                        ),
                      )
                    : _buildDefaultAvatar(message.sender),
              )
            else
              const SizedBox(width: 46), // 프로필 공간 유지
          ],
          
          // 메시지 내용
          Expanded(
            child: Column(
              crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // 보낸사람 이름 (그룹의 첫 메시지만 표시, 내가 보낸 메시지는 표시 안 함)
                if (showName && !isSentByMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.sender,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF555555),
                      ),
                    ),
                  ),
                // 메시지 내용 (이미지 + 텍스트)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 링크 메시지인 경우 특별한 UI 표시
                    if (message.isLinkMessage && message.imagePath != null)
                      _buildLinkMessage(message, isSentByMe, showTime)
                    else ...[
                      // 일반 이미지가 있으면 먼저 표시 (말풍선 없이)
                      if (message.imagePath != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildImageWidget(message.imagePath!, message: message),
                          ),
                        ),
                      // 텍스트가 있으면 말풍선으로 표시 (이미지가 있을 때는 시스템 메시지 제외)
                      if (message.message.isNotEmpty && 
                          message.message != '사진을 보냈습니다' && 
                          message.message != '이모티콘을 보냈습니다' &&
                          message.message.trim().isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            // 내가 보낸 메시지가 아니면 말풍선 먼저, 내가 보낸 메시지는 시간 먼저
                            if (!isSentByMe) ...[
                              // 말풍선 (카카오톡 스타일)
                              Flexible(
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: bubbleColor,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(showName ? 4 : 16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: const Radius.circular(16),
                                      bottomRight: const Radius.circular(16),
                                    ),
                                    border: isCurrentSearchResult
                                        ? Border.all(color: const Color(0xFFFF9800), width: 2)
                                        : null,
                                  ),
                                  child: _buildHighlightedText(message.message, searchQuery),
                                ),
                              ),
                              // 시간 표시
                              if (showTime)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6, bottom: 2),
                                  child: Text(
                                    _formatTime(message.createTime),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ),
                            ] else ...[
                              // 내가 보낸 메시지: 시간 먼저
                              if (showTime)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6, bottom: 2),
                                  child: Text(
                                    _formatTime(message.createTime),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ),
                              // 말풍선 (연한 노란색)
                              Flexible(
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: bubbleColor,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: const Radius.circular(16),
                                      bottomRight: const Radius.circular(16),
                                    ),
                                    border: isCurrentSearchResult
                                        ? Border.all(color: const Color(0xFFFF9800), width: 2)
                                        : null,
                                  ),
                                  child: _buildHighlightedText(message.message, searchQuery),
                                ),
                              ),
                            ],
                          ],
                        )
                      else if (message.imagePath != null && showTime)
                        // 이미지만 있고 텍스트가 없을 때 시간 표시
                        Padding(
                          padding: const EdgeInsets.only(left: 6, bottom: 2),
                          child: Text(
                            _formatTime(message.createTime),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 이미지 위젯 생성 (content:// 또는 file:// URI 처리)
  Widget _buildImageWidget(String imagePath, {MessageItem? message}) {
    // context가 없을 경우를 대비해 안전하게 처리
    final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? 400.0;
    
    // 이모티콘인지 확인 (메시지 텍스트에 "이모티콘" 또는 "스티커"가 포함되어 있거나, 이미지 경로에 emoticon/sticker가 포함된 경우)
    final imagePathLower = imagePath.toLowerCase();
    final isEmoticon = (message?.message.contains('이모티콘') ?? false) ||
                       (message?.message.contains('스티커') ?? false) ||
                       imagePathLower.contains('emoticon') ||
                       imagePathLower.contains('sticker');
    
    // 이모티콘은 작게, 사진은 크게
    final maxImageWidth = isEmoticon 
        ? screenWidth * 0.3  // 이모티콘: 화면 너비의 30%
        : screenWidth * 0.7; // 사진: 화면 너비의 70%
    final maxImageHeight = isEmoticon
        ? screenWidth * 0.3  // 이모티콘: 화면 너비의 30%
        : screenWidth * 0.9; // 사진: 최대 높이 제한
    
    // content:// URI인 경우 - Android에서 절대 경로로 변환했으므로 일반적으로 file:// 또는 절대 경로
    // 하지만 혹시 모를 경우를 대비해 처리
    if (imagePath.startsWith('content://')) {
      // content:// URI는 Flutter에서 직접 읽을 수 없으므로 에러 표시
      debugPrint('⚠️ content:// URI는 직접 읽을 수 없습니다: $imagePath');
      return Container(
        width: maxImageWidth,
        height: 200,
        color: Colors.grey[200],
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: Colors.grey),
            SizedBox(height: 4),
            Text(
              '이미지를 불러올 수 없습니다',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    // file:// URI 또는 절대 경로인 경우
    final file = File(imagePath.startsWith('file://') 
        ? imagePath.substring(7) 
        : imagePath);
    
    if (!file.existsSync()) {
      debugPrint('⚠️ 이미지 파일이 존재하지 않습니다: ${file.path}');
      return Container(
        width: maxImageWidth,
        height: 200,
        color: Colors.grey[200],
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: Colors.grey),
            SizedBox(height: 4),
            Text(
              '이미지를 찾을 수 없습니다',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxImageWidth,
        maxHeight: maxImageHeight,
      ),
      child: Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('⚠️ 이미지 로드 실패: ${file.path}, $error');
          return Container(
            width: maxImageWidth,
            height: 200,
            color: Colors.grey[200],
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.grey),
                SizedBox(height: 4),
                Text(
                  '이미지 로드 실패',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 링크 메시지 위젯 (카카오톡 스타일)
  Widget _buildLinkMessage(MessageItem message, bool isSentByMe, bool showTime) {
    // 메시지에서 URL 추출
    final urlPattern = RegExp(r'(https?://[^\s]+|www\.[^\s]+)');
    final urlMatch = urlPattern.firstMatch(message.message);
    final url = urlMatch?.group(0) ?? '';
    final displayText = message.message.replaceAll(urlPattern, '').trim();
    
    // URL이 http:// 또는 https://로 시작하지 않으면 추가
    final fullUrl = url.isNotEmpty && !url.startsWith('http') 
        ? 'https://$url' 
        : url;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final maxImageWidth = screenWidth * 0.7;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 링크 미리보기 이미지
        GestureDetector(
          onTap: () async {
            if (fullUrl.isNotEmpty) {
              final uri = Uri.tryParse(fullUrl);
              if (uri != null) {
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('링크를 열 수 없습니다: $fullUrl')),
                    );
                  }
                }
              }
            }
          },
          child: Container(
            constraints: BoxConstraints(
              maxWidth: maxImageWidth,
              maxHeight: screenWidth * 0.5,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이미지
                  if (message.imagePath != null)
                    SizedBox(
                      width: double.infinity,
                      child: _buildImageWidget(message.imagePath!, message: message),
                    ),
                  // 링크 정보
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 링크 URL
                        if (url.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.link, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  url.length > 50 ? '${url.substring(0, 50)}...' : url,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[700],
                                    decoration: TextDecoration.underline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        // 추가 텍스트가 있으면 표시
                        if (displayText.isNotEmpty) ...[
                          if (url.isNotEmpty) const SizedBox(height: 4),
                          Text(
                            displayText,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[800],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 시간 표시
        if (showTime)
          Padding(
            padding: EdgeInsets.only(
              left: isSentByMe ? 0 : 6,
              right: isSentByMe ? 6 : 0,
              bottom: 2,
              top: 4,
            ),
            child: Text(
              _formatTime(message.createTime),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ),
      ],
    );
  }

  /// 기본 아바타 위젯 (프로필 이미지 없을 때)
  Widget _buildDefaultAvatar(String sender) {
    // 이름 기반 색상 생성
    final colors = [
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFF45B7D1),
      const Color(0xFFFFA07A),
      const Color(0xFF98D8C8),
      const Color(0xFFF7DC6F),
      const Color(0xFFBB8FCE),
      const Color(0xFF85C1E9),
    ];
    final colorIndex = sender.isNotEmpty ? sender.codeUnitAt(0) % colors.length : 0;
    
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: colors[colorIndex],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          sender.isNotEmpty ? sender[0] : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

}

/// 요약 히스토리 오버레이 위젯
class _SummaryHistoryOverlay extends StatefulWidget {
  final List<SummaryItem> summaries;
  final VoidCallback onClose;

  const _SummaryHistoryOverlay({
    required this.summaries,
    required this.onClose,
  });

  @override
  State<_SummaryHistoryOverlay> createState() => _SummaryHistoryOverlayState();
}

class _SummaryHistoryOverlayState extends State<_SummaryHistoryOverlay> {
  late PageController _pageController;
  int _currentIndex = 0;

  // 드래그 관련 상태
  double _dragStartX = 0;
  double _accumulatedDrag = 0;
  static const double _dragThreshold = 30.0; // 페이지 이동에 필요한 드래그 거리

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    // 배경 스크롤 제거 - 오버레이에서는 스크롤하지 않음
  }
  
  /// 5페이지 앞으로 이동 (끝에 도달하면 마지막 페이지로)
  void _jumpForward() {
    final totalPages = widget.summaries.length;
    final targetPage = (_currentIndex + 5).clamp(0, totalPages - 1);
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    HapticFeedback.selectionClick();
  }
  
  /// 5페이지 뒤로 이동 (처음에 도달하면 첫 페이지로)
  void _jumpBackward() {
    final targetPage = (_currentIndex - 5).clamp(0, widget.summaries.length - 1);
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    HapticFeedback.selectionClick();
  }

  /// 페이지 인디케이터 생성 (최대 5개만 표시, 현재 페이지 중심)
  List<Widget> _buildPageIndicators() {
    final totalPages = widget.summaries.length;
    
    // 5개 이하면 전부 표시
    if (totalPages <= 5) {
      return List.generate(
        totalPages,
        (index) => GestureDetector(
          onTap: () {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          },
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentIndex == index
                  ? Colors.white
                  : Colors.white.withOpacity(0.4),
            ),
          ),
        ),
      );
    }
    
    // 5개 초과: 현재 페이지를 중심으로 5개 표시
    // 현재 페이지가 항상 가운데(또는 가능한 가운데)에 오도록 계산
    int start;
    if (_currentIndex <= 2) {
      // 처음 부분: 0~4 표시
      start = 0;
    } else if (_currentIndex >= totalPages - 3) {
      // 끝 부분: 마지막 5개 표시
      start = totalPages - 5;
    } else {
      // 중간: 현재 페이지가 가운데에 오도록
      start = _currentIndex - 2;
    }
    
    List<Widget> indicators = [];
    for (int i = start; i < start + 5; i++) {
      final isCurrentPage = _currentIndex == i;
      indicators.add(
        GestureDetector(
          onTap: () {
            _pageController.animateToPage(
              i,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isCurrentPage ? 10 : 8,
            height: isCurrentPage ? 10 : 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrentPage
                  ? Colors.white
                  : Colors.white.withOpacity(0.4),
            ),
          ),
        ),
      );
    }
    
    return indicators;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 배경 (반투명)
        Container(
          color: Colors.transparent,
        ),
        // 카드뉴스 형태의 요약 리스트
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.summaries.length,
              itemBuilder: (context, index) {
                final summary = widget.summaries[index];
                return _buildSummaryCard(summary, index);
              },
            ),
          ),
        ),
        // 닫기 버튼
        Positioned(
          top: 40,
          right: 20,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: widget.onClose,
          ),
        ),
        // 인디케이터 (최대 5개, 드래그 가능) + 양쪽 화살표
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (details) {
              _dragStartX = details.localPosition.dx;
              _accumulatedDrag = 0;
            },
            onHorizontalDragUpdate: (details) {
              final delta = details.localPosition.dx - _dragStartX;
              _accumulatedDrag += (delta - _accumulatedDrag).abs() > _dragThreshold
                  ? 0
                  : delta - _accumulatedDrag;

              // 드래그 거리가 임계값을 넘으면 페이지 이동
              if (_accumulatedDrag < -_dragThreshold) {
                // 왼쪽으로 드래그 → 다음 페이지
                if (_currentIndex < widget.summaries.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                  );
                  _accumulatedDrag = 0;
                  _dragStartX = details.localPosition.dx;
                  HapticFeedback.selectionClick();
                }
              } else if (_accumulatedDrag > _dragThreshold) {
                // 오른쪽으로 드래그 → 이전 페이지
                if (_currentIndex > 0) {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                  );
                  _accumulatedDrag = 0;
                  _dragStartX = details.localPosition.dx;
                  HapticFeedback.selectionClick();
                }
              }
            },
            onHorizontalDragEnd: (details) {
              // 빠른 스와이프 처리
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! < -800 && _currentIndex < widget.summaries.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                } else if (details.primaryVelocity! > 800 && _currentIndex > 0) {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              }
              _accumulatedDrag = 0;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 왼쪽 화살표 (5페이지 뒤로) - 2개 이상일 때 표시, 첫 페이지 아니면 활성화
                  if (widget.summaries.length > 1)
                    GestureDetector(
                      onTap: _currentIndex > 0 ? _jumpBackward : null,
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentIndex > 0 
                              ? Colors.white.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                        ),
                        child: Icon(
                          Icons.keyboard_double_arrow_left,
                          color: _currentIndex > 0 
                              ? Colors.white 
                              : Colors.white.withOpacity(0.3),
                          size: 20,
                        ),
                      ),
                    ),
                  // 페이지 인디케이터 (점)
                  ...(_buildPageIndicators()),
                  // 오른쪽 화살표 (5페이지 앞으로) - 2개 이상일 때 표시, 마지막 페이지 아니면 활성화
                  if (widget.summaries.length > 1)
                    GestureDetector(
                      onTap: _currentIndex < widget.summaries.length - 1 ? _jumpForward : null,
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentIndex < widget.summaries.length - 1
                              ? Colors.white.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                        ),
                        child: Icon(
                          Icons.keyboard_double_arrow_right,
                          color: _currentIndex < widget.summaries.length - 1
                              ? Colors.white 
                              : Colors.white.withOpacity(0.3),
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(SummaryItem summary, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Color(AppColors.summaryPrimary).withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더 (더 세련되게)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(AppColors.summaryPrimary).withOpacity(0.12),
                  Color(AppColors.summaryPrimary).withOpacity(0.06),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                // AI 아이콘
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(AppColors.summaryPrimary),
                        Color(AppColors.summaryPrimary).withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color(AppColors.summaryPrimary).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.summaryName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                          decoration: TextDecoration.none,
                          decorationColor: Colors.transparent,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (summary.summaryFrom != null && summary.summaryTo != null)
                        Text(
                          '${_formatDateTime(summary.summaryFrom!)} ~ ${_formatDateTime(summary.summaryTo!)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(AppColors.summaryPrimary).withOpacity(0.7),
                            decoration: TextDecoration.none,
                          ),
                        ),
                    ],
                  ),
                ),
                // 페이지 인디케이터
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${index + 1}/${widget.summaries.length}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(AppColors.summaryPrimary),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 내용 (깔끔한 패딩)
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _buildSummaryCardContent(
                  summaryMessage: summary.summaryMessage,
                  summaryDetailMessage: summary.summaryDetailMessage,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 요약 카드 내용 (상세보기 기능 포함)
  Widget _buildSummaryCardContent({
    required String summaryMessage,
    String? summaryDetailMessage,
  }) {
    bool _showDetail = false; // builder 밖에서 선언하여 상태 유지
    
    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 요약 메시지 (마크다운 렌더링)
            MarkdownBody(
              data: summaryMessage,
              selectable: true,
              softLineBreak: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  fontSize: 16,
                  height: 1.8,
                  color: Color(0xFF2A2A2A),
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                  decoration: TextDecoration.none,
                ),
                pPadding: const EdgeInsets.only(bottom: 8),
                h1: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                  color: Color(0xFF2A2A2A),
                  decoration: TextDecoration.none,
                ),
                h1Padding: const EdgeInsets.only(bottom: 12, top: 8),
                h2: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                  color: Color(0xFF2A2A2A),
                  decoration: TextDecoration.none,
                ),
                h2Padding: const EdgeInsets.only(bottom: 10, top: 8),
                h3: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: Color(0xFF2A2A2A),
                  decoration: TextDecoration.none,
                ),
                h3Padding: const EdgeInsets.only(bottom: 8, top: 6),
                strong: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A2A2A),
                ),
                em: const TextStyle(
                  fontStyle: FontStyle.italic,
                ),
                blockSpacing: 12,
                listIndent: 24,
                listBullet: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2196F3),
                ),
                listBulletPadding: const EdgeInsets.only(right: 8),
                code: TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  backgroundColor: Colors.grey[200],
                  color: Colors.black87,
                ),
                codeblockDecoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                codeblockPadding: const EdgeInsets.all(12),
                blockquote: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                ),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: const Color(0xFF2196F3),
                      width: 4,
                    ),
                  ),
                ),
                blockquotePadding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
              ),
            ),
            
            // 상세보기 버튼 (상세 메시지가 있을 때만 표시)
            if (summaryDetailMessage != null && summaryDetailMessage.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _showDetail ? [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showDetail = !_showDetail;
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: _showDetail 
                            ? LinearGradient(
                                colors: [
                                  const Color(0xFF2196F3).withOpacity(0.12),
                                  const Color(0xFF2196F3).withOpacity(0.06),
                                ],
                              )
                            : null,
                        color: _showDetail ? null : Colors.grey[50],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _showDetail 
                              ? const Color(0xFF2196F3).withOpacity(0.4)
                              : Colors.grey[300]!,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _showDetail ? Icons.expand_less : Icons.expand_more,
                            color: _showDetail 
                                ? const Color(0xFF2196F3)
                                : const Color(0xFF666666),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _showDetail ? '상세보기 접기' : '상세보기',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _showDetail 
                                  ? const Color(0xFF2196F3)
                                  : const Color(0xFF666666),
                              letterSpacing: -0.3,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // 상세 메시지 (펼쳐질 때)
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _showDetail
                    ? Container(
                        margin: const EdgeInsets.only(top: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF2196F3).withOpacity(0.08),
                              const Color(0xFF2196F3).withOpacity(0.03),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF2196F3).withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2196F3).withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 상세 메시지 제목
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: const Color(0xFF2196F3),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '상세 내용',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF2196F3),
                                      letterSpacing: -0.2,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // 상세 메시지 내용 (마크다운 렌더링)
                            MarkdownBody(
                              data: summaryDetailMessage,
                              selectable: true,
                              softLineBreak: true,
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(
                                  fontSize: 15,
                                  height: 1.8,
                                  color: Color(0xFF2A2A2A),
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.2,
                                  decoration: TextDecoration.none,
                                ),
                                pPadding: const EdgeInsets.only(bottom: 8),
                                h1: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  height: 1.5,
                                  color: Color(0xFF2A2A2A),
                                  decoration: TextDecoration.none,
                                ),
                                h1Padding: const EdgeInsets.only(bottom: 10, top: 6),
                                h2: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  height: 1.5,
                                  color: Color(0xFF2A2A2A),
                                  decoration: TextDecoration.none,
                                ),
                                h2Padding: const EdgeInsets.only(bottom: 8, top: 6),
                                h3: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                  color: Color(0xFF2A2A2A),
                                  decoration: TextDecoration.none,
                                ),
                                h3Padding: const EdgeInsets.only(bottom: 6, top: 4),
                                strong: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2A2A2A),
                                ),
                                em: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                                blockSpacing: 10,
                                listIndent: 24,
                                listBullet: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF2196F3),
                                ),
                                listBulletPadding: const EdgeInsets.only(right: 8),
                                code: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  backgroundColor: Colors.grey[200],
                                  color: Colors.black87,
                                ),
                                codeblockDecoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                codeblockPadding: const EdgeInsets.all(12),
                                blockquote: TextStyle(
                                  fontSize: 15,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey[700],
                                ),
                                blockquoteDecoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: const Color(0xFF2196F3),
                                      width: 4,
                                    ),
                                  ),
                                ),
                                blockquotePadding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// 말풍선 꼬리 그리기 (카카오톡 스타일)
