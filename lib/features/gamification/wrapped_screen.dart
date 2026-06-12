import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/share_helpers.dart';
import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../shared/wall_ui.dart';

/// "Wall Wrapped" — a brand-styled recap card the user can post to WhatsApp
/// status / Instagram. Shareable artifacts are the organic acquisition loop:
/// every share is an impression with a link back to the app.
class WrappedScreen extends ConsumerStatefulWidget {
  const WrappedScreen({super.key});
  @override
  ConsumerState<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends ConsumerState<WrappedScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share({required bool whatsApp}) async {
    setState(() => _sharing = true);
    try {
      final text = 'My Wall, wrapped 🧱 — see what people who know me say. '
          'Claim your own wall: ${K.webBase}';
      if (whatsApp) {
        // Image + WhatsApp deep link can't combine reliably; share the image
        // through the sheet (WhatsApp is in it) for the richer post.
        await shareWidgetAsImage(_cardKey,
            filename: 'wall-wrapped.png', text: text);
      } else {
        await shareWidgetAsImage(_cardKey,
            filename: 'wall-wrapped.png', text: text);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    final wall = ref.watch(myWallProvider).value;
    final gam = ref.watch(gamificationProvider).value;
    final feedback = ref.watch(receivedFeedbackProvider).value ?? const [];

    final topTags = (wall?.tagCounts.entries.toList() ?? [])
      ..sort((a, b) => b.value.compareTo(a.value));
    final topDims = (wall?.dimensionAverages.entries
            .where((e) => e.value > 0)
            .toList() ??
        [])
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('Wall Wrapped')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ── The shareable card (captured as PNG) ──
          RepaintBoundary(
            key: _cardKey,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.ink950, AppTheme.ink850],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: AppTheme.clay.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BrickMark(size: 34, animate: false),
                      const SizedBox(width: 10),
                      Text('THE WALL · WRAPPED',
                          style: AppTheme.body(
                              size: 11,
                              weight: FontWeight.w800,
                              color: AppTheme.clay,
                              letterSpacing: 1.6)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    user?.displayName.split(' ').first ?? 'Me',
                    style: AppTheme.display(size: 32),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${feedback.length} bricks · ${wall?.opennessLabel ?? "New"} · '
                    '${gam?.streak.current ?? 0}-day streak',
                    style:
                        AppTheme.body(size: 13, color: AppTheme.ink300),
                  ),
                  const SizedBox(height: 22),
                  if (topTags.isNotEmpty) ...[
                    Text('WHAT PEOPLE SAY',
                        style: AppTheme.body(
                            size: 10.5,
                            weight: FontWeight.w800,
                            color: AppTheme.ink400,
                            letterSpacing: 1.4)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: topTags
                          .take(5)
                          .map((e) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: AppTheme.clay),
                                  borderRadius:
                                      BorderRadius.circular(100),
                                ),
                                child: Text(e.key,
                                    style: AppTheme.body(
                                        size: 12.5,
                                        weight: FontWeight.w600,
                                        color: AppTheme.clay)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (topDims.isNotEmpty) ...[
                    Text('STRONGEST DIMENSION',
                        style: AppTheme.body(
                            size: 10.5,
                            weight: FontWeight.w800,
                            color: AppTheme.ink400,
                            letterSpacing: 1.4)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          FeedbackDimension.byKey(topDims.first.key).label,
                          style: AppTheme.display(
                              size: 20, color: AppTheme.sage),
                        ),
                        const SizedBox(width: 10),
                        ScorePill(topDims.first.value),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: AppTheme.ink700,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'the-wall-app-260609.web.app',
                    style: AppTheme.body(
                        size: 11.5, color: AppTheme.ink400),
                  ),
                ],
              ),
            ),
          ).entrance(1),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: _sharing ? null : () => _share(whatsApp: true),
            icon: const Icon(Icons.ios_share_rounded, size: 19),
            label: Text(_sharing ? 'Preparing…' : 'Share my Wrapped'),
          ).entrance(2),
          const SizedBox(height: 10),
          Text(
            'Shares only what you choose: your top tags, openness and streak. '
            'Never individual feedback.',
            textAlign: TextAlign.center,
            style: AppTheme.body(size: 11.5, color: AppTheme.ink400),
          ).entrance(3),
        ],
      ),
    );
  }
}
