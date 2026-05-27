import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 헤더 좌측에 들어가는 작은 사각 로고.
///
/// 핸드오프 §8.1 — 26px 정사각, 라디우스 변의 22.5%(약 6px),
/// accent 배경 + 흰 마크. 마크는 chat_llm 기존 자산 [assets/ai_talk.png].
/// 로고가 바뀌면 이 위젯 한 곳만 교체하면 됨.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = AppTokens.appLogoSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTokens.accent,
        borderRadius: BorderRadius.circular(size * 0.225),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Padding(
        // ai_talk.png 자체에 약간의 여백이 있어 padding 살짝
        padding: EdgeInsets.all(2),
        child: Image(
          image: AssetImage('assets/ai_talk.png'),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
