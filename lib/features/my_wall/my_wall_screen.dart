import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/badge_definitions.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../shared/wall_ui.dart';
import '../gamification/badges_screen.dart';
import '../gamification/wrapped_screen.dart';
import '../feedback/request_feedback_screen.dart';
import '../premium/premium_screen.dart';
import '../self_assessment/self_assessment_screen.dart';

class MyWallScreen extends ConsumerWidget {
  const MyWallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).value;
    final wall = ref.watch(myWallProvider).value;
    final feedbackAsync = ref.watch(receivedFeedbackProvider);
    final gam = ref.watch(gamificationProvider).value;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: feedbackAsync.when(
          loading: () => const WallLoader(),
          error: (e, _) => Center(
            child: Text('Error: $e', style: AppTheme.body()),
          ),
          data: (feedback) {
            final gateCleared = user?.gateCleared ?? false;
            final isPremium = user?.isPremium ?? false;
            final given = user?.giveToGetCount ?? 0;

            // Progressive reveal: 1 give = 1 unlock, oldest first. The full
            // gate (aggregates + other walls) still opens at the threshold.
            final byOldest = [...feedback]
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            final unlockedIds =
                byOldest.take(given).map((f) => f.id).toSet();

            var i = 0;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
              children: [
                _Header(
                  name: user?.displayName ?? '',
                  count: feedback.length,
                  opennessLabel: wall?.opennessLabel ?? 'New',
                ),
                const SizedBox(height: 20),
                if (!gateCleared) ...[
                  _GateProgressCard(
                    lockedCount:
                        feedback.length - unlockedIds.length,
                    given: given,
                    onAccessData: () =>
                        ref.read(repoProvider).requestDataAccess(),
                  ).entrance(++i),
                  const SizedBox(height: 14),
                ],
                if (gateCleared && wall != null && wall.meetsMinN) ...[
                  _DimensionSummary(wall: wall).entrance(++i),
                  const SizedBox(height: 14),
                ],
                if (user != null && wall != null && wall.meetsMinN) ...[
                  _GapCard(user: user, wall: wall).entrance(++i),
                  const SizedBox(height: 14),
                ] else if (user != null && user.selfScores.isEmpty) ...[
                  _SelfAssessCta(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const SelfAssessmentScreen())),
                  ).entrance(++i),
                  const SizedBox(height: 14),
                ],
                if (isPremium && gateCleared && wall != null && wall.meetsMinN) ...[
                  _CoachingCard(wall: wall).entrance(++i),
                  const SizedBox(height: 14),
                  _CohortCard(wall: wall).entrance(++i),
                  const SizedBox(height: 14),
                ],
                if (!isPremium) ...[
                  _PremiumBanner(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PremiumScreen())),
                  ).entrance(++i),
                  const SizedBox(height: 14),
                ],
                _BadgesMiniSection(
                  badges: gam?.badges ?? [],
                  onViewAll: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BadgesScreen())),
                ).entrance(++i),
                const SizedBox(height: 14),
                // Campaigns are FREE — the ask-link is the core loop.
                WallCard(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const RequestFeedbackScreen())),
                  child: Row(
                    children: [
                      const Icon(Icons.campaign_outlined,
                          color: AppTheme.clay),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ask for feedback',
                                style: AppTheme.body(
                                    size: 15,
                                    weight: FontWeight.w600,
                                    color: AppTheme.paper)),
                            Text(
                                'Share a link — anyone on The Wall can answer.',
                                style: AppTheme.body(
                                    size: 12, color: AppTheme.ink400)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded,
                          color: AppTheme.ink400, size: 20),
                    ],
                  ),
                ).entrance(++i),
                if (feedback.length >= K.minReviewsForAggregate) ...[
                  const SizedBox(height: 14),
                  WallCard(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const WrappedScreen())),
                    borderColor: AppTheme.gold.withValues(alpha: 0.3),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            color: AppTheme.goldSoft),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('Your Wall, wrapped — share it',
                              style: AppTheme.body(
                                  size: 15,
                                  weight: FontWeight.w600,
                                  color: AppTheme.paper)),
                        ),
                        const Icon(Icons.arrow_forward_rounded,
                            color: AppTheme.ink400, size: 20),
                      ],
                    ),
                  ).entrance(++i),
                ],
                const SizedBox(height: 26),
                SectionLabel('Bricks on your wall · ${feedback.length}')
                    .entrance(++i),
                if (feedback.isEmpty)
                  const EmptyState(
                    icon: Icons.grid_view_rounded,
                    title: 'No bricks yet',
                    message:
                        'Every piece of feedback is a brick on your wall. '
                        'Invite people you trust to lay the first one.',
                  ).entrance(++i)
                else
                  ...feedback.map((f) {
                    final locked =
                        !gateCleared && !unlockedIds.contains(f.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FeedbackCard(
                        f: f,
                        locked: locked,
                        onToggle: (v) => ref
                            .read(repoProvider)
                            .setDisclosure(f.id, v),
                        onDispute: () => _dispute(context, ref, f.id),
                      ).entrance(++i),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  void _dispute(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dispute this feedback?'),
        content: const Text(
            'It will be hidden from your public aggregate and reviewed '
            'by our moderation team within 7 days.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(120, 48),
              backgroundColor: AppTheme.rose,
            ),
            onPressed: () {
              ref.read(repoProvider).fileDispute(id, 'inaccurate');
              Navigator.pop(context);
            },
            child: const Text('Dispute'),
          ),
        ],
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String name;
  final int count;
  final String opennessLabel;
  const _Header({
    required this.name,
    required this.count,
    required this.opennessLabel,
  });

  @override
  Widget build(BuildContext context) {
    final first = name.trim().isEmpty ? 'there' : name.trim().split(' ').first;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR WALL',
                  style: AppTheme.body(
                    size: 11.5,
                    weight: FontWeight.w700,
                    color: AppTheme.clay,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Hi, $first', style: AppTheme.display(size: 30)),
                const SizedBox(height: 4),
                Text(
                  count == 0
                      ? 'Your wall is waiting for its first brick.'
                      : '$count ${count == 1 ? "brick" : "bricks"} laid by people who know you.',
                  style: AppTheme.body(size: 13.5, color: AppTheme.ink400),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const BrickMark(size: 40),
              const SizedBox(height: 8),
              _OpennessBadge(label: opennessLabel),
            ],
          ),
        ],
      ),
    ).entrance(0);
  }
}

