import 'package:flutter/material.dart';

/// AI 톡비서 사용 가이드 화면
class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  static const Color _primaryBlue = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text(
          'AI 톡비서 사용 가이드',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 필수 설정
              _buildSection(
                context,
                title: '1. 필수 설정',
                subtitle: '작동을 위해 필수!',
                icon: Icons.settings,
                iconColor: Colors.orange,
                items: [
                  _buildBulletItem(
                    '카카오톡 알림 켜기: 요약이나 삭제된 메시지 확인을 원하는 채팅방의 알림을 켜주세요.',
                  ),
                  _buildBulletItem(
                    '카톡 알림 형식: 카카오톡 설정 → 알림 → \'이름+메시지\' 형식으로 설정해야 내용을 인식합니다.',
                  ),
                  _buildBulletItem(
                    '앱 권한 허용: 앱 설정에서 \'알림 접근 허용\' 및 **\'배터리 사용량 최적화 중지\'**를 반드시 설정해 주세요.',
                    isImportant: true,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. 보안 및 개인정보 보호
              _buildSection(
                context,
                title: '2. 🔒 보안 및 개인정보 보호',
                subtitle: '안심하고 사용하세요!',
                icon: Icons.lock,
                iconColor: Colors.green,
                items: [
                  _buildBulletItem(
                    '로컬 저장 방식: 모든 대화 내용은 서버가 아닌 사용자의 휴대폰(로컬)에만 저장되어 안전합니다.',
                  ),
                  _buildBulletItem(
                    '철저한 개인정보 마스킹: 요약 기능 사용 시, 대화에 포함된 주민등록번호, 핸드폰 번호, 이메일 등 주요 개인정보는 자동으로 마스킹(별표 처리) 후 전송됩니다.',
                  ),
                  _buildBulletItem(
                    '데이터 보안: 모든 통신은 HTTPS 암호화를 거치며, 서버에는 어떠한 대화 로그도 남지 않습니다.',
                  ),
                  _buildBulletItem(
                    '익명성 보장: 별도의 로그인을 하지 않으므로 대화 내용이 누구의 것인지 특정할 수 없어 익명성이 철저히 보장됩니다.',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 3. 채팅방 목록 관리
              _buildSection(
                context,
                title: '3. 채팅방 목록 관리',
                subtitle: '목록에서 길게 누르기',
                icon: Icons.list,
                iconColor: _primaryBlue,
                items: [
                  _buildBulletItem(
                    'AI 요약 기능 켜기/끄기: 켜두면 안 읽은 메시지가 5개 이상일 때 입장 시 자동으로 요약 영역이 선택됩니다.',
                  ),
                  _buildBulletItem(
                    'AI 자동 요약 설정 (Basic 전용): 설정한 메시지 개수가 쌓이면 자동으로 요약하고 푸시 알림을 보냅니다.',
                  ),
                  _buildBulletItem(
                    '상단 고정 / 알림 끄기: 자주 쓰는 방은 고정하고, 시끄러운 방은 앱 내에서 알림만 끌 수 있습니다.',
                  ),
                  _buildBulletItem(
                    '채팅방 차단 / 삭제: 차단 시 메시지 저장을 중단하며, 삭제 시 모든 데이터(사진, 요약 등)가 소멸됩니다.',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 4. 대화방 내부 주요 기능
              _buildSection(
                context,
                title: '4. 대화방 내부 주요 기능',
                icon: Icons.chat_bubble,
                iconColor: Colors.purple,
                items: [
                  _buildBulletItem(
                    '대화 요약: 오른쪽 상단의 요약하기 아이콘을 클릭하여 즉시 요약할 수 있습니다.',
                  ),
                  _buildBulletItem(
                    '검색 & 복사: 사용자/시간/키워드별 검색이 가능하며, 메시지를 꾹 눌러 복사할 수 있습니다.',
                  ),
                  _buildBulletItem(
                    '삭제된 메시지 확인: 상대방이 삭제한 메시지도 그대로 확인할 수 있습니다.',
                  ),
                  _buildBulletItem(
                    '주의사항: 동영상 및 여러 장 묶음 사진은 앱 내에 저장되지 않습니다.',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 5. 상세 요약 활용법
              _buildSection(
                context,
                title: '5. 상세 요약 활용법',
                icon: Icons.auto_awesome,
                iconColor: Colors.amber,
                items: [
                  _buildBulletItem(
                    '수동 요약: 구간 직접 선택, 숫자 입력, 혹은 말풍선 터치로 블록을 잡아 요약할 수 있습니다.',
                  ),
                  _buildBulletItem(
                    '요약 히스토리: [앱 설정 → 요약 관리 → 요약 히스토리]에서 과거 기록 확인 및 삭제가 가능합니다.',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 6. 요금제 및 사용량 확인
              _buildSection(
                context,
                title: '6. 요금제 및 사용량 확인',
                subtitle: '[앱 설정 → 요약 관리]에서 실시간 사용량을 확인하세요.',
                icon: Icons.payment,
                iconColor: Colors.teal,
                items: [
                  _buildPlanTable(context),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    required List<Widget> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildBulletItem(String text, {bool isImportant = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 12),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isImportant ? Colors.orange : _primaryBlue,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
                children: _parseText(text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _parseText(String text) {
    final spans = <TextSpan>[];
    final parts = text.split('**');
    
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        // 일반 텍스트
        spans.add(TextSpan(text: parts[i]));
      } else {
        // 강조 텍스트 (**로 감싼 부분)
        spans.add(TextSpan(
          text: parts[i],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ));
      }
    }
    
    return spans;
  }

  Widget _buildPlanTable(BuildContext context) {
    return Column(
      children: [
        // 무료 플랜 카드
        _buildPlanCard(
          planName: '무료 플랜',
          planColor: Colors.blue,
          items: [
            _buildPlanItem('요약 횟수', '일 1회 (매일 자정 초기화)'),
            _buildPlanItem('1회 요약 한도', '5~50개'),
            _buildPlanItem('주요 특징', '기본 요약 기능'),
          ],
        ),
        const SizedBox(height: 12),
        // Basic 플랜 카드
        _buildPlanCard(
          planName: '베이직 플랜',
          planColor: Colors.purple,
          items: [
            _buildPlanItem('요약 횟수', '150회 (결제일 기준 초기화)'),
            _buildPlanItem('1회 요약 한도', '5~200개'),
            _buildPlanItem('주요 특징', '자동 요약, 푸시 알림 제공, 타 메신저 추가 설정 가능'),
          ],
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String planName,
    required Color planColor,
    required List<Widget> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: planColor.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: planColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: planColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                planName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: planColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildPlanItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1A1A1A),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
