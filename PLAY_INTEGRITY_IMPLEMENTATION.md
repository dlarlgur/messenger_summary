# Play Integrity 검증 구현 완료

## 구현 내용

### 1. PlayIntegrityConfig (Bean 생성)
**파일**: `src/main/java/com/dksw/aipf/config/PlayIntegrityConfig.java`

- `src/main/resources/google-integrity-key.json` 파일을 읽어서 `PlayIntegrity` Bean 생성
- Google Credential을 생성하고 Play Integrity API 클라이언트 초기화
- Project ID를 별도 Bean으로 제공

**사용 방법**:
```java
@Bean
public PlayIntegrity playIntegrity() {
    // google-integrity-key.json 파일을 읽어서 PlayIntegrity 객체 생성
}
```

### 2. IntegrityService (토큰 검증 및 기기 무결성 확인)
**파일**: `src/main/java/com/dksw/aipf/service/IntegrityService.java`

**주요 기능**:
1. **토큰 검증**: 클라이언트가 보낸 Integrity Token을 Google API로 검증
2. **기기 무결성 확인**: `deviceIntegrity.DeviceRecognitionVerdicts` 확인
3. **루팅/변조 차단**: 허용되지 않은 기기는 에러 발생

**허용 가능한 Verdicts**:
- `MEETS_STRONG_INTEGRITY`: 강한 무결성 (변조 없음) ✅
- `MEETS_DEVICE_INTEGRITY`: 기기 무결성 (변조 없음) ✅
- `MEETS_BASIC_INTEGRITY`: 기본 무결성 (루팅/변조 가능) ❌
- `MEETS_VIRTUAL_INTEGRITY`: 가상 기기 (에뮬레이터) ❌

**에러 처리**:
- `deviceIntegrity`가 null이면 `AipfException(ErrorCode.UNAUTHORIZED)` 발생
- `verdicts`가 비어있으면 `AipfException(ErrorCode.UNAUTHORIZED)` 발생
- 허용된 verdict가 없으면 (루팅/변조된 기기) `AipfException(ErrorCode.UNAUTHORIZED)` 발생

### 3. AuthController 수정
**파일**: `src/main/java/com/dksw/aipf/controller/AuthController.java`

- `PlayIntegrityService` → `IntegrityService`로 변경
- `/api/v1/auth/token` 엔드포인트에서 `IntegrityService` 사용

## 설정 파일

### application-local.yml
```yaml
google:
  play-integrity:
    project-id: ${GOOGLE_PLAY_INTEGRITY_PROJECT_ID:}  # Google Cloud Project ID (숫자)
```

### 필요한 파일
- `src/main/resources/google-integrity-key.json`: Google Play Integrity 서비스 계정 키 JSON 파일

## 사용 흐름

1. **클라이언트**: Play Integrity 토큰 요청
2. **클라이언트 → 서버**: `/api/v1/auth/token`으로 토큰 전송
3. **서버**: `IntegrityService.verifyTokenAndExtractDeviceId()` 호출
   - Google API로 토큰 검증
   - `deviceIntegrity.DeviceRecognitionVerdicts` 확인
   - 루팅/변조된 기기면 에러 발생
   - 정상 기기면 deviceId 추출
4. **서버**: deviceId를 SHA-256 해싱하여 JWT 발급
5. **서버 → 클라이언트**: JWT 토큰 반환

## 보안 특징

- ✅ 루팅된 기기 차단
- ✅ 변조된 기기 차단
- ✅ 에뮬레이터 차단
- ✅ 정상 기기만 JWT 발급

## 다음 단계

1. `google-integrity-key.json` 파일을 `src/main/resources/` 폴더에 배치
2. `GOOGLE_PLAY_INTEGRITY_PROJECT_ID` 환경변수 설정 (또는 application.yml에 직접 입력)
3. 테스트 및 배포