// ─── Gate progress (progressive reveal) ──────────────────────────────────────

class _GateProgressCard extends StatelessWidget {
  final int lockedCount;
  final int given;
  final VoidCallback onAccessData;
  const _GateProgressCard({
    required this.lockedCount,
    required this.given,
    required this.onAccessData,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (K.giveToGetThreshold - given).clamp(0, 999);
    return WallCard(
      padding: const EdgeInsets.all(24),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.ink850, AppTheme.ink800],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.clay.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    const Icon(Icons.lock_open_outlined, color: AppTheme.clay),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  lockedCount == 0
                      ? 'Every brick unlocked'
                      : '$lockedCount ${lockedCount == 1 ? "brick is" : "bricks are"} still sealed',
                  style: AppTheme.display(size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'EACH BRICK YOU LAY UNLOCKS ONE OF YOURS',
            style: AppTheme.body(
              size: 11,
              weight: FontWeight.w700,
              color: AppTheme.ink400,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          BrickProgress(
              filled: given.clamp(0, K.giveToGetThreshold),
              total: K.giveToGetThreshold),
          const SizedBox(height: 12),
          Text(
            remaining == 0
                ? 'Full wall open — averages and other walls unlocked.'
                : 'Give feedback to $remaining more ${remaining == 1 ? "person" : "people"} to open your averages and browse walls. Honest in, honest out.',
            style: AppTheme.body(
                size: 13.5, color: AppTheme.ink300, height: 1.5),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onAccessData,
            icon: const Icon(Icons.shield_outlined, size: 18),
            label: const Text('Access my data now (privacy right)'),
          ),
        ],
      ),
    );
  }
}

// ─── Dimension summary ────────────────────────────────────────────────────────

class _DimensionSummary extends StatelessWidget {
  final Wall wall;
  const _DimensionSummary({required this.wall});

