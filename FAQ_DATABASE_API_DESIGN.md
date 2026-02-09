# FAQ 데이터베이스 및 API 설계

## 1. 데이터베이스 스키마

### FAQ 테이블 생성 (MySQL/PostgreSQL)

```sql
CREATE TABLE faq (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(255) NOT NULL COMMENT 'FAQ 제목',
    content TEXT NOT NULL COMMENT 'FAQ 내용',
    display_order INT DEFAULT 0 COMMENT '표시 순서',
    is_active TINYINT(1) DEFAULT 1 COMMENT '활성화 여부 (1: 활성, 0: 비활성)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_display_order (display_order),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='FAQ 테이블';
```

### 초기 데이터 삽입

```sql
INSERT INTO faq (title, content, display_order, is_active) VALUES
('AI 톡비서 FAQ', 
'Q1. "메시지가 정상적으로 저장 되지 않아요!"
답변: AI 톡비서 필수 설정을 반드시 해주세요. 앱 설정 > AI 톡비서 사용 방법으로 이동하여 참고해주세요.

Q2. AI 톡비서 설치 이전의 메시지는 볼 수 없나요?
답변: AI 톡비서는 설치 이후 화면 상단 알림창에 뜨는 메시지를 실시간으로 저장하는 앱입니다. 죄송하지만 AI 톡비서 설치 이전의 메시지는 확인 할 수 없습니다.

Q3. 자동요약은 어떻게 하나요?
답변: AI 톡비서에서 자동요약기능은 BASIC 요금제부터 사용 할 수 있습니다. 채팅방 목록에서 자동요약 할 채팅방을 길게 눌러 자동요약기능 하기를 누르면 화면이 이동합니다. 해당 화면에서 자동요약하기 기능을 켜고 메시지 수를 설정하면 안읽은 메시지가 설정한 수에 도달하면 자동 요약이되고 푸시 알림이갑니다. 푸시알림을 받기 위해서 설정에서 AI 톡비서 푸시알람 설정을 켜주세요.

Q4. "사진을 보냈습니다", "이모티콘을 보냈습니다" 만 뜨고 보이지 않아요.
답변: 시스템의 문제로 사진 및 이모티콘을 저장을 실패 할 수있습니다. 그리고 2개이상의 묶음 사진은 현재 저장하지 못합니다.',
1, 1);
```

## 2. API 엔드포인트 설계

### 2.1 FAQ 조회 API (공개)

**GET** `/api/v1/faq`

**설명**: 활성화된 FAQ 목록 조회 (인증 불필요)

**응답 예시**:
```json
{
  "success": true,
  "data": {
    "faq": {
      "id": 1,
      "title": "AI 톡비서 FAQ",
      "content": "Q1. \"메시지가 정상적으로 저장 되지 않아요!\"\n답변: AI 톡비서 필수 설정을 반드시 해주세요...",
      "displayOrder": 1,
      "isActive": true,
      "createdAt": "2024-01-01T00:00:00Z",
      "updatedAt": "2024-01-15T10:30:00Z"
    }
  }
}
```

**에러 응답**:
```json
{
  "success": false,
  "error": "FAQ를 찾을 수 없습니다."
}
```

### 2.2 FAQ 관리 API (관리자용)

#### 2.2.1 FAQ 조회 (관리자)

**GET** `/api/v1/admin/faq`

**설명**: 모든 FAQ 조회 (비활성화 포함)

**헤더**:
```
Authorization: Bearer {admin_token}
```

**응답 예시**:
```json
{
  "success": true,
  "data": {
    "faqs": [
      {
        "id": 1,
        "title": "AI 톡비서 FAQ",
        "content": "...",
        "displayOrder": 1,
        "isActive": true,
        "createdAt": "2024-01-01T00:00:00Z",
        "updatedAt": "2024-01-15T10:30:00Z"
      }
    ]
  }
}
```

#### 2.2.2 FAQ 생성 (관리자)

**POST** `/api/v1/admin/faq`

**설명**: 새 FAQ 생성

**헤더**:
```
Authorization: Bearer {admin_token}
Content-Type: application/json
```

**요청 본문**:
```json
{
  "title": "AI 톡비서 FAQ",
  "content": "Q1. ...\n답변: ...",
  "displayOrder": 1,
  "isActive": true
}
```

**응답 예시**:
```json
{
  "success": true,
  "message": "FAQ가 생성되었습니다.",
  "data": {
    "id": 1,
    "title": "AI 톡비서 FAQ",
    "content": "...",
    "displayOrder": 1,
    "isActive": true,
    "createdAt": "2024-01-15T10:30:00Z",
    "updatedAt": "2024-01-15T10:30:00Z"
  }
}
```

#### 2.2.3 FAQ 수정 (관리자)

**PUT** `/api/v1/admin/faq/{id}`

**설명**: FAQ 수정

**헤더**:
```
Authorization: Bearer {admin_token}
Content-Type: application/json
```

**요청 본문**:
```json
{
  "title": "AI 톡비서 FAQ (수정)",
  "content": "수정된 내용...",
  "displayOrder": 1,
  "isActive": true
}
```

