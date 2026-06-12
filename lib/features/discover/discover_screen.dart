import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../shared/wall_ui.dart';
import '../circles/circles_screen.dart';

/// Discover: circles first (your people), then opt-in leaderboards ranking
/// CONTRIBUTION, GROWTH and OPENNESS. Never "highest-rated people"
/// (avoids comparison harm + defamation). Only opted-in users appear.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(firestoreProvider);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: ScreenHeader(
                  kicker: 'Community',
                  title: 'Discover',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  'We never rank people by their ratings — only by what they give.',
                  style: AppTheme.body(
                      size: 12.5, color: AppTheme.ink400, height: 1.4),
                ).entrance(1),
              ),
              const SizedBox(height: 10),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: EdgeInsets.symmetric(horizontal: 12),
                tabs: [
                  Tab(text: 'Circles'),
                  Tab(text: 'Contribution'),
                  Tab(text: 'Growth'),
                  Tab(text: 'Openness'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    const CirclesTab(),
                    _Board(
                      stream: db
                          .collection('gamification')
                          .where('leaderboardOptIn', isEqualTo: true)
                          .orderBy('contributionPoints', descending: true)
                          .limit(50)
                          .snapshots(),
                      metric: 'contributionPoints',
                      suffix: ' pts',
                      icon: Icons.volunteer_activism_outlined,
                    ),
                    _Board(
                      stream: db
                          .collection('gamification')
                          .where('leaderboardOptIn', isEqualTo: true)
                          .orderBy('growthScore', descending: true)
                          .limit(50)
                          .snapshots(),
                      metric: 'growthScore',
                      suffix: '',
                      icon: Icons.trending_up_rounded,
                    ),
                    _Board(
                      stream: db
                          .collection('gamification')
                          .where('leaderboardOptIn', isEqualTo: true)
                          .orderBy('opennessScore', descending: true)
                          .limit(50)
                          .snapshots(),
                      metric: 'opennessScore',
                      suffix: '',
                      icon: Icons.visibility_outlined,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  final Stream stream;
  final String metric;
  final String suffix;
  final IconData icon;
  const _Board({
    required this.stream,
    required this.metric,
    required this.suffix,
    required this.icon,
  });

  static const _rankColors = [AppTheme.gold, Color(0xFFB8BCC8), Color(0xFFC2845A)];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) return const WallLoader();
        final docs = (snap.data as dynamic).docs as List;
        if (docs.isEmpty) {
          return EmptyState(
            icon: icon,
            title: 'Quiet for now',
            message:
                'Leaderboards fill up as the community grows.\nEnable “Appear on leaderboards” in Settings to join.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final raw = d[metric];
            final value = raw is double
                ? raw.toStringAsFixed(
                    raw == raw.truncateToDouble() ? 0 : 1)
                : (raw as num?)?.toString() ?? '0';
            final isTop3 = i < 3;
            final rankColor =
                isTop3 ? _rankColors[i] : AppTheme.ink400;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WallCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 13),
                borderColor: isTop3
                    ? rankColor.withValues(alpha: 0.4)
                    : null,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: rankColor.withValues(
                            alpha: isTop3 ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(11),
                        border: isTop3
                            ? Border.all(
                                color: rankColor.withValues(alpha: 0.45))
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: AppTheme.display(
                              size: 15, color: rankColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        d['displayName'] as String? ?? 'Member',
                        style: AppTheme.body(
                            size: 14.5,
                            weight: FontWeight.w600,
                            color: AppTheme.paper),
                      ),
                    ),
                    Text(
                      '$value$suffix',
                      style: AppTheme.display(
                          size: 15, color: AppTheme.clay),
                    ),
                  ],
                ),
              ).entrance(i.clamp(0, 12)),
            );
          },
        );
      },
    );
  }
}
