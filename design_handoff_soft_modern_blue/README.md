# AI 톡비서 — Settings & Home Redesign Handoff

**디자인 방향:** `C1 · 소프트 모던 블루` (Soft Modern Blue)
**대상 화면:** 메인 (오늘의 요약), 앱 설정 상단, 앱 설정 하단

---

## 1. Overview

AI 톡비서는 KakaoTalk / LINE / Telegram / Instagram 등의 메신저 메시지를 AI가 요약해 주는 Android 앱입니다. 이번 리디자인은 **메인 홈** 과 **앱 설정 화면(상·하)** 두 영역을 대상으로, 기존의 형광 파랑 헤더 / 강한 노랑 활성 탭 / 글로스 그라데이션 배너 등을 정리하고, **차분한 블루 + 화이트 카드 + 라인 아이콘** 으로 재구성한 버전입니다.

전체적인 결은 Linear / Vercel / Notion 류의 모던 AI 프로덕트와 비슷합니다 — 부드러운 블루 액센트, 살짝 떠 있는 듯한 카드, AI 요약 메타데이터를 강조하는 작은 ✦ 마커.

> **로고는 별도로 진행 중**입니다. 현재 헤더에 들어간 작은 "톡" 모노그램은 플레이스홀더입니다. 최종 로고가 정해지면 컴포넌트 하나만 교체하면 됩니다 (`AppLogo`).

---

## 2. About the design files in this bundle

이 폴더의 `.html` / `.jsx` 파일들은 **디자인 레퍼런스**입니다 — 의도된 비주얼과 인터랙션을 보여주기 위해 React + Babel 으로 만든 프로토타입이고, 그대로 프로덕션에 옮기는 코드가 아닙니다.

실제 구현은 본 앱의 코드베이스 환경(예: React Native, Kotlin/Jetpack Compose, Flutter 등)에서 기존 패턴·디자인 시스템을 따라 **이 디자인을 재구현**하는 방식이어야 합니다. README에 정리된 디자인 토큰 / 컴포넌트 스펙 / 데이터 모양은 어느 프레임워크에도 그대로 옮길 수 있도록 작성됐습니다.

---

## 3. Fidelity

**High fidelity.** 색상, 타이포, 간격, 그림자, 보더 라디우스 모두 최종 의도값입니다. 픽셀 단위로 가깝게 재현해 주세요. 사용 폰트(Pretendard), 색상(헥스), 카드 라디우스 14–18px, 행 패딩 14px 등은 모두 의도된 값입니다.

---

## 4. Design tokens

### 4.1 Colors (C1 · Soft Modern Blue)

| Token | Value | Usage |
|---|---|---|
| `bg` | `#f3f6fc` | 페이지 배경 — 살짝 푸르게 도는 화이트 |
| `surface` | `#ffffff` | 카드 / 시트 표면 |
| `text` | `#0f1430` | 1차 텍스트 |
| `text2` | `#5b6280` | 2차 텍스트 (본문 보조) |
| `text3` | `#9097b1` | 3차 텍스트 (메타·플레이스홀더) |
| `hair` | `#e7ecf6` | 카드 *내부* 행 사이 헤어라인 |
| `border` | `#e1e7f3` | 카드 / 컴포넌트 외곽 보더 |
| `accent` | `#3b6dff` | 브랜드 액센트 (CTA, 활성 상태, AI 마커) |
| `accentSoft` | `#e7efff` | 액센트 배경 (활성 칩, 'AI 요약' 배지) |
| `accent2` | `#9ab2ff` | 보조 액센트 (장식 스파클 등) |
| `gradStart` | `#e6eeff` | 그라데이션 시작 (서머리 배너, 무료플랜 카드) |
| `gradEnd` | `#f5f8ff` | 그라데이션 끝 |
| `warn` | `#b85a36` | 경고 보조 텍스트 (예: "알림 권한이 필요합니다") |
| `togglePadding` | `#dedbeb` | 토글 OFF 트랙 |

> 위 컬러는 `design_handoff_soft_modern_blue/screens-c.jsx` 의 `C_SOFT` 객체와 일치합니다.

### 4.2 Card shadow

```
0 1px 2px rgba(15,20,48,0.05),
0 8px 24px -12px rgba(15,20,48,0.10)
```

