import 'package:cached_network_image/cached_network_image.dart';
import 'package:dksw_app_core/dksw_app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

import 'subscription_screen.dart';
import '../l10n/app_localizations.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late Future<List<EventItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = DkswCore.fetchEvents();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).events_appBarTitle)),
      body: FutureBuilder<List<EventItem>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return _empty(
              icon: Icons.celebration_outlined,
              title: AppLocalizations.of(context).events_emptyTitle,
              description: AppLocalizations.of(context).events_emptyDescription,
              isDark: isDark,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              final fresh = await DkswCore.fetchEvents();
              if (mounted) setState(() => _future = Future.value(fresh));
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) =>
                  _EventCard(event: items[i], isDark: isDark),
            ),
          );
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventItem event;
  final bool isDark;
  const _EventCard({required this.event, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF141823) : Colors.white;
    final border =
        isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E8F0);
    final muted = isDark ? Colors.white54 : const Color(0xFF9CA3AF);
    final primary = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondary = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final imageUrl = event.imageUrl;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: DkswCore.resolveAssetUrl(imageUrl),
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: muted.withValues(alpha: 0.1)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                  if (event.summary != null && event.summary!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, color: secondary, height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(_periodLabel(event),
                      style: TextStyle(fontSize: 11.5, color: muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(EventItem e) {
    if (e.startAt == null && e.endAt == null) return '상시 진행';
    String fmt(DateTime d) {
      final l = d.toLocal();
      return '${l.year}.${l.month.toString().padLeft(2, '0')}.${l.day.toString().padLeft(2, '0')}';
    }

    if (e.startAt != null && e.endAt != null) {
      return '${fmt(e.startAt!)} ~ ${fmt(e.endAt!)}';
    }
    if (e.endAt != null) return '${fmt(e.endAt!)} 까지';
    return '${fmt(e.startAt!)} 부터';
  }
}

class EventDetailScreen extends StatelessWidget {
  final EventItem event;
  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondary = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final imageUrl = event.imageUrl;
    // 본문의 링크(<a>)는 네이티브 CTA 버튼으로 분리해 예쁘게 렌더.
    final split = _splitEventCtas(event.bodyHtml);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).events_appBarTitle)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 상세에서는 대표 이미지를 크롭하지 않고 원본 비율 전체(가로맞춤)로 표시.
          // (flutter_html 은 이미지 확장 미설정이라 본문 <img> 를 렌더하지 않으므로
          //  이미지는 대표 이미지 슬롯으로만 노출한다.)
          if (imageUrl != null && imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: DkswCore.resolveAssetUrl(imageUrl),
              fit: BoxFit.fitWidth,
              width: double.infinity,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: primary,
                  ),
                ),
                if (event.summary != null && event.summary!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    event.summary!,
                    style: TextStyle(
                      fontSize: 14,
                      color: secondary,
                      height: 1.55,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (split.body.replaceAll(RegExp(r'<[^>]*>|&nbsp;|\s'), '').isNotEmpty)
                  Html(
                    data: split.body,
                    onLinkTap: (url, _, __) async {
                      if (url != null) await _openEventLink(context, url);
                    },
                  ),
                ...split.ctas.map((c) => _eventCtaButton(context, c)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _empty({
  required IconData icon,
  required String title,
  required String description,
  required bool isDark,
}) {
  final muted = isDark ? Colors.white54 : const Color(0xFF9CA3AF);
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: muted),
        const SizedBox(height: 14),
        Text(title,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: muted)),
        const SizedBox(height: 6),
        Text(description, style: TextStyle(fontSize: 13, color: muted)),
      ],
    ),
  );
}

// 본문 HTML 에서 링크(<a href>)를 추출해 네이티브 CTA 버튼으로 분리.
// 반환: (링크 제거된 본문, [(href,label)...])
({String body, List<({String href, String label})> ctas}) _splitEventCtas(String html) {
  final ctas = <({String href, String label})>[];
  final re = RegExp(r'<a\b[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
      caseSensitive: false, dotAll: true);
  final body = html.replaceAllMapped(re, (m) {
    final href = (m.group(1) ?? '').trim();
    final label = _cleanLabel(m.group(2) ?? '');
    if (href.isNotEmpty) {
      ctas.add((href: href, label: label.isEmpty ? '바로가기' : label));
    }
    return '';
  });
  return (body: body, ctas: ctas);
}

// 버튼 라벨 정리: 태그 제거 + 화살표(→ / &rarr;) 제거 + 기본 엔티티 디코드.
String _cleanLabel(String raw) {
  return raw
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&rarr;', '')
      .replaceAll('&#8594;', '')
      .replaceAll('→', '')
      .replaceAll('&amp;', '&')
      .replaceAll('&nbsp;', ' ')
      .trim();
}

// CTA 링크 열기: app://subscription → 구독 화면(내부), 그 외(http 등) → 외부 브라우저.
// 광고 CTA 와 동일 규칙: http(s) = 외부 브라우저, 그 외(식별자 /subscribe 등) = 앱 내부 화면.
Future<void> _openEventLink(BuildContext context, String url) async {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    return;
  }
  // 내부 식별자(/subscribe 등) → 앱 화면. http 가 아니면 절대 launchUrl 로 보내지 않는다(검정화면 방지).
  Widget target;
  switch (url) {
    case '/subscribe':
      target = const SubscriptionScreen();
      break;
    default:
      target = const SubscriptionScreen(); // 알 수 없는 식별자는 구독으로 (광고와 동일)
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => target));
}

// 예쁜 네이티브 CTA 버튼 (둥근 초록, 풀폭).
Widget _eventCtaButton(BuildContext context, ({String href, String label}) cta) {
  return Padding(
    padding: const EdgeInsets.only(top: 10),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () { _openEventLink(context, cta.href); },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          cta.label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}
