import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/chat_message.dart';
import '../services/local_db_service.dart';
import '../config/constants.dart';
import 'package:intl/intl.dart';

/// 요약 히스토리 화면
class SummaryHistoryScreen extends StatefulWidget {
  final int roomId;
  final String roomName;
  final int? initialSummaryId; // 특정 요약을 자동으로 열기 위한 ID

  const SummaryHistoryScreen({
    Key? key,
    required this.roomId,
    required this.roomName,
    this.initialSummaryId,
  }) : super(key: key);

  @override
  State<SummaryHistoryScreen> createState() => _SummaryHistoryScreenState();
}

class _SummaryHistoryScreenState extends State<SummaryHistoryScreen> {
  final LocalDbService _localDb = LocalDbService();
  List<SummaryItem> _allSummaries = []; // 모든 요약
  List<SummaryItem> _summaries = []; // 현재 날짜의 요약
  List<DateTime> _availableDates = []; // 요약이 있는 날짜 목록
  DateTime _selectedDate = DateTime.now(); // 선택된 날짜
  int _currentDateIndex = 0; // 현재 날짜 인덱스
  late PageController _pageController;
  bool _isLoading = true;
  Set<int> _selectedSummaryIds = {};
  bool _isSelectionMode = false;

  /// 마크다운 전처리 (서버에서 받은 마크다운을 올바르게 파싱하도록 정리)
  String _preprocessMarkdown(String text) {
    if (text.isEmpty) return text;
    
    String processed = text;
    
    // 1. 숫자 리스트 항목에서 **가 줄바꿈으로 분리된 경우 먼저 처리
    // 예: "1. **제목\n**" -> "1. **제목**"
    processed = processed.replaceAllMapped(
      RegExp(r'(\d+)\.\s+\*\*([^\n\*]+)\n\*\*'),
      (match) => '${match.group(1)}. **${match.group(2)}**',
    );
    
    // 2. **bold** 형식이 줄바꿈으로 분리된 경우 수정 (재귀적으로 처리)
    // 예: "**text\n**" -> "**text**"
    int maxIterations = 10;
    for (int i = 0; i < maxIterations; i++) {
      final before = processed;
      // 단일 줄바꿈으로 분리된 경우
      processed = processed.replaceAllMapped(
        RegExp(r'\*\*([^\n\*]+)\n\*\*'),
        (match) => '**${match.group(1)}**',
      );
      // 여러 줄에 걸친 경우
      processed = processed.replaceAllMapped(
        RegExp(r'\*\*([^\n\*]+)\n([^\n\*]+)\n\*\*'),
        (match) => '**${match.group(1)} ${match.group(2)}**',
      );
      if (before == processed) break; // 더 이상 변경이 없으면 종료
    }
    
    // 3. 숫자 리스트 다음에 오는 불렛 리스트만 들여쓰기
    final lines = processed.split('\n');
    final result = <String>[];
    bool inBulletList = false;
    int lastNumberLineIndex = -1;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trimLeft();
      final isNumberList = RegExp(r'^\d+\.\s+').hasMatch(trimmedLine);
      final isBulletList = RegExp(r'^\*\s+').hasMatch(trimmedLine);

      if (isNumberList) {
        // 숫자 리스트 - 무조건 모드 종료
        inBulletList = false;
        lastNumberLineIndex = i;
        result.add(line);
      } else if (isBulletList) {
        // 불렛 리스트 - 바로 이전 줄이 숫자였거나 모드 중이면 들여쓰기
        if (lastNumberLineIndex == i - 1 || inBulletList) {
          inBulletList = true;
          result.add('   $line');
        } else {
          result.add(line);
        }
      } else {
        // 그 외 - 모드 종료
        inBulletList = false;
        result.add(line);
      }
    }
    
    processed = result.join('\n');
    
    // 4. 숫자 리스트 형식 정리 (1. **제목\n** * 내용 패턴)
    processed = processed.replaceAllMapped(
      RegExp(r'(\d+)\.\s+\*\*([^\n\*]+)\n\*\*\s*\*'),
      (match) => '${match.group(1)}. **${match.group(2)}**\n   *',
    );
    
    // 5. 줄바꿈 정리 (연속된 줄바꿈을 2개로 제한)
    processed = processed.replaceAll(RegExp(r'\n{4,}'), '\n\n\n');
    