부드럽고 작은 그림자 — 카드가 살짝 떠 있는 느낌. **글로스 / 큰 블러 / 그라데이션 섀도는 금지.**

### 4.3 Radii

| | Value |
|---|---|
| 메시지 카드 / 설정 섹션 카드 | `14–16px` |
| 무료 플랜 카드 (히어로) | `18px` |
| 메신저 탭 칩 | `10px` |
| 활성 상태 작은 배지 (pill) | `999px` (fully round) |
| 아바타 | `12px` (모서리 살짝) |
| CTA 버튼 | `12px` |
| 토글 트랙 / 노브 | `999px` / `50%` |

### 4.4 Spacing

- 페이지 좌우 여백: **16px**
- 카드 내부 패딩: **14–18px**
- 행과 행 사이 간격: 메시지 리스트는 카드 사이 `gap: 8px`, 설정 카드 내부 행은 헤어라인으로 구분 (각 행 padding `14px 16px`)
- 섹션 사이 간격: 약 **20–22px**

---

## 5. Typography

**폰트:** `Pretendard Variable` (Korean + Latin). 디바이스에 없으면 시스템 산세리프로 폴백. iOS/Android 양쪽 모두 Pretendard 권장.

| Role | Size | Weight | Color | Notes |
|---|---|---|---|---|
| App bar 타이틀 ("AI 톡비서", "앱 설정") | 17px | 700 | `text` | letter-spacing `-0.02em` |
| 서머리 배너 메타 ("오늘 아침 요약 완료") | 12px | 400 | `text2` | line-height 1.3 |
| 서머리 배너 본문 ("7개 채팅방 · 195개 메시지") | 13px | 600 | `text` | line-height 1.3 |
| 메시지 카드 — 채팅방 이름 | 14px | 600 | `text` | ellipsis 1줄, letter-spacing `-0.005em` |
| 메시지 카드 — 미리보기 본문 | 13px | 400 | `text2` | ellipsis 1줄 |
| 메시지 카드 — 시간 | 11px | 400 | `text3` | tabular-nums |
| 메시지 카드 — 'AI 요약' 배지 | 10px | 700 | `accent` | `accentSoft` 배경 |
| 메시지 카드 — N개 카운트 배지 | 10px | 600 | 100개 미만 `text2` / 100개 이상 흰색 (배경 `accent`) | tabular-nums |
| 설정 섹션 라벨 ("알림", "채팅방 설정") | 13px | 700 | `text` | 앞에 16px 아이콘 (accent 컬러) |
| 설정 행 — 라벨 | 14px | 500 | `text` | |
| 설정 행 — 서브카피 | 12px | 400 | `text3` (또는 경고시 `warn`) | |
| 무료플랜 카드 헤드라인 | 16px | 700 | `text` | 2줄, line-height 1.35 |
| 무료플랜 카드 체크리스트 항목 | 13px | 400 | `text2` | 앞에 11px ✓ 아이콘 in accent 원형 |
| CTA 버튼 라벨 | 13px | 700 | `#fff` | 패딩 `11px 14px` |
| 푸터 (버전, 카피라이트) | 11px | 400 | `text3` | center-aligned, line-height 18px |

---

## 6. Iconography

전부 **24-grid, 1.6px stroke, currentColor 라인 아이콘**으로 통일. 채움 아이콘은 ✦ 스파클 하나만 (강조용). 회로 패턴 / 글로스 / 다색 이모지스러운 아이콘은 모두 제거.

필요한 아이콘 (구현 시 `lucide-react` / `Material Symbols Rounded` 등 기존 아이콘 라이브러리에서 동일 메타포를 골라 사용해도 됨):

```
back     ← chevron-left
bell     ← bell                bellOff
gear     ← settings
spark    ← sparkles (single 4-point)  — accent 컬러로 칠해서 강조
chevron  → chevron-right       (행 우측 끝)
check    ✓ (작은 체크리스트 마커)
megaphone announcements (소식·도움말)
party    이벤트
help     자주 묻는 질문
star     리뷰
share    친구 추천
qmark    사용방법
info     앱 소개
policy   정책·약관
msg      메신저 관리
block    차단된 채팅방
```

(현 디자인 파일에서 `<I name="..."/>` 으로 참조되는 아이콘 목록입니다.)

---

## 7. Screens

