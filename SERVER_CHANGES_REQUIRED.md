# 서버 변경 사항 요구사항

## 플랜별 제한 변경

### 1. 무료 플랜 (Free Plan)
- **일일 요약 횟수**: 2회로 변경
- **한번에 요약 가능한 메시지 개수**: 50개 (변경 없음)
- **제한 주기**: 일일 (daily)
- **API**: `/api/v1/llm/usage` 응답에서 `limit: 2` 반환

### 2. Basic 플랜
- **월간 요약 횟수**: 150회로 변경
- **한번에 요약 가능한 메시지 개수**: 200개로 변경 (기존 300개)
- **제한 주기**: 월간 (monthly)
- **API**: `/api/v1/llm/usage` 응답에서 `limit: 150` 반환

## API 응답 형식

### `/api/v1/llm/usage` 응답 예시

**무료 플랜:**
```json
{
  "planType": "free",
  "currentUsage": 1,
  "limit": 2,
  "period": "daily",
  "nextResetDate": "2024-01-28T00:00:00Z"
}
```

**Basic 플랜:**
```json
{
  "planType": "basic",
  "currentUsage": 10,
  "limit": 150,
  "period": "monthly",
  "nextResetDate": "2024-02-01T00:00:00Z"
}
```

## 에러 응답 (429 Too Many Requests)

**무료 플랜:**
```json
{
  "message": "오늘 무료 요약 2/2회 사용 완료",
  "planType": "free",
  "currentUsage": 2,
  "limit": 2,
  "nextResetDate": "2024-01-28T00:00:00Z"
}
```

**Basic 플랜:**
```json
{
  "message": "이번 달 요약 150/150회 사용 완료",
  "planType": "basic",
  "currentUsage": 150,
  "limit": 150,
  "nextResetDate": "2024-02-01T00:00:00Z"
}
```

## 요약 API 제한

### `/api/v1/llm/summary` 요청 시

**무료 플랜:**
- 메시지 개수: 최대 50개
- 일일 요약 횟수: 최대 2회

**Basic 플랜:**
- 메시지 개수: 최대 200개
- 월간 요약 횟수: 최대 150회

## 변경 사항 요약

1. ✅ **클라이언트 변경 완료**
   - Basic 플랜 최대 메시지 개수: 300개 → 200개
   - 플랜별 제한 로직 적용

2. ⚠️ **서버 변경 필요**
   - 무료 플랜 일일 제한: 2회로 설정
   - Basic 플랜 월간 제한: 150회로 설정
   - Basic 플랜 메시지 개수 제한: 200개로 설정 (API 검증)
