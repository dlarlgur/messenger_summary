import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// 마크다운 텍스트 렌더링 위젯
/// \n 문자를 실제 줄바꿈으로 표시하고, 숫자 리스트와 불렛포인트를 지원
class MarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const MarkdownText({
    Key? key,
    required this.text,
    this.style,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // \n 문자를 실제 줄바꿈으로 변환
    final processedText = text.replaceAll('\\n', '\n');

    return MarkdownBody(
      data: processedText,
      styleSheet: MarkdownStyleSheet(
        p: style ?? const TextStyle(fontSize: 16),
        h1: style?.copyWith(fontSize: 24, fontWeight: FontWeight.bold) ??
            const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        h2: style?.copyWith(fontSize: 20, fontWeight: FontWeight.bold) ??
            const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        h3: style?.copyWith(fontSize: 18, fontWeight: FontWeight.bold) ??
            const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        listBullet: style ?? const TextStyle(fontSize: 16),
        listIndent: 24.0,
        blockquote: style?.copyWith(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ) ??
            const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      ),
      selectable: true,
    );
  }
}