### 7.1 메인 (홈) — `MainScreen`

#### Layout (top → bottom)

1. **App bar** (높이 약 56px)
   - 좌측: 작은 로고 (26px 스퀘어, accent 컬러 배경, 흰 마크) + 타이틀 **"AI 톡비서"**
   - 우측: 아이콘 버튼 두 개 — `bell`, `gear` (각 36×36 탭 타겟, 24px 아이콘, 컬러 `text2`)
   - 배경 `bg`, 보더 없음 (페이지 배경과 동일)

2. **Summary banner** — 그라데이션 카드
   - 위에서 12px 떨어져 시작, 좌우 16px 여백
   - 패딩 `10px 14px`, 라디우스 `12px`, 보더 `1px solid border`
   - 배경: `linear-gradient(135deg, gradStart, gradEnd)`
   - 내용 (좌 → 우):
     - 28×28 정사각 라디우스 8px, `accent` 배경, 흰색 `spark` 아이콘
     - 메타 줄 ("오늘 아침 요약 완료") + 본문 ("7개 채팅방 · 195개 메시지")
     - 시간 ("오전 8:13") — `text3`, tabular-nums

3. **Messenger tabs** — 칩 형태
   - 가로 스크롤 가능, gap 6px, 좌우 16px 여백
   - 칩 패딩 `8px 12px`, 라디우스 10px
   - **비활성** 칩: 배경 투명, 보더 `border`, 텍스트 `text2`
   - **활성** 칩 (현재 선택된 메신저): 배경 `accentSoft`, 보더 `accent`, 텍스트 `accent`, weight 600
   - 안 읽음 카운트 표시: 칩 우측 끝에 작은 둥근 박스 (16px 최소폭) — 활성 시 흰 배경 + accent 글자, 비활성 시 페이지 배경 + `text3`
   - 탭 라벨: `카카오톡`, `LINE`, `Telegram`, `Instagram` (실제 메신저 식별자 기반)

4. **Messages list** — 플로팅 카드들의 세로 스택
   - 좌우 14px 여백, 카드 사이 8px gap
   - 각 메시지 카드 컴포넌트 → 7.4 참조
   - 광고는 별도 스타일 — 7.5 참조

#### Behaviors

- 메신저 칩 탭 → 해당 메신저의 채팅방 리스트로 필터링
- 메시지 카드 탭 → 해당 채팅방의 AI 요약 상세 화면으로 진입
- 광고 카드 "더보기" 탭 → 광고주 페이지 / 보상형 광고 시청 플로우
- 종/기어 아이콘 → 알림 센터 / 앱 설정 진입
- 스크롤은 자연스러운 1방향 세로 스크롤 (서머리 배너는 sticky 아님 — 위로 같이 흐름)

---

### 7.2 앱 설정 · 상단 — `SettingsScreenTop`

#### Layout

1. **App bar**
   - 좌측: 작은 로고 + "앱 설정"
   - 우측 actions: 없음 (또는 빈 공간)
   - 좌측 끝에 ← 백 버튼 (22px) 들어감 — 로고 자리에 백 버튼이 오고, 로고는 생략됨

2. **무료 플랜 카드** (히어로)
   - 좌우 16px 여백
   - 라디우스 18px, 보더 `1px solid border`, 그림자 위 4.2
   - 배경: `linear-gradient(140deg, gradStart 0%, #fff 100%)` — 부드러운 좌상 → 우하 페이드
   - 우상단 28px ✦ 스파클 (accent2 컬러, 장식용)
   - 내용:
     - 작은 pill "무료 플랜" — 흰 배경 + 보더, accent 글자, weight 700, 11px
     - 헤드라인 "Basic으로 업그레이드해 / 더 많이 요약하세요" — 16/700, max-width 220px, 줄바꿈 강제
     - 체크리스트 3줄: 16px accent 원에 흰 ✓ + 13px text2 항목
       - "하루 최대 5회 무료 요약"
       - "메시지 최대 50개 요약"
       - "3회 광고 시청 시 제공"
     - CTA 버튼 "Basic 살펴보기" — 풀너비, accent 배경, 흰 글자 700/13px, 라디우스 12px, 패딩 `11px 14px`

