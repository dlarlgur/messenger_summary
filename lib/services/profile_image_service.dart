import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 프로필 이미지 타입
enum ProfileImageType {
  room,    // 대화방 프로필 (그룹톡의 대화방 이미지, 개인톡의 상대방 이미지)
  sender,  // 보낸사람 프로필 (그룹톡의 개인 프로필)
}

/// 프로필 이미지 통합 관리 서비스
/// 
/// 저장 구조:
/// - filesDir/profile/room/{safeRoomName}.jpg      : 대화방 프로필
/// - filesDir/profile/sender/{hash}.jpg           : 보낸사람 프로필 (packageName+roomName+sender 해시)
/// 
/// 특징:
/// - filesDir 사용으로 캐시 삭제해도 이미지 유지 (데이터 삭제 시에만 삭제)
/// - 메모리 캐시로 빠른 접근
/// - 개인 프로필 없으면 대화방 프로필로 fallback
class ProfileImageService {
  static final ProfileImageService _instance = ProfileImageService._internal();
  factory ProfileImageService() => _instance;
  ProfileImageService._internal();

  static const MethodChannel _methodChannel = MethodChannel('com.dksw.app/main');

  String? _profileDir;
  bool _initialized = false;

  // 메모리 캐시
  final Map<String, File?> _roomProfileCache = {};
  final Map<String, File?> _senderProfileCache = {};

  /// 서비스 초기화 (앱 시작 시 한 번 호출)
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (Platform.isAndroid) {
        // Android: filesDir 사용 (캐시 삭제해도 유지)
        String? filesDirPath;
        try {
          final filesDir = await _methodChannel.invokeMethod<String>('getFilesDir');
          // debugPrint('📁 getFilesDir 반환값: $filesDir');
          if (filesDir != null && filesDir.isNotEmpty) {
            filesDirPath = filesDir;
          }
        } catch (e) {
          debugPrint('❌ getFilesDir 호출 실패: $e');
        }
        
        // getFilesDir가 실패했거나 null인 경우, supportDir에서 경로 추출
        if (filesDirPath == null || filesDirPath.isEmpty) {
          debugPrint('⚠️ getFilesDir 실패 - supportDir에서 경로 추출 시도');
          try {
            final supportDir = await getApplicationSupportDirectory();
            debugPrint('📁 supportDir 경로: ${supportDir.path}');
            
            // supportDir 경로에서 패키지명과 base 경로 추출
            // 예: /data/user/0/com.dksw.app/app_flutter -> /data/user/0/com.dksw.app/files
            final supportPath = supportDir.path;
            if (supportPath.contains('/app_flutter')) {
              filesDirPath = supportPath.replaceAll('/app_flutter', '/files');
              debugPrint('✅ 경로 교체 성공: $filesDirPath');
            } else if (supportPath.contains(RegExp(r'/app_[^/]+'))) {
              filesDirPath = supportPath.replaceAll(RegExp(r'/app_[^/]+'), '/files');
              debugPrint('✅ 경로 교체 성공 (패턴): $filesDirPath');
            } else {
              // 패키지명 추출 시도
              final match = RegExp(r'/data/user/0/([^/]+)').firstMatch(supportPath);
              if (match != null) {
                final packageName = match.group(1);
                filesDirPath = '/data/user/0/$packageName/files';
                debugPrint('✅ 패키지명으로 경로 구성: $filesDirPath');
              } else {
                // 최종 fallback: 하드코딩
                filesDirPath = '/data/user/0/com.dksw.app/files';
                debugPrint('⚠️ 최종 fallback 경로 사용: $filesDirPath');
              }
            }
          } catch (e) {
            debugPrint('❌ supportDir 경로 추출 실패: $e');
            // 최종 fallback: 하드코딩
            filesDirPath = '/data/user/0/com.dksw.app/files';
            debugPrint('⚠️ 최종 fallback 경로 사용: $filesDirPath');
          }
        }
        
        _profileDir = '$filesDirPath/profile';
        // debugPrint('✅ 최종 프로필 디렉토리: $_profileDir');
      } else {
        // iOS: Documents 디렉토리 사용
        final dir = await getApplicationDocumentsDirectory();
        _profileDir = '${dir.path}/profile';
      }

      // 프로필 디렉토리 생성
      final roomDir = Directory('$_profileDir/room');
      final senderDir = Directory('$_profileDir/sender');
      
      if (!roomDir.existsSync()) {
        roomDir.createSync(recursive: true);
      }
      if (!senderDir.existsSync()) {
        senderDir.createSync(recursive: true);
      }