    // 6. 리스트 항목 사이의 불필요한 빈 줄 제거
    processed = processed.replaceAllMapped(
      RegExp(r'\n\n(\d+\.|\*)'),
      (match) => '\n${match.group(1)}',
    );
    
    // 7. 문단 끝의 불필요한 줄바꿈 제거
    processed = processed.trim();
    
    return processed;
  }

  /// 상세 내용용 마크다운 전처리 (숫자 리스트를 일반 텍스트로 처리하여 들여쓰기 방지)
  String _preprocessDetailMarkdown(String text) {
    if (text.isEmpty) return text;
    
    String processed = text;
    
    // 1. 숫자 리스트 항목에서 **가 줄바꿈으로 분리된 경우 먼저 처리
    // 예: "1. **제목\n**" -> "1. **제목**"
    processed = processed.replaceAllMapped(
      RegExp(r'(\d+)\.\s+\*\*([^\n\*]+)\n\*\*'),
      (match) => '${match.group(1)}. **${match.group(2)}**',
    );
    
    // 2. **bold** 형식이 줄바꿈으로 분리된 경우 수정 (재귀적으로 처리)
    // 예: "**text\n**" -> "**text**"
    int maxIterations = 10;
    for (int i = 0; i < maxIterations; i++) {
      final before = processed;
      // 단일 줄바꿈으로 분리된 경우
      processed = processed.replaceAllMapped(
        RegExp(r'\*\*([^\n\*]+)\n\*\*'),
        (match) => '**${match.group(1)}**',
      );
      // 여러 줄에 걸친 경우
      processed = processed.replaceAllMapped(
        RegExp(r'\*\*([^\n\*]+)\n([^\n\*]+)\n\*\*'),
        (match) => '**${match.group(1)} ${match.group(2)}**',
      );
      if (before == processed) break; // 더 이상 변경이 없으면 종료
    }
    
    // 3. 숫자 리스트를 일반 텍스트로 변환 (마크다운 리스트로 인식하지 않도록)
    // 숫자 앞에 공백 4개를 추가하여 마크다운 리스트로 인식하지 않게 함
    // 예: "1. 제목" -> "    1. 제목" (앞에 공백 4개 추가)
    processed = processed.replaceAllMapped(
      RegExp(r'^(\d+)\.\s+', multiLine: true),
      (match) => '    ${match.group(1)}. ',  // 앞에 공백 4개 추가하여 리스트로 인식 방지
    );
    
    // 4. 숫자 리스트 다음에 오는 불렛 리스트만 들여쓰기
    final lines = processed.split('\n');
    final result = <String>[];
    bool inBulletList = false;
    int lastNumberLineIndex = -1;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trimLeft();
      // 숫자 텍스트 체크 (앞 공백 4개 포함하여 체크: "    1. " 패턴)
      final isNumberText = RegExp(r'^\s{4,}\d+\.\s+').hasMatch(line);
      // 불렛 리스트 체크 (정확히 *로 시작하는 경우만)
      final isBulletList = RegExp(r'^\*\s+').hasMatch(trimmedLine);

      if (isNumberText) {
        // 숫자 텍스트 - 앞 공백 모두 제거하여 들여쓰기 없이 표시
        inBulletList = false;
        lastNumberLineIndex = i;
        // 앞 공백 모두 제거 (원래 숫자 리스트는 들여쓰기 없이)
        result.add(trimmedLine);
      } else if (isBulletList) {
        // 불렛 리스트 - 들여쓰기 없이 표시
        inBulletList = true;
        result.add(trimmedLine);
      } else {
        // 그 외 (빈 줄 포함) - 모드 종료
        inBulletList = false;
        result.add(line);
      }
    }
    
    processed = result.join('\n');
    
    // 5. 줄바꿈 정리 (연속된 줄바꿈을 2개로 제한)
    processed = processed.replaceAll(RegExp(r'\n{4,}'), '\n\n\n');
    
    // 6. 리스트 항목 사이의 불필요한 빈 줄 제거
    processed = processed.replaceAllMapped(
      RegExp(r'\n\n(\s{4,}\d+\.|\*)'),
      (match) => '\n${match.group(1)}',
    );
    
    // 7. 문단 끝의 불필요한 줄바꿈 제거
    processed = processed.trim();
    
    return processed;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadSummaries();
  }

  /// 요약 히스토리 로드
  Future<void> _loadSummaries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 빈 요약 먼저 정리
      await _localDb.deleteEmptySummaries();

      // 요약 히스토리 로드
      final detailResponse = await _localDb.getRoomSummaries(widget.roomId);

      // 최신순 정렬 (summaryTo 기준, 없으면 summaryFrom)
      final sortedSummaries = List<SummaryItem>.from(detailResponse.summaries);
      sortedSummaries.sort((a, b) {
        final aTime = a.summaryTo ?? a.summaryFrom ?? DateTime(1970);
        final bTime = b.summaryTo ?? b.summaryFrom ?? DateTime(1970);
        return bTime.compareTo(aTime); // 최신이 먼저
      });

      // 날짜 목록 추출 (중복 제거, 최신순)
      final dateSet = <DateTime>{};
      for (final summary in sortedSummaries) {
        final date = summary.summaryTo ?? summary.summaryFrom;
        if (date != null) {
          final dateOnly = DateTime(date.year, date.month, date.day);
          dateSet.add(dateOnly);
        }
      }
      final availableDates = dateSet.toList()
        ..sort((a, b) => b.compareTo(a)); // 최신순

      // 초기 선택 날짜 설정
      DateTime initialDate = DateTime.now();
      int initialIndex = 0;
      
      if (widget.initialSummaryId != null) {
        // initialSummaryId가 있으면 해당 요약의 날짜로 설정
        final matchingSummary = sortedSummaries.firstWhere(
          (s) => s.summaryId == widget.initialSummaryId,
          orElse: () => sortedSummaries.isNotEmpty ? sortedSummaries.first : sortedSummaries.first,
        );
        if (matchingSummary.summaryTo != null || matchingSummary.summaryFrom != null) {
          final date = matchingSummary.summaryTo ?? matchingSummary.summaryFrom!;
          initialDate = DateTime(date.year, date.month, date.day);
          initialIndex = availableDates.indexWhere(
            (d) => d.year == initialDate.year && d.month == initialDate.month && d.day == initialDate.day,
          );
          if (initialIndex == -1) {
            initialIndex = 0;
            initialDate = availableDates.isNotEmpty ? availableDates.first : DateTime.now();
          }
        }
      } else if (availableDates.isNotEmpty) {
        // 오늘 날짜가 있으면 오늘, 없으면 가장 최신 날짜
        final today = DateTime.now();
        final todayOnly = DateTime(today.year, today.month, today.day);
        if (availableDates.contains(todayOnly)) {
          initialDate = todayOnly;
          initialIndex = availableDates.indexOf(todayOnly);
        } else {
          initialDate = availableDates.first;
          initialIndex = 0;
        }
      }

      if (mounted) {
        setState(() {
          _allSummaries = sortedSummaries;
          _availableDates = availableDates;
          _selectedDate = initialDate;
          _currentDateIndex = initialIndex;
          _updateSummariesForDate(initialDate);
          _isLoading = false;
        });

        // PageController 초기 위치 설정 (PageView가 빌드된 후)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _availableDates.isNotEmpty && _pageController.hasClients) {
            _pageController.jumpToPage(_currentDateIndex);
          }
        });
        
        // initialSummaryId가 있으면 해당 요약 자동으로 열기
        if (widget.initialSummaryId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _openInitialSummary();
          });
        }
      }
    } catch (e) {
      debugPrint('요약 히스토리 로딩 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('요약 히스토리를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 선택된 날짜의 요약만 필터링
  void _updateSummariesForDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    _summaries = _allSummaries.where((summary) {
      final summaryDate = summary.summaryTo ?? summary.summaryFrom;
      if (summaryDate == null) return false;
      final summaryDateOnly = DateTime(summaryDate.year, summaryDate.month, summaryDate.day);
      return summaryDateOnly == dateOnly;
    }).toList();
  }

  /// 날짜 변경
  void _onDateChanged(DateTime date, int index) {
    setState(() {
      _selectedDate = date;
      _currentDateIndex = index;
      _updateSummariesForDate(date);
    });
  }

  /// 이전 날짜로 이동 (과거로)
  void _goToPreviousDate() {
    if (_currentDateIndex < _availableDates.length - 1) {
      final newIndex = _currentDateIndex + 1;
      _pageController.animateToPage(
        newIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 다음 날짜로 이동 (최신으로)
  void _goToNextDate() {
    if (_currentDateIndex > 0) {
      final newIndex = _currentDateIndex - 1;
      _pageController.animateToPage(
        newIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 달력으로 날짜 선택
  Future<void> _showCalendarPicker() async {
    final selectedDate = await showDialog<DateTime>(
      context: context,
      builder: (context) => _CalendarPickerDialog(
        availableDates: _availableDates,
        initialDate: _selectedDate,
      ),
    );

    if (selectedDate != null && mounted) {
      final index = _availableDates.indexWhere(
        (d) => d.year == selectedDate.year && d.month == selectedDate.month && d.day == selectedDate.day,
      );
      if (index != -1) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  /// initialSummaryId에 해당하는 요약 자동으로 열기
  void _openInitialSummary() {
    if (widget.initialSummaryId == null) return;
    
    final matchingSummary = _allSummaries.firstWhere(
      (s) => s.summaryId == widget.initialSummaryId,
      orElse: () => _allSummaries.first,
    );
    
    if (matchingSummary.summaryId == widget.initialSummaryId) {
      _showSummaryDetail(matchingSummary);
    } else {
      debugPrint('⚠️ 요약을 찾을 수 없음: summaryId=${widget.initialSummaryId}');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 선택 모드 토글
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedSummaryIds.clear();
      }
    });
  }

  /// 요약 항목 선택/해제
  void _toggleSummarySelection(int summaryId) {
    setState(() {
      if (_selectedSummaryIds.contains(summaryId)) {
        _selectedSummaryIds.remove(summaryId);
      } else {
        _selectedSummaryIds.add(summaryId);
      }
    });
  }

  /// 전체 선택/해제
  void _toggleSelectAll() {
    setState(() {
      if (_selectedSummaryIds.length == _summaries.length) {
        // 모두 선택되어 있으면 전체 해제
        _selectedSummaryIds.clear();
      } else {
        // 일부만 선택되어 있거나 아무것도 선택 안 되어 있으면 전체 선택
        _selectedSummaryIds = _summaries.map((s) => s.summaryId).toSet();
      }
    });
    HapticFeedback.selectionClick();
  }

  /// 선택된 요약 삭제
  Future<void> _deleteSelectedSummaries() async {
    if (_selectedSummaryIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          '요약 삭제',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '선택한 ${_selectedSummaryIds.length}개의 요약을 삭제하시겠습니까?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              '취소',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      int successCount = 0;
      for (final summaryId in _selectedSummaryIds) {
        final success = await _localDb.deleteSummary(summaryId);
        if (success) successCount++;
      }

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount개의 요약이 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );

        // 선택 모드 종료 및 목록 새로고침
        setState(() {
          _isSelectionMode = false;
          _selectedSummaryIds.clear();
        });
        _loadSummaries();
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제에 실패했습니다. 잠시 후 다시 시도해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 개별 요약 삭제
  Future<void> _deleteSummary(int summaryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          '요약 삭제',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          '이 요약을 삭제하시겠습니까?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              '취소',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success = await _localDb.deleteSummary(summaryId);

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('요약이 삭제되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadSummaries();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('삭제에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제에 실패했습니다. 잠시 후 다시 시도해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 날짜 포맷팅
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return '오늘 (${DateFormat('M월 d일', 'ko_KR').format(date)})';
    } else if (dateOnly == today.subtract(const Duration(days: 1))) {
      return '어제 (${DateFormat('M월 d일', 'ko_KR').format(date)})';
    } else {
      return DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(date);
    }
  }

  /// 시간 포맷팅
  String _formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  /// 날짜/시간 포맷팅
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(AppColors.summaryPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _isSelectionMode
            ? Text(
                '${_selectedSummaryIds.length}개 선택됨',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              )
            : const Text(
                'AI 요약 히스토리',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
        actions: [
          if (_isSelectionMode) ...[
            // 전체 선택/해제 텍스트 버튼
            TextButton(
              onPressed: _toggleSelectAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _selectedSummaryIds.length == _summaries.length
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _selectedSummaryIds.length == _summaries.length
                        ? '전체 해제'
                        : '전체 선택',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // 선택 삭제 버튼
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: _selectedSummaryIds.isEmpty
                    ? Colors.white.withOpacity(0.5)
                    : Colors.white,
              ),
              onPressed: _selectedSummaryIds.isEmpty ? null : _deleteSelectedSummaries,
              tooltip: '선택 삭제',
            ),
          ],
          // 선택 모드 토글 버튼
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _toggleSelectionMode,
              tooltip: '선택 모드 종료',
            )
          else
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: _toggleSelectionMode,
              tooltip: '편집',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(AppColors.summaryPrimary)),
              ),
            )
          : _availableDates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '요약 히스토리가 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // 날짜 선택 헤더
                    _buildDateHeader(),
                    // 요약 목록
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        reverse: false, // 최신이 왼쪽에 오도록 (인덱스 0이 최신)
                        physics: const BouncingScrollPhysics(), // iOS 스타일 스크롤
                        onPageChanged: (index) {
                          if (index < _availableDates.length && index >= 0) {
                            _onDateChanged(_availableDates[index], index);
                          }
                        },
                        itemCount: _availableDates.length,
                        itemBuilder: (context, index) {
                          final date = _availableDates[index];
                          final summariesForDate = _allSummaries.where((summary) {
                            final summaryDate = summary.summaryTo ?? summary.summaryFrom;
                            if (summaryDate == null) return false;
                            final summaryDateOnly = DateTime(
                              summaryDate.year,
                              summaryDate.month,
                              summaryDate.day,
                            );
                            final dateOnly = DateTime(date.year, date.month, date.day);
                            return summaryDateOnly == dateOnly;
                          }).toList();

                          if (summariesForDate.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '이 날짜의 요약이 없습니다',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: summariesForDate.length,
                            itemBuilder: (context, itemIndex) {
                              final summary = summariesForDate[itemIndex];
                              final isSelected = _selectedSummaryIds.contains(summary.summaryId);
                              final isLast = itemIndex == summariesForDate.length - 1;

                              return Column(
                                children: [
                                  _buildSummaryCard(summary, isSelected),
                                  if (isLast) const SizedBox(height: 16),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  /// 날짜 선택 헤더
  Widget _buildDateHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 이전 날짜 버튼
          IconButton(
            icon: Icon(
              Icons.chevron_left,
              color: _currentDateIndex < _availableDates.length - 1
                  ? const Color(AppColors.summaryPrimary)
                  : Colors.grey[300],
            ),
            onPressed: _currentDateIndex < _availableDates.length - 1
                ? _goToPreviousDate
                : null,
          ),
          // 날짜 표시 및 달력 버튼
          Expanded(
            child: GestureDetector(
              onTap: _showCalendarPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(AppColors.summaryPrimary).withValues(alpha: 0.1),
                      const Color(AppColors.summaryPrimary).withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(AppColors.summaryPrimary).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: const Color(AppColors.summaryPrimary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(_selectedDate),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(AppColors.summaryPrimary),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${_summaries.length}개)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 다음 날짜 버튼
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: _currentDateIndex > 0
                  ? const Color(AppColors.summaryPrimary)
                  : Colors.grey[300],
            ),
            onPressed: _currentDateIndex > 0 ? _goToNextDate : null,
          ),
        ],
      ),
    );
  }

  /// 날짜 구분선
  Widget _buildDateDivider(DateTime date) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF8BA4B8).withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDate(date),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// 요약 상세보기 다이얼로그
  void _showSummaryDetail(SummaryItem summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.75,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.9, 0.95],
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
          child: Column(
            children: [
              // 핸들바
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 헤더
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(AppColors.summaryPrimary).withOpacity(0.12),
                      const Color(AppColors.summaryPrimary).withOpacity(0.06),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(AppColors.summaryPrimary),
                            Color(0xFF3A7ECC),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
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
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (summary.summaryFrom != null && summary.summaryTo != null)
                            Text(
                              '${_formatDateTime(summary.summaryFrom!)} ~ ${_formatDateTime(summary.summaryTo!)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(AppColors.summaryPrimary).withOpacity(0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // 내용
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 요약 메시지
                    MarkdownBody(
                      data: _preprocessMarkdown(summary.summaryMessage),
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
                        listIndent: 32,
                        listBullet: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2196F3),
                          fontWeight: FontWeight.w600,
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
                    // 상세 메시지 (있을 경우)
                    if (summary.summaryDetailMessage != null &&
                        summary.summaryDetailMessage!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
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
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: Color(0xFF2196F3),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '상세 내용',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2196F3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            MarkdownBody(
                              data: _preprocessDetailMarkdown(summary.summaryDetailMessage!),
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
                                pPadding: const EdgeInsets.only(left: 0, right: 0, bottom: 8),
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
                                listIndent: 16,
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
                                blockquotePadding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 요약 카드
  Widget _buildSummaryCard(SummaryItem summary, bool isSelected) {
    return GestureDetector(
      onTap: _isSelectionMode
          ? () {
              _toggleSummarySelection(summary.summaryId);
              HapticFeedback.selectionClick();
            }
          : () {
              _showSummaryDetail(summary);
            },
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelectionMode();
          _toggleSummarySelection(summary.summaryId);
          HapticFeedback.mediumImpact();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(
                  color: const Color(AppColors.summaryPrimary),
                  width: 3,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(AppColors.summaryPrimary).withOpacity(0.12),
                    const Color(AppColors.summaryPrimary).withOpacity(0.06),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  // 선택 체크박스 (선택 모드일 때만)
                  if (_isSelectionMode)
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(AppColors.summaryPrimary)
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? const Color(AppColors.summaryPrimary)
                              : Colors.grey[400]!,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  // AI 아이콘
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(AppColors.summaryPrimary),
                          Color(0xFF3A7ECC),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(AppColors.summaryPrimary).withOpacity(0.3),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (summary.summaryFrom != null && summary.summaryTo != null)
                          Text(
                            '${_formatDateTime(summary.summaryFrom!)} ~ ${_formatDateTime(summary.summaryTo!)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(AppColors.summaryPrimary).withOpacity(0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 삭제 버튼 (선택 모드가 아닐 때만)
                  if (!_isSelectionMode)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () => _deleteSummary(summary.summaryId),
                      tooltip: '삭제',
                    ),
                ],
              ),
            ),
            // 내용
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 요약 메시지 미리보기 (최대 3줄)
                  MarkdownBody(
                    data: summary.summaryMessage,
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
                  // 상세보기 버튼 (상세 메시지가 있을 때만)
                  if (summary.summaryDetailMessage != null &&
                      summary.summaryDetailMessage!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _showSummaryDetail(summary),
                        icon: const Icon(
                          Icons.expand_more,
                          color: Color(0xFF2196F3),
                        ),
                        label: const Text(
                          '상세보기',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2196F3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 달력 선택 다이얼로그
class _CalendarPickerDialog extends StatefulWidget {
  final List<DateTime> availableDates;
  final DateTime initialDate;

  const _CalendarPickerDialog({
    required this.availableDates,
    required this.initialDate,
  });

  @override
  State<_CalendarPickerDialog> createState() => _CalendarPickerDialogState();
}

class _CalendarPickerDialogState extends State<_CalendarPickerDialog> {
  late DateTime _selectedDate;
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _focusedDay = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Row(
              children: [
                const Text(
                  '날짜 선택',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 달력
            TableCalendar(
              firstDay: widget.availableDates.isNotEmpty
                  ? widget.availableDates.last
                  : DateTime.utc(2020, 1, 1),
              lastDay: widget.availableDates.isNotEmpty
                  ? widget.availableDates.first
                  : DateTime.now(),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDate, day);
              },
              availableCalendarFormats: const {
                CalendarFormat.month: '월',
              },
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              locale: 'ko_KR',
              enabledDayPredicate: (day) {
                final dayOnly = DateTime(day.year, day.month, day.day);
                return widget.availableDates.any((date) =>
                    date.year == dayOnly.year &&
                    date.month == dayOnly.month &&
                    date.day == dayOnly.day);
              },
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                selectedDecoration: BoxDecoration(
                  color: const Color(AppColors.summaryPrimary),
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: const Color(AppColors.summaryPrimary).withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                disabledDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[100],
                ),
                defaultTextStyle: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w500,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                todayTextStyle: TextStyle(
                  color: const Color(AppColors.summaryPrimary),
                  fontWeight: FontWeight.bold,
                ),
                disabledTextStyle: TextStyle(
                  color: Colors.grey[400],
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                leftChevronIcon: const Icon(Icons.chevron_left),
                rightChevronIcon: const Icon(Icons.chevron_right),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                final dayOnly = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                final isAvailable = widget.availableDates.any((date) =>
                    date.year == dayOnly.year &&
                    date.month == dayOnly.month &&
                    date.day == dayOnly.day);
                
                if (isAvailable) {
                  setState(() {
                    _selectedDate = dayOnly;
                    _focusedDay = focusedDay;
                  });
                }
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
            ),
            const SizedBox(height: 20),
            // 확인 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(_selectedDate);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.summaryPrimary),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '선택',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