  @override
  Widget build(BuildContext context) {
    final entries = wall.dimensionAverages.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return WallCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How people see you', style: AppTheme.display(size: 18)),
          const SizedBox(height: 16),
          ...entries.map((e) {
            final d = FeedbackDimension.byKey(e.key);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 116,
                    child: Text(d.label,
                        style: AppTheme.body(
                            size: 13.5,
                            weight: FontWeight.w600,
                            color: AppTheme.ink200)),
                  ),
                  Expanded(
                      child: WallProgress(value: e.value / 5)),
                  const SizedBox(width: 10),
                  ScorePill(e.value),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── You vs how others see you (free — the Johari hook) ─────────────────────

class _GapCard extends StatelessWidget {
  final AppUser user;
  final Wall wall;
  const _GapCard({required this.user, required this.wall});

  @override
  Widget build(BuildContext context) {
    final shared = wall.dimensionAverages.entries
        .where((e) => user.selfScores.containsKey(e.key) && e.value > 0)
        .toList();
    if (shared.isEmpty) return const SizedBox.shrink();
    return WallCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded,
                  color: AppTheme.sage, size: 20),
              const SizedBox(width: 8),
              Text('You vs how others see you',
                  style: AppTheme.display(size: 17)),
            ],
          ),
          const SizedBox(height: 14),
          ...shared.map((e) {
            final d = FeedbackDimension.byKey(e.key);
            final self = (user.selfScores[e.key] ?? 0).toDouble();
            final others = e.value;
            final delta = others - self;
            final deltaLabel = delta.abs() < 0.3
                ? 'aligned'
                : delta > 0
                    ? '+${delta.toStringAsFixed(1)} kinder than you think'
                    : '${delta.toStringAsFixed(1)} vs your view';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(d.label,
                          style: AppTheme.body(
                              size: 13,
                              weight: FontWeight.w600,
                              color: AppTheme.ink200)),
                      const Spacer(),
                      Text(deltaLabel,
                          style: AppTheme.body(
                              size: 11.5,
                              color: delta.abs() < 0.3
                                  ? AppTheme.ink400
                                  : (delta > 0
                                      ? AppTheme.sage
                                      : AppTheme.gold))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  WallProgress(value: self / 5, color: AppTheme.ink600),
                  const SizedBox(height: 4),
                  WallProgress(value: others / 5),
                ],
              ),
            );
          }),
          Row(
            children: [
              _LegendDot(color: AppTheme.ink600, label: 'You'),
              const SizedBox(width: 14),
              _LegendDot(color: AppTheme.clay, label: 'Others'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: AppTheme.body(size: 11.5, color: AppTheme.ink400)),
        ],
      );
}

class _SelfAssessCta extends StatelessWidget {
  final VoidCallback onTap;
  const _SelfAssessCta({required this.onTap});

  @override
  Widget build(BuildContext context) => WallCard(
        onTap: onTap,
        child: Row(
          children: [
            const Icon(Icons.psychology_outlined, color: AppTheme.sage),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rate yourself (2 min)',
                      style: AppTheme.body(
                          size: 15,
                          weight: FontWeight.w600,
                          color: AppTheme.paper)),
                  Text(
                      'Then see how your self-image compares with what others say.',
                      style: AppTheme.body(
                          size: 12, color: AppTheme.ink400)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                color: AppTheme.ink400, size: 20),
          ],
        ),
      );
}

// ─── Coaching prompts (Premium) ───────────────────────────────────────────────

const _kCoachingTips = <String, String>{
  'punctuality':
      'Set calendar reminders 15 minutes before events so you are always on time.',
  'professionalism':
      'Practise active listening — acknowledge what someone said before responding.',
  'communication':
      'Summarise key points at the end of important conversations to close the loop.',
  'reliability':
      'Use a simple task manager to track every commitment, no matter how small.',
  'listening':
      'In your next three conversations, ask one follow-up question before sharing your view.',
  'shows_up':
      'Reply to plans within a day — even a "can\'t make it" builds trust.',
  'patience':
      'When you feel the urge to jump in, count three breaths first.',
  'fun': 'Suggest the next plan yourself — people remember initiators.',
};

class _CoachingCard extends StatelessWidget {
  final Wall wall;
  const _CoachingCard({required this.wall});