3. **섹션: 알림** — `SectionCard`
   - 카드 위 라벨 행: 14px spark 아이콘(accent) + "알림" 13/700
   - 카드 내부 3개 토글 행 — 헤어라인으로 구분
     - "자동 요약 알림" / 서브 "알림 권한이 필요합니다" *(warn 컬러)* / 토글 OFF
     - "소리" / "알림이 꺼져 있습니다" / OFF
     - "진동" / "알림이 꺼져 있습니다" / OFF
   - 토글 사양: 트랙 42×24, OFF 색 `togglePadding`, ON 색 `accent`, 노브 20×20 흰색 + 작은 섀도

4. **섹션: 채팅방 설정** — `SectionCard`
   - 라벨 행: 14px msg 아이콘(accent) + "채팅방 설정"
   - 행 3개 (모두 nav row → `chevron-right`):
     - "메신저 관리" / "사용할 메신저 선택 및 순서 변경"
     - "차단된 채팅방 관리" / "요약에서 제외할 채팅방"
     - "요약 관리" / "요약 표시 방식 설정"

#### Behaviors

- 토글 탭 → 권한 요청 다이얼로그 (자동 요약 알림) 혹은 즉시 토글
- nav 행 탭 → 해당 하위 화면 진입
- CTA 탭 → 인앱 결제 / 플랜 비교 화면

---

### 7.3 앱 설정 · 하단 — `SettingsScreenBottom`

같은 App bar (← + "앱 설정").

1. **섹션: 소식·도움말** — nav 행 3개
   - 공지사항 / "새 공지를 확인해보세요"
   - 이벤트 / "진행 중 이벤트가 있을 수 있어요"
   - 자주 묻는 질문 / "15건 등록됨"
   - 라벨 아이콘: `megaphone` (accent)

2. **섹션: 일반** — nav 행 5개
   - 리뷰를 남겨주세요 / "소중한 리뷰가 큰 힘이 됩니다"
   - 친구에게 추천하기 / "앱을 친구와 공유해보세요"
   - AI 톡비서 사용방법 / "앱 사용 가이드"
   - AI 톡비서 란 / "앱 소개 및 기능 안내"
   - 정책 및 약관 / "개인정보처리방침·이용약관 등"
   - 라벨 아이콘: `gear` (accent)

3. **푸터**
   - 가운데 정렬, 위로 28px 여백
   - 1줄: accent 컬러로 작은 ✦ + "AI 톡비서" 11/600
   - 2줄: "App version: 1.0.30" — text3
   - 3줄: "Copyright 2026. 동키소프트웨어 All rights reserved." — text3

#### Behaviors

- 행 탭 → 각 서브 화면 / 외부 링크 (리뷰: 스토어 리뷰 인텐트, 친구 추천: 공유 시트, 정책·약관: 웹뷰 또는 외부 브라우저)

---

## 8. Component breakdown

이 디자인의 재사용 컴포넌트들. 코드베이스 컨벤션에 맞춰 이름을 바꿔도 됩니다.

### 8.1 `AppLogo`
- 24–28px 정사각 (스퀘어클: 라디우스 = 변의 22.5%)
- accent 배경, 흰 마크
- **현재 플레이스홀더 마크:** 한글 "톡" 모노그램 (`LogoMegaTok` in `logos.jsx`)
- 최종 로고가 정해지면 이 컴포넌트만 교체

### 8.2 `Header`
- props: `title`, `back?: boolean`, `right?: ReactNode`, `subBelow?: ReactNode`
- 좌측: `back` true면 `chevron-left`, 아니면 `AppLogo`
- 가운데 (좌측 정렬, flex:1): title 17/700
- 우측: `right` 슬롯 (보통 bell + gear)
- `subBelow` 가 있으면 헤더 바로 아래 한 단락 (서머리 배너용)

### 8.3 `MessengerTabs`
- props: `tabs: Tab[]`, `activeId`, `onChange`
- Tab: `{ id, label, unread: number }`
- 가로 스크롤, 칩 스타일

### 8.4 `MessageCard`
- props: `avatarInitial`, `avatarBg`, `name`, `preview`, `time`, `count?`, `isAiSummary?`
- 아바타 40×40 라디우스 12px (배경은 채팅방 색, 흰 글자 1자)
- 본문 1줄 ellipsis
- 메타 행: AI 요약 배지 + 카운트 배지 (조건부)

