import 'package:flutter/material.dart';

/// design_handoff_soft_modern_blue (C1 · Soft Modern Blue) 디자인 토큰.
///
/// 모든 색·라디우스·간격·그림자 값은 README.md §4.x 와 일치해야 함.
/// 새 화면/위젯에서 색을 직접 하드코딩하지 말고 이 클래스를 통해 참조한다.
class AppTokens {
  AppTokens._();

  // ─── Colors ───────────────────────────────────────────
  /// 페이지 배경 — 살짝 푸르게 도는 화이트
  static const Color bg = Color(0xFFF3F6FC);

  /// 카드/시트 표면
  static const Color surface = Color(0xFFFFFFFF);

  /// 1차 텍스트
  static const Color text = Color(0xFF0F1430);

  /// 2차 텍스트 (본문 보조)
  static const Color text2 = Color(0xFF5B6280);

  /// 3차 텍스트 (메타·플레이스홀더)
  static const Color text3 = Color(0xFF9097B1);

  /// 카드 내부 행 사이 헤어라인
  static const Color hair = Color(0xFFE7ECF6);

  /// 카드/컴포넌트 외곽 보더
  static const Color border = Color(0xFFE1E7F3);

  /// 브랜드 액센트 (CTA·활성·AI 마커)
  static const Color accent = Color(0xFF3B6DFF);

  /// 액센트 배경 (활성 칩, 'AI 요약' 배지)
  static const Color accentSoft = Color(0xFFE7EFFF);

  /// 보조 액센트 (장식 스파클 등)
  static const Color accent2 = Color(0xFF9AB2FF);

  /// 그라데이션 시작 (서머리 배너·무료플랜 카드)
  static const Color gradStart = Color(0xFFE6EEFF);

  /// 그라데이션 끝
  static const Color gradEnd = Color(0xFFF5F8FF);

  /// 경고 보조 텍스트 (예: "알림 권한이 필요합니다")
  static const Color warn = Color(0xFFB85A36);

  /// 토글 OFF 트랙
  static const Color togglePadding = Color(0xFFDEDBEB);

  // ─── Card shadow ──────────────────────────────────────
  /// 카드가 살짝 떠 있는 느낌. 큰 블러·글로스 금지.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0D0F1430), // rgba(15,20,48,0.05)
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x1A0F1430), // rgba(15,20,48,0.10)
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -12,
    ),
  ];

  // ─── Radii ───────────────────────────────────────────
  static const double radiusCard = 16;     // 메시지/설정 섹션 카드
  static const double radiusCardSm = 14;   // 더 작은 카드
  static const double radiusHero = 18;     // 무료플랜 히어로 카드
  static const double radiusChip = 10;     // 메신저 탭 칩
  static const double radiusPill = 999;    // 활성 배지·토글 트랙
  static const double radiusAvatar = 12;   // 아바타 (모서리 살짝)
  static const double radiusCta = 12;      // CTA 버튼

  // ─── Spacing ─────────────────────────────────────────
  static const double pagePadH = 16;     // 페이지 좌우 여백
  static const double cardPad = 14;      // 카드 내부 패딩 기본
  static const double cardPadLg = 18;    // 큰 카드 내부 패딩
  static const double rowPadV = 14;      // 카드 내부 행 세로 패딩
  static const double rowPadH = 16;      // 카드 내부 행 가로 패딩
  static const double cardGap = 8;       // 메시지 카드 사이 gap
  static const double sectionGap = 22;   // 섹션 사이 간격

  // ─── Toggle ──────────────────────────────────────────
  static const double toggleTrackW = 42;
  static const double toggleTrackH = 24;
  static const double toggleKnob = 20;

  // ─── Header ──────────────────────────────────────────
  static const double headerHeight = 56;
  static const double appLogoSize = 26;

  // ─── Font family ─────────────────────────────────────
  /// pubspec.yaml 에 등록된 Pretendard family. MaterialApp.theme 의 fontFamily.
  static const String fontFamily = 'Pretendard';
}

/// 텍스트 스타일 헬퍼 — 핸드오프 §5 Typography 직역.
class AppText {
  AppText._();

  /// App bar 타이틀 ("AI 톡비서", "앱 설정")
  static const TextStyle appBarTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppTokens.text,
    letterSpacing: -0.34, // -0.02em @ 17px
  );

  /// 메시지 카드 — 채팅방 이름
  static const TextStyle messageName = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppTokens.text,
    letterSpacing: -0.07, // -0.005em @ 14px
  );

  /// 메시지 카드 — 미리보기 본문
  static const TextStyle messagePreview = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppTokens.text2,
  );

  /// 메시지 카드 — 시간
  static const TextStyle messageTime = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppTokens.text3,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 메시지 카드 — 'AI 요약' 배지
  static const TextStyle aiBadge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppTokens.accent,
  );

  /// 설정 섹션 라벨
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppTokens.text,
  );

  /// 설정 행 — 라벨
  static const TextStyle rowLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppTokens.text,
  );

  /// 설정 행 — 서브카피
  static const TextStyle rowSub = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppTokens.text3,
  );

  /// 설정 행 — 서브카피 (warn)
  static const TextStyle rowSubWarn = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppTokens.warn,
  );

  /// 무료플랜 카드 헤드라인
  static const TextStyle heroHeadline = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppTokens.text,
    height: 1.35,
  );

  /// 무료플랜 카드 체크리스트 항목
  static const TextStyle heroCheck = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppTokens.text2,
  );

  /// CTA 버튼 라벨
  static const TextStyle cta = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  /// 푸터 (버전·카피라이트)
  static const TextStyle footer = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppTokens.text3,
    height: 18 / 11,
  );
}