  @override
  Widget build(BuildContext context) {
    final tips = wall.dimensionAverages.entries
        .where((e) => e.value > 0 && e.value < 3.5)
        .map((e) => _kCoachingTips[e.key])
        .whereType<String>()
        .toList();
    if (tips.isEmpty) return const SizedBox.shrink();
    return WallCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  color: AppTheme.gold, size: 20),
              const SizedBox(width: 8),
              Text('Coaching tips', style: AppTheme.display(size: 17)),
              const Spacer(),
              const _PremiumTag(),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.gold,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(t,
                          style: AppTheme.body(
                              size: 13.5,
                              color: AppTheme.ink300,
                              height: 1.5)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Cohort comparison (Premium) ─────────────────────────────────────────────

class _CohortCard extends StatelessWidget {
  final Wall wall;
  const _CohortCard({required this.wall});

  String _label(double score) {
    if (score >= 4.5) return 'Top 10%';
    if (score >= 4.0) return 'Top 25%';
    if (score >= 3.5) return 'Top 50%';
    return 'Climbing';
  }

  Color _color(double score) =>
      score >= 4.0 ? AppTheme.sage : (score >= 3.5 ? AppTheme.gold : AppTheme.ink400);

  @override
  Widget build(BuildContext context) {
    return WallCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_outline,
                  color: AppTheme.clay, size: 20),
              const SizedBox(width: 8),
              Text('Among your peers', style: AppTheme.display(size: 17)),
              const Spacer(),
              const _PremiumTag(),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: wall.dimensionAverages.entries.map((e) {
              final v = e.value;
              if (v == 0) return const SizedBox.shrink();
              final d = FeedbackDimension.byKey(e.key);
              final c = _color(v);
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: c.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.label,
                        style: AppTheme.body(
                            size: 11.5, color: AppTheme.ink300)),
                    const SizedBox(height: 2),
                    Text(_label(v),
                        style: AppTheme.body(
                            size: 14, weight: FontWeight.w800, color: c)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PremiumTag extends StatelessWidget {
  const _PremiumTag();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(7),
          border:
              Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
        ),
        child: Text(
          'PREMIUM',
          style: AppTheme.body(
            size: 9.5,
            weight: FontWeight.w800,
            color: AppTheme.goldSoft,
            letterSpacing: 1,
          ),
        ),
      );
}

// ─── Premium upsell banner ────────────────────────────────────────────────────

class _PremiumBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _PremiumBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return WallCard(
      onTap: onTap,
      borderColor: AppTheme.gold.withValues(alpha: 0.35),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.gold.withValues(alpha: 0.10),
          AppTheme.ink850,
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.workspace_premium_outlined,
                color: AppTheme.goldSoft, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Go deeper with Premium',
                    style: AppTheme.body(
                        size: 15,
                        weight: FontWeight.w700,
                        color: AppTheme.paper)),
                const SizedBox(height: 2),
                Text('AI summary, coaching, peer comparison, trends.',
                    style: AppTheme.body(
                        size: 12.5, color: AppTheme.ink400)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded,
              color: AppTheme.goldSoft, size: 20),
        ],
      ),
    );
  }
}

// ─── Badges mini section ──────────────────────────────────────────────────────