### 8.5 `AdCard`
- 동일 골격이나 보더가 점선 (`1px dashed border`), 배경 살짝 더 밝게
- 좌측 `megaphone` 아이콘, "AD" 라벨, "더보기" 버튼

### 8.6 `SectionCard`
- props: `label`, `icon`, `children`
- 위 14px 라벨 행 + 카드 컨테이너 (라디우스 16px, 보더, 그림자)
- 자식은 자연스럽게 헤어라인으로 구분되는 `Row` 들

### 8.7 `ToggleRow`
- props: `label`, `sub?`, `warn?`, `value`, `onChange`
- 우측 토글 (트랙 42×24)

### 8.8 `NavRow`
- props: `label`, `sub?`, `onPress`
- 우측 `chevron-right`

### 8.9 `PlanHeroCard`
- 무료 플랜 카드 (상수처럼 유일 사용) — props: `items[]`, `headline`, `ctaLabel`, `onCta`

---

## 9. Mock data shapes

`data.jsx` 의 데이터 모양 그대로 옮겨도 됩니다.

```ts
type ChatSummary = {
  id: string;
  initial: string;        // 아바타 1자
  avatarBg: string;       // 헥스
  name: string;
  preview: string;        // AI가 요약한 한 줄
  time: string;           // "오전 8:09" 포맷 (실제 구현에서는 Date)
  count?: number;         // 요약된 메시지 개수
  source: 'kakao' | 'line' | 'telegram' | 'instagram';
  ai?: boolean;           // AI 요약 됐는지
};

type Ad = {
  id: string;
  ad: true;
  name: string;
  preview: string;
};

type Messenger = {
  id: string;
  label: string;
  unread: number;
};
```

---

## 10. Interactions & motion

- 토글 노브 좌↔우 이동: `transition: left .15s ease`
- 카드 / 버튼 탭 시 살짝 어두워지는 ripple 또는 active state — Android Material ripple 또는 native press 효과로 OK
- 메신저 칩 변경 시 리스트 페이드/슬라이드 인 (옵션) — 굳이 안 넣어도 됨
- 메인 → 설정 진입: 표준 슬라이드 인 / 뒤로 가기는 ← 버튼 또는 시스템 백 제스처

---

## 11. States not yet designed (TODO)

이번 핸드오프 범위 밖이지만 구현 시 필요할 수 있는 상태:

- 메시지 0건 (empty state) — 채팅방이 0개거나 오늘 메시지가 없을 때
- AI 요약 로딩 중 (skeleton) — 메시지 카드 자리에 헤어 펄스
- 권한 거부 후 진입 (notification permission 거부 경로)
- 다크 모드 — C1 팔레트의 다크 미러는 별도 정의 필요
- 푸시 알림 도착 시 인앱 토스트

위 항목들이 필요하면 같은 디자인 시스템으로 별도 화면을 그릴 수 있습니다.

---

## 12. Files in this bundle

- `README.md` — 이 문서
- `preview.html` — 3개 화면을 가로로 펼친 프리뷰 (Chrome 등에서 바로 열면 됨)
- `screens-c.jsx` — 화면 컴포넌트 (`makeCSet(C_SOFT)` 의 결과가 `C1.Main` / `C1.SettingsTop` / `C1.SettingsBot`). C2/C3 코드도 포함되어 있지만 채택본은 C1
- `data.jsx` — 목 데이터 + 라인 아이콘 셋 (`I` 컴포넌트)
- `logos.jsx` — 로고 마크 후보들 (헤더에 들어간 작은 마크는 `LogoMegaTok`)
- `android-frame.jsx` — 프리뷰용 안드로이드 디바이스 프레임 (실제 앱에는 불필요)

---

## 13. Definition of done

- C1 팔레트의 색·라디우스·그림자·간격값이 토큰화돼 코드베이스에 들어가 있다
- 메인 / 설정 상단 / 설정 하단 3개 화면이 7.1–7.3 스펙대로 구현돼 있다
- Pretendard Variable 폰트가 로딩되고 적용된다
- 라인 아이콘 셋이 24px / 1.6px stroke / currentColor 규칙으로 통일돼 있다
- 토글/Nav 행/카드 컴포넌트가 재사용 가능한 형태로 추출돼 있다
- 로고는 `AppLogo` 컴포넌트 한 곳에서만 참조 — 추후 교체 용이
