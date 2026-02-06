/// 개인정보 마스킹 서비스 (On-device anonymization)
/// LLM 전송 전에 PII 제거 + 의미 보존 토큰화
class PrivacyMaskingService {
  static final PrivacyMaskingService _instance = PrivacyMaskingService._internal();
  factory PrivacyMaskingService() => _instance;
  PrivacyMaskingService._internal();

  /// 텍스트에서 민감 정보 마스킹 (전화번호, 계좌번호 등)
  static String maskSensitiveInfo(String text) {
    if (text.isEmpty) return text;
    return PrivacyMaskingService().maskPersonalInfo(text);
  }

  /// 텍스트에서 개인정보 마스킹
  String maskPersonalInfo(String text) {
    if (text.isEmpty) return text;
    String masked = text;

    // =========================
    // 1) 주민번호 (우선) - 앞 6자리 + 뒷 7자리(1-4로 시작)
    // =========================
    masked = masked.replaceAllMapped(
      RegExp(r'\b\d{6}[-\s]?[1-4]\d{6}\b'),
      (_) => '[SSN]',
    );

    // =========================
    // 2) 전화번호 (계좌번호보다 우선 처리)
    // 하이픈 있음: 010-1234-5678, 010-123-4567, 02-123-4567 등
    // 하이픈 없음: 01012345678, 0101234567, 021234567 등
    // =========================
    masked = masked.replaceAllMapped(
      RegExp(r'\b(01[016789]|02|0[3-9]\d)[-.\s]?\d{3,4}[-.\s]?\d{4}\b'),
      (_) => '[PHONE]',
    );

    // =========================
    // 3) 계좌번호 (10~16자리, 전화번호 패턴 제외)
    // 전화번호 패턴이 아닌 숫자-숫자-숫자 형식만 체크
    // =========================
    masked = masked.replaceAllMapped(
      RegExp(r'\b\d{2,4}-?\d{2,6}-?\d{4,8}\b'),
      (m) {
        final match = m.group(0)!;
        final digits = match.replaceAll(RegExp(r'\D'), '');
        
        // 전화번호 패턴이면 건너뛰기 (이미 위에서 처리됨)
        if (RegExp(r'^(01[016789]|02|0[3-9]\d)\d{7,8}$').hasMatch(digits)) {
          return match;
        }
        
        // 계좌번호 패턴만 처리 (10~16자리)
        if (digits.length >= 10 && digits.length <= 16) {
          return '[ACCOUNT]';
        }
        return match;
      },
    );

    // =========================
    // 4) 이메일
    // =========================
    masked = masked.replaceAllMapped(
      RegExp(r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b'),
      (_) => '[EMAIL]',
    );

    // =========================
    // 5) 주소 (숫자 포함된 경우만)
    // =========================
    masked = masked.replaceAllMapped(
      RegExp(
        r'\b(서울|부산|대구|인천|광주|대전|울산|세종|경기|강원|충북|충남|전북|전남|경북|경남|제주)[가-힣\s0-9\-]+(번지|로|길|동|호)\b',
      ),
      (_) => '[ADDRESS]',
    );

    return masked;
  }

  /// 메시지 리스트 마스킹
  List<Map<String, dynamic>> maskMessages(List<Map<String, dynamic>> messages) {
    return messages.map((msg) {
      final masked = Map<String, dynamic>.from(msg);

      // message PII 제거 (발신자 이름/닉네임은 그대로 유지)
      if (masked['message'] != null) {
        masked['message'] = maskPersonalInfo(masked['message'].toString());
      }

      return masked;
    }).toList();
  }

  /// 세션 초기화 (채팅방 바뀔 때 호출)
  void resetSession() {
    // 발신자 익명화 제거로 인해 세션 초기화 불필요
  }
}
