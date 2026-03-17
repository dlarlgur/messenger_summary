# Play Integrity + JWT + Redis 기반 인증 및 요금제 시스템 구현 요약

## 구현 완료 사항

### 1. AIPF 서버 (Spring Boot)

#### 1.1 Play Integrity 검증 및 JWT 발급
- **엔드포인트**: `POST /api/v1/auth/token`
- **기능**:
  - Google Play Integrity 토큰 검증
  - deviceId를 SHA-256으로 해싱
  - JWT 토큰 발급 (30일 유효기간)
  - 해싱된 deviceId를 JWT의 `sub`에 저장

**파일**:
- `PlayIntegrityService.java`: Play Integrity API 검증
- `JwtService.java`: JWT 생성/검증 (deviceId 해싱 포함)
- `AuthController.java`: `/api/v1/auth/token` 엔드포인트

#### 1.2 Redis 사용량 관리
- **Free 플랜**: 일 3회 (`usage:free:{date}:{idHash}`, TTL 24시간)
- **Basic 플랜**: 월 200회 (`usage:pro:{month}:{idHash}`, TTL 해당 월 말일)
- **Atomic Operation**: Redis INCR 명령어 사용

**파일**:
- `UsageLimitService.java`: 사용량 체크 및 증가 로직
- `RedisConfig.java`: String 값 저장용 ReactiveRedisTemplate 추가

#### 1.3 LLM 요약 API 개선
- **엔드포인트**: `POST /api/v1/llm/summary`
- **기능**:
  - JWT 기반 인증 (deviceIdHash 추출)
  - 메시지 300개 제한 (초과 시 자동 truncate)
  - 사용량 체크 (Redis 기반)
  - 429 에러 처리 (다음 갱신일 정보 포함)

**파일**:
- `LlmController.java`: 사용량 체크 및 메시지 제한 로직 추가
- `JwtAuthenticationFilter.java`: Device 토큰 지원 추가

### 2. Flutter 앱 (chat_llm)

#### 2.1 Play Integrity 통합
- Google Play Integrity 토큰 요청
- 서버로 토큰 전송하여 JWT 발급

**파일**:
- `auth_service.dart`: Play Integrity 토큰 요청 및 JWT 관리

#### 2.2 Dio 인터셉터
- **자동 헤더 추가**:
  - `Authorization: Bearer {JWT}`
  - `X-Timestamp`: 현재 시간 (밀리초)
- **에러 처리**:
  - 401: 토큰 재요청
  - 429: 사용량 초과 알림 (다음 갱신일 표시)

**파일**:
- `auth_interceptor.dart`: JWT 및 타임스탬프 헤더 자동 추가

#### 2.3 Secure Storage
- JWT 토큰을 `flutter_secure_storage`에 저장
- 앱 재시작 시에도 토큰 유지

#### 2.4 민감 정보 마스킹
- 전송 전 정규식으로 전화번호, 계좌번호 등 마스킹
- `PrivacyMaskingService.maskSensitiveInfo()` 사용

**파일**:
- `privacy_masking_service.dart`: `maskSensitiveInfo()` static 메서드 추가

#### 2.5 마크다운 렌더링
- `\n` 문자를 실제 줄바꿈으로 렌더링
- 숫자 리스트와 불렛포인트 지원

**파일**:
- `markdown_text.dart`: 마크다운 텍스트 렌더링 위젯

## 설정 파일

### AIPF 서버 설정 (`application-local.yml`)
```yaml
jwt:
  device-token-expiration: 2592000000  # 30일

google:
  play-integrity:
    project-id: ${GOOGLE_PLAY_INTEGRITY_PROJECT_ID:}
    service-account-key: ${GOOGLE_PLAY_INTEGRITY_SERVICE_ACCOUNT_KEY:}
```

### Flutter 앱 설정 (`pubspec.yaml`)
```yaml
dependencies:
  flutter_secure_storage: ^9.0.0
  google_play_integrity: ^1.0.0
```

## 데이터 흐름

1. **[chat_llm 앱]**: Google Play Integrity 토큰 요청
2. **[chat_llm 앱 → AIPF]**: `/api/v1/auth/token`으로 토큰 전송
3. **[서버(AIPF)]**: Google API로 토큰 검증 후, deviceId를 SHA-256으로 해싱하여 JWT 발급
4. **[chat_llm 앱 → AIPF]**: JWT와 함께 카톡 메시지(최대 300개) 요약 요청
5. **[서버(AIPF)]**: Redis에서 사용량(월 200회) 및 Message Capping(300개) 체크
6. **[서버(AIPF) → AIIF]**: 검증된 요청을 전달하여 LLM 요약 수행 (Gemini 2.5 Flash)
7. **[서버(AIPF) → chat_llm 앱]**: 결과 반환 및 잔여 횟수 업데이트

## 주요 특징

- **비동기 구조**: Spring WebFlux 기반으로 만 명 동시 접속 지원
- **Atomic Operations**: Redis INCR로 동시 요청 시 카운트 꼬임 방지
- **보안**: deviceId 해싱, JWT 토큰, Secure Storage 사용
- **사용자 경험**: 429 에러 시 다음 갱신일 정보 제공, 자동 토큰 재요청

## 다음 단계

1. Google Play Integrity 프로젝트 설정 및 서비스 계정 키 발급
2. Flutter 앱의 `auth_service.dart`에서 `YOUR_CLOUD_PROJECT_NUMBER` 실제 값으로 교체
3. 테스트 및 배포