class _BadgesMiniSection extends StatelessWidget {
  final List<BadgeEarned> badges;
  final VoidCallback onViewAll;
  const _BadgesMiniSection({required this.badges, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final earnedIds = badges.map((b) => b.id).toSet();
    final shown =
        kBadges.where((d) => earnedIds.contains(d.id)).take(4).toList();
    return WallCard(
      onTap: onViewAll,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Badges', style: AppTheme.display(size: 17)),
              const Spacer(),
              Text(
                '${earnedIds.length}/${kBadges.length}',
                style: AppTheme.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppTheme.clay),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded,
                  color: AppTheme.clay, size: 16),
            ],
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            Text(
              'No badges yet — give feedback to start earning.',
              style: AppTheme.body(size: 13, color: AppTheme.ink400),
            )
          else
            Row(
              children: shown
                  .asMap()
                  .entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Column(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: e.value.color
                                    .withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: e.value.color
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Icon(e.value.icon,
                                  color: e.value.color, size: 26),
                            )
                                .animate()
                                .scale(
                                  begin: const Offset(0.5, 0.5),
                                  end: const Offset(1, 1),
                                  delay: Duration(
                                      milliseconds: 100 * e.key + 300),
                                  duration: WallMotion.slow,
                                  curve: WallMotion.spring,
                                )
                                .fadeIn(
                                    delay: Duration(
                                        milliseconds: 100 * e.key + 300)),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 56,
                              child: Text(
                                e.value.label,
                                style: AppTheme.body(
                                    size: 9.5, color: AppTheme.ink300),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ─── Feedback card (with locked tease state) ─────────────────────────────────

class _FeedbackCard extends StatelessWidget {
  final ReceivedFeedback f;
  final bool locked;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDispute;
  const _FeedbackCard({
    required this.f,
    this.locked = false,
    required this.onToggle,
    required this.onDispute,
  });

  double get _avg => f.dimensions.isEmpty
      ? 0
      : f.dimensions.values.reduce((a, b) => a + b) / f.dimensions.length;

  @override
  Widget build(BuildContext context) {
    final underReview = f.status == 'under_review';

    if (locked) {
      // Blurred tease with real metadata — the motivator to give one more.
      return WallCard(
        padding: const EdgeInsets.all(18),
        borderColor: AppTheme.gold.withValues(alpha: 0.25),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lock_outline,
                  color: AppTheme.goldSoft, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${f.contextTag ?? "Someone"} · ${f.tags.length} tag${f.tags.length == 1 ? "" : "s"}${f.comment != null ? " · a note" : ""}',
                    style: AppTheme.body(
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: AppTheme.paper),
                  ),
                  const SizedBox(height: 8),
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Row(
                      children: List.generate(
                        5,
                        (i) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: i < _avg.round()
                                  ? AppTheme.gold
                                  : AppTheme.ink700,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Give one piece of feedback to unlock this brick.',
                    style: AppTheme.body(
                        size: 11.5, color: AppTheme.ink400),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return WallCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.clay.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    (f.authorName ?? 'A')[0].toUpperCase(),
                    style: AppTheme.display(
                        size: 16, color: AppTheme.clay),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.authorName ?? 'Anonymous',
                        style: AppTheme.body(
                            size: 14.5,
                            weight: FontWeight.w700,
                            color: AppTheme.paper)),
                    if (f.contextTag != null)
                      Text(f.contextTag!,
                          style: AppTheme.body(
                              size: 11.5, color: AppTheme.ink400)),
                  ],
                ),
              ),
              if (underReview)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text('UNDER REVIEW',
                      style: AppTheme.body(
                          size: 9.5,
                          weight: FontWeight.w800,
                          color: AppTheme.goldSoft,
                          letterSpacing: 0.8)),
                )
              else
                ScorePill(_avg),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: f.dimensions.entries.map((e) {
              final dim = FeedbackDimension.byKey(e.key);
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.ink800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${dim.label} ${e.value}/5',
                  style: AppTheme.body(
                      size: 12, color: AppTheme.ink300),
                ),
              );
            }).toList(),
          ),
          if (f.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: f.tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.clay.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(t,
                            style: AppTheme.body(
                                size: 11.5, color: AppTheme.clay)),
                      ))
                  .toList(),
            ),
          ],
          if (f.growthTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: f.growthTags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.rose.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                              color:
                                  AppTheme.rose.withValues(alpha: 0.3)),
                        ),
                        child: Text(t,
                            style: AppTheme.body(
                                size: 11.5, color: AppTheme.rose)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 2),
            Text(
              'Growth notes are private to you.',
              style: AppTheme.body(size: 10.5, color: AppTheme.ink400),
            ),
          ],
          if (f.comment != null && f.comment!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.ink900,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '“${f.comment}”',
                style: AppTheme.body(
                    size: 13.5,
                    color: AppTheme.ink200,
                    height: 1.55),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: f.disclosed,
                  onChanged: underReview ? null : onToggle,
                  title: Text('Show on public wall',
                      style: AppTheme.body(
                          size: 13, color: AppTheme.ink300)),
                ),
              ),
              IconButton(
                onPressed: underReview ? null : onDispute,
                icon: const Icon(Icons.flag_outlined, size: 20),
                color: AppTheme.ink400,
                tooltip: 'Dispute',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Openness badge ───────────────────────────────────────────────────────────

class _OpennessBadge extends StatelessWidget {
  final String label;
  const _OpennessBadge({required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.sage.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
          border:
              Border.all(color: AppTheme.sage.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility_outlined,
                size: 13, color: AppTheme.sage),
            const SizedBox(width: 5),
            Text(label,
                style: AppTheme.body(
                    size: 11.5,
                    weight: FontWeight.w700,
                    color: AppTheme.sage)),
          ],
        ),
      );
}