**응답 예시**:
```json
{
  "success": true,
  "message": "FAQ가 수정되었습니다.",
  "data": {
    "id": 1,
    "title": "AI 톡비서 FAQ (수정)",
    "content": "수정된 내용...",
    "displayOrder": 1,
    "isActive": true,
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-15T11:00:00Z"
  }
}
```

#### 2.2.4 FAQ 삭제 (관리자)

**DELETE** `/api/v1/admin/faq/{id}`

**설명**: FAQ 삭제 (실제 삭제 또는 isActive = false로 변경)

**헤더**:
```
Authorization: Bearer {admin_token}
```

**응답 예시**:
```json
{
  "success": true,
  "message": "FAQ가 삭제되었습니다."
}
```

## 3. 서버 구현 예시 (Java/Spring Boot)

### 3.1 Entity 클래스

```java
@Entity
@Table(name = "faq")
public class FAQ {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false)
    private String title;
    
    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;
    
    @Column(name = "display_order")
    private Integer displayOrder = 0;
    
    @Column(name = "is_active")
    private Boolean isActive = true;
    
    @Column(name = "created_at", updatable = false)
    @CreationTimestamp
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    @UpdateTimestamp
    private LocalDateTime updatedAt;
    
    // Getters and Setters
}
```

### 3.2 Repository

```java
@Repository
public interface FAQRepository extends JpaRepository<FAQ, Long> {
    Optional<FAQ> findByIsActiveTrueOrderByDisplayOrderAsc();
    List<FAQ> findAllByOrderByDisplayOrderAsc();
}
```

### 3.3 Service

```java
@Service
public class FAQService {
    private final FAQRepository faqRepository;
    
    public FAQService(FAQRepository faqRepository) {
        this.faqRepository = faqRepository;
    }
    
    // 공개 API: 활성화된 FAQ 조회
    public FAQ getActiveFAQ() {
        return faqRepository.findByIsActiveTrueOrderByDisplayOrderAsc()
            .orElseThrow(() -> new NotFoundException("FAQ를 찾을 수 없습니다."));
    }
    
    // 관리자 API: 모든 FAQ 조회
    public List<FAQ> getAllFAQs() {
        return faqRepository.findAllByOrderByDisplayOrderAsc();
    }
    
    // 관리자 API: FAQ 생성
    public FAQ createFAQ(FAQ faq) {
        return faqRepository.save(faq);
    }
    
    // 관리자 API: FAQ 수정
    public FAQ updateFAQ(Long id, FAQ faq) {
        FAQ existing = faqRepository.findById(id)
            .orElseThrow(() -> new NotFoundException("FAQ를 찾을 수 없습니다."));
        
        existing.setTitle(faq.getTitle());
        existing.setContent(faq.getContent());
        existing.setDisplayOrder(faq.getDisplayOrder());
        existing.setIsActive(faq.getIsActive());
        
        return faqRepository.save(existing);
    }
    
    // 관리자 API: FAQ 삭제
    public void deleteFAQ(Long id) {
        FAQ faq = faqRepository.findById(id)
            .orElseThrow(() -> new NotFoundException("FAQ를 찾을 수 없습니다."));
        
        // 실제 삭제 또는 비활성화
        faq.setIsActive(false);
        faqRepository.save(faq);
    }
}
```

### 3.4 Controller

```java
@RestController
@RequestMapping("/api/v1")
public class FAQController {
    private final FAQService faqService;
    
    public FAQController(FAQService faqService) {
        this.faqService = faqService;
    }
    
    // 공개 API: FAQ 조회
    @GetMapping("/faq")
    public ResponseEntity<Map<String, Object>> getFAQ() {
        try {
            FAQ faq = faqService.getActiveFAQ();
            return ResponseEntity.ok(Map.of(
                "success", true,
                "data", Map.of("faq", faq)
            ));
        } catch (NotFoundException e) {
            return ResponseEntity.status(404).body(Map.of(
                "success", false,
                "error", e.getMessage()
            ));
        }
    }
}

@RestController
@RequestMapping("/api/v1/admin/faq")
@PreAuthorize("hasRole('ADMIN')")
public class AdminFAQController {
    private final FAQService faqService;
    
    public AdminFAQController(FAQService faqService) {
        this.faqService = faqService;
    }
    
    // 관리자 API: 모든 FAQ 조회
    @GetMapping
    public ResponseEntity<Map<String, Object>> getAllFAQs() {
        List<FAQ> faqs = faqService.getAllFAQs();
        return ResponseEntity.ok(Map.of(
            "success", true,
            "data", Map.of("faqs", faqs)
        ));
    }
    
    // 관리자 API: FAQ 생성
    @PostMapping
    public ResponseEntity<Map<String, Object>> createFAQ(@RequestBody FAQ faq) {
        FAQ created = faqService.createFAQ(faq);
        return ResponseEntity.ok(Map.of(
            "success", true,
            "message", "FAQ가 생성되었습니다.",
            "data", created
        ));
    }
    
    // 관리자 API: FAQ 수정
    @PutMapping("/{id}")
    public ResponseEntity<Map<String, Object>> updateFAQ(
            @PathVariable Long id,
            @RequestBody FAQ faq) {
        FAQ updated = faqService.updateFAQ(id, faq);
        return ResponseEntity.ok(Map.of(
            "success", true,
            "message", "FAQ가 수정되었습니다.",
            "data", updated
        ));
    }
    
    // 관리자 API: FAQ 삭제
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> deleteFAQ(@PathVariable Long id) {
        faqService.deleteFAQ(id);
        return ResponseEntity.ok(Map.of(
            "success", true,
            "message", "FAQ가 삭제되었습니다."
        ));
    }
}
```