      _initialized = true;
      // debugPrint('✅ ProfileImageService 초기화 완료: $_profileDir');
    } catch (e) {
      debugPrint('❌ ProfileImageService 초기화 실패: $e');
      // fallback: 임시 디렉토리 사용
      final dir = await getTemporaryDirectory();
      _profileDir = '${dir.path}/profile';
      _initialized = true;
    }
  }

  /// 안전한 파일명 생성 (특수문자 제거)
  String _safeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  /// SHA-256 해시 생성 (sender 프로필용)
  String _generateHash(String packageName, String roomName, String sender) {
    final uniqueKey = '$packageName|$roomName|$sender';
    final bytes = utf8.encode(uniqueKey);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// 대화방 프로필 이미지 가져오기
  /// 
  /// [roomName] 대화방 이름
  /// 반환: File 또는 null
  File? getRoomProfile(String roomName, [String? packageName]) {
    if (!_initialized || _profileDir == null || roomName.isEmpty) {
      return null;
    }

    final cacheKey = packageName != null ? '$packageName|$roomName' : roomName;

    // 캐시 확인
    if (_roomProfileCache.containsKey(cacheKey)) {
      return _roomProfileCache[cacheKey];
    }

    final safeRoomName = _safeFileName(roomName);
    // 새 경로 (메신저별) 먼저 확인, 없으면 기존 경로 fallback
    File file;
    if (packageName != null) {
      final safePkg = _safeFileName(packageName);
      file = File('$_profileDir/room/$safePkg/$safeRoomName.jpg');
      if (!file.existsSync()) {
        file = File('$_profileDir/room/$safeRoomName.jpg'); // fallback
      }
    } else {
      file = File('$_profileDir/room/$safeRoomName.jpg');
    }

    if (file.existsSync()) {
      try {
        final size = file.lengthSync();
        if (size > 0) {
          _roomProfileCache[cacheKey] = file;
          return file;
        }
      } catch (e) {
        debugPrint('대화방 프로필 읽기 실패: $e');
      }
    }

    _roomProfileCache[cacheKey] = null;
    return null;
  }

  /// 보낸사람 프로필 이미지 가져오기
  /// 
  /// [packageName] 메신저 패키지명
  /// [roomName] 대화방 이름
  /// [sender] 보낸사람 이름
  /// [fallbackToRoom] true면 sender 프로필 없을 때 대화방 프로필 반환
  /// 반환: File 또는 null
  File? getSenderProfile({
    required String packageName,
    required String roomName,
    required String sender,
    bool fallbackToRoom = true,
  }) {
    if (!_initialized || _profileDir == null) {
      return null;
    }

    if (sender.isEmpty || roomName.isEmpty) {
      return fallbackToRoom ? getRoomProfile(roomName) : null;
    }

    // 캐시 키 생성
    final cacheKey = '$packageName|$roomName|$sender';

    // 캐시 확인
    if (_senderProfileCache.containsKey(cacheKey)) {
      final cached = _senderProfileCache[cacheKey];
      if (cached != null) return cached;
      // 캐시에 null이 저장되어 있으면 fallback 시도
      return fallbackToRoom ? getRoomProfile(roomName) : null;
    }

    // 파일 확인
    final fileKey = _generateHash(packageName, roomName, sender);
    final file = File('$_profileDir/sender/$fileKey.jpg');

    if (file.existsSync()) {
      try {
        final size = file.lengthSync();
        if (size > 0) {
          _senderProfileCache[cacheKey] = file;
          return file;
        }
      } catch (e) {
        debugPrint('보낸사람 프로필 읽기 실패: $e');
      }
    }

    // 파일 없음 - 캐시에 null 저장
    _senderProfileCache[cacheKey] = null;

    // fallback: 대화방 프로필 사용
    if (fallbackToRoom) {
      return getRoomProfile(roomName);
    }

    return null;
  }

  /// 대화방 프로필 캐시 무효화
  void invalidateRoomProfile(String roomName) {
    _roomProfileCache.remove(roomName);
  }

  /// 보낸사람 프로필 캐시 무효화
  void invalidateSenderProfile(String packageName, String roomName, String sender) {
    final cacheKey = '$packageName|$roomName|$sender';
    _senderProfileCache.remove(cacheKey);
  }

  /// 특정 대화방의 모든 sender 캐시 무효화
  void invalidateRoomSenders(String roomName) {
    _senderProfileCache.removeWhere((key, _) => key.contains('|$roomName|'));
  }

  /// 모든 캐시 클리어 (메모리만, 파일은 유지)
  void clearCache() {
    _roomProfileCache.clear();
    _senderProfileCache.clear();
    // debugPrint('프로필 이미지 메모리 캐시 클리어');
  }

  /// 프로필 디렉토리 경로 반환
  String? get profileDir => _profileDir;

  /// 초기화 여부
  bool get isInitialized => _initialized;

  /// 디버그: 저장된 프로필 파일 목록 출력
  void debugPrintProfileFiles() {
    if (_profileDir == null) {
      debugPrint('프로필 디렉토리가 초기화되지 않음');
      return;
    }

    debugPrint('=== 프로필 이미지 파일 목록 ===');
    
    final roomDir = Directory('$_profileDir/room');
    if (roomDir.existsSync()) {
      final roomFiles = roomDir.listSync();
      debugPrint('대화방 프로필 (${roomFiles.length}개):');
      for (final file in roomFiles.take(10)) {
        debugPrint('  - ${file.path.split('/').last}');
      }
    }

    final senderDir = Directory('$_profileDir/sender');
    if (senderDir.existsSync()) {
      final senderFiles = senderDir.listSync();
      debugPrint('보낸사람 프로필 (${senderFiles.length}개):');
      for (final file in senderFiles.take(10)) {
        debugPrint('  - ${file.path.split('/').last}');
      }
    }
  }
}