## 4. 클라이언트 구현 (Flutter)

### 4.1 FAQ Service 생성

```dart
// lib/services/faq_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../interceptors/auth_interceptor.dart';

class FAQService {
  static final FAQService _instance = FAQService._internal();
  factory FAQService() => _instance;
  
  static const String _baseUrl = 'https://api.dksw4.com';
  static const String _faqEndpoint = '/api/v1/faq';
  
  late final Dio _dio;
  
  FAQService._internal() {
    _initDio();
  }
  
  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));
    // 공개 API이므로 인증 인터셉터 불필요
  }
  
  /// FAQ 조회
  Future<Map<String, dynamic>?> getFAQ() async {
    try {
      final response = await _dio.get(_faqEndpoint);
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          return data['data']['faq'] as Map<String, dynamic>?;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ FAQ 조회 실패: $e');
      return null;
    }
  }
}
```

### 4.2 LocalDbService 수정

```dart
// lib/services/local_db_service.dart에 추가

/// FAQ 채팅방 생성 및 메시지 저장 (서버에서 FAQ 가져오기)
Future<void> createFAQRoomIfNeeded() async {
  const String faqRoomName = 'AI 톡비서 FAQ';
  const String faqPackageName = 'com.dksw.app.faq';
  
  final db = await database;
  
  // FAQ 채팅방이 이미 있는지 확인
  final existing = await db.query(
    _tableRooms,
    where: 'room_name = ? AND package_name = ?',
    whereArgs: [faqRoomName, faqPackageName],
  );
  
  if (existing.isNotEmpty) {
    final roomId = existing.first['id'] as int;
    final messageCount = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_tableMessages WHERE room_id = ?',
      [roomId],
    );
    final count = Sqflite.firstIntValue(messageCount) ?? 0;
    
    if (count > 0) {
      debugPrint('✅ FAQ 채팅방이 이미 존재하고 메시지도 있습니다.');
      return;
    }
  }
  
  // 서버에서 FAQ 가져오기
  final faqService = FAQService();
  final faqData = await faqService.getFAQ();
  
  if (faqData == null) {
    debugPrint('⚠️ 서버에서 FAQ를 가져올 수 없습니다.');
    return;
  }
  
  final String faqContent = faqData['content'] as String? ?? '';
  final String faqTitle = faqData['title'] as String? ?? faqRoomName;
  
  // FAQ 채팅방 생성 또는 업데이트
  final now = DateTime.now();
  final nowMillis = now.millisecondsSinceEpoch;
  
  int roomId;
  if (existing.isNotEmpty) {
    roomId = existing.first['id'] as int;
    await db.update(
      _tableRooms,
      {
        'last_message': faqTitle,
        'last_sender': 'AI 톡비서',
        'last_message_time': nowMillis,
        'updated_at': nowMillis,
        'pinned': 0,
      },
      where: 'id = ?',
      whereArgs: [roomId],
    );
  } else {
    roomId = await db.insert(_tableRooms, {
      'room_name': faqRoomName,
      'package_name': faqPackageName,
      'package_alias': 'AI 톡비서',
      'last_message': faqTitle,
      'last_sender': 'AI 톡비서',
      'last_message_time': nowMillis,
      'unread_count': 1,
      'pinned': 0,
      'blocked': 0,
      'muted': 0,
      'summary_enabled': 0,
      'category': 'SYSTEM',
      'participant_count': 0,
      'created_at': nowMillis,
      'updated_at': nowMillis,
    });
  }
  
  // FAQ 메시지 저장
  await db.insert(_tableMessages, {
    'room_id': roomId,
    'sender': 'AI 톡비서',
    'message': faqContent,
    'create_time': nowMillis,
    'room_name': faqRoomName,
  });
  
  debugPrint('✅ FAQ 채팅방 및 메시지 생성 완료 (서버에서 가져옴)');
}
```

## 5. 구현 순서

1. **데이터베이스 테이블 생성**
   - `faq` 테이블 생성
   - 초기 데이터 삽입

2. **서버 API 구현**
   - FAQ 조회 API (`GET /api/v1/faq`)
   - 관리자 API (생성, 수정, 삭제)

3. **클라이언트 구현**
   - `FAQService` 생성
   - `LocalDbService.createFAQRoomIfNeeded()` 수정하여 서버에서 FAQ 가져오기

4. **테스트**
   - 서버 API 테스트
   - 클라이언트에서 FAQ 가져오기 테스트
   - FAQ 채팅방 생성 확인
