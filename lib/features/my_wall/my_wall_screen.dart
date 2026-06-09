import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/badge_definitions.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../gamification/badges_screen.dart';
import '../feedback/request_feedback_screen.dart';
import '../premium/premium_screen.dart';

class MyWallScreen extends ConsumerWidget {
  const MyWallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).value;
    final wall = ref.watch(myWallProvider).value;
    final feedbackAsync = ref.watch(receivedFeedbackProvider);
    final gam = ref.watch(gamificationProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wall'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                  child: _OpennessBadge(label: wall?.opennessLabel ?? 'New')),
            ),
        ],
      ),
      body: feedbackAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (feedback) {
          final gateCleared = user?.gateCleared ?? false;
          final isPremium = user?.premium ?? false;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(name: user?.displayName ?? '', count: feedback.length),
              const SizedBox(height: 16),

              // ── Give-to-get soft gate ─────────────────────────────────────
              if (!gateCleared)
                _SoftGateCard(
                  count: feedback.length,
                  given: user?.giveToGetCount ?? 0,
                  onAccessData: () =>
                      ref.read(repoProvider).requestDataAccess(),
                )
              else ...[
                // ── Dimension summary ───────────────────────────────────────
                if (wall != null && wall.meetsMinN) ...[
                  _DimensionSummary(wall: wall),
                  const SizedBox(height: 12),
                ],

                // ── Premium: coaching prompts ───────────────────────────────
                if (isPremium && wall != null && wall.meetsMinN)
                  _CoachingCard(wall: wall),

                // ── Premium: cohort comparison ──────────────────────────────
                if (isPremium && wall != null && wall.meetsMinN) ...[
                  const SizedBox(height: 12),
                  _CohortCard(wall: wall),
                ],

                // ── Premium upsell banner ───────────────────────────────────
                if (!isPremium) ...[
                  const SizedBox(height: 12),
                  _PremiumBanner(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const PremiumScreen())),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Badges mini section ─────────────────────────────────────
                _BadgesMiniSection(
                  badges: gam?.badges ?? [],
                  onViewAll: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const BadgesScreen())),
                ),
                const SizedBox(height: 16),

                // ── Request feedback campaign ───────────────────────────────
                if (isPremium)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const RequestFeedbackScreen())),
                    icon: const Icon(Icons.campaign_outlined),
                    label: const Text('Request targeted feedback'),
                  ),

                const SizedBox(height: 16),

                // ── Received feedback list ──────────────────────────────────
                Text('Feedback you\'ve received (${feedback.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (feedback.isEmpty)
                  const _EmptyInbox()
                else
                  ...feedback.map((f) => _FeedbackCard(
                        f: f,
                        onToggle: (v) =>
                            ref.read(repoProvider).setDisclosure(f.id, v),
                        onDispute: () => _dispute(context, ref, f.id),
                      )),
              ],
            ],
          );
        },
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
  const _Header({required this.name, required this.count});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.tealDark,
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    Text('$count piece(s) of feedback',
                        style: const TextStyle(color: AppTheme.slate300)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// ─── Soft gate ───────────────────────────────────────────────────────────────

class _SoftGateCard extends StatelessWidget {
  final int count;
  final int given;
  final VoidCallback onAccessData;
  const _SoftGateCard(
      {required this.count,
      required this.given,
      required this.onAccessData});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.lock_outline, color: AppTheme.amber, size: 40),
              const SizedBox(height: 12),
              Text(
                '$count ${count == 1 ? "person" : "people"} wrote about you',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (i) => Icon(Icons.star,
                        color:
                            i < 3 ? AppTheme.amber : AppTheme.slate700,
                        size: 32),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (given / K.giveToGetThreshold).clamp(0.0, 1.0),
                backgroundColor: AppTheme.slate700,
                color: AppTheme.teal,
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Text(
                'Give feedback to ${K.giveToGetThreshold - given} more '
                'contact(s) to unlock your Wall',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.slate300),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onAccessData,
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: const Text('Access my data now (Privacy right)'),
              ),
            ],
          ),
        ),
      );
}

// ─── Dimension summary ────────────────────────────────────────────────────────

class _DimensionSummary extends StatelessWidget {
  final Wall wall;
  const _DimensionSummary({required this.wall});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your strengths',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...FeedbackDimension.all.map((d) {
                final v = wall.dimensionAverages[d.key] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 120, child: Text(d.label)),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (v / 5).clamp(0.0, 1.0),
                          backgroundColor: AppTheme.slate700,
                          color: AppTheme.teal,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(v.toStringAsFixed(1)),
                    ],
                  ),
                );
              }),
            ],
          ),
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
};

class _CoachingCard extends StatelessWidget {
  final Wall wall;
  const _CoachingCard({required this.wall});

  @override
  Widget build(BuildContext context) {
    final tips = wall.dimensionAverages.entries
        .where((e) => e.value < 3.5)
        .map((e) => _kCoachingTips[e.key])
        .whereType<String>()
        .toList();
    if (tips.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.lightbulb_outline, color: AppTheme.amber),
                SizedBox(width: 8),
                Text('Coaching tips',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                Spacer(),
                Chip(
                  label: Text('Premium',
                      style: TextStyle(fontSize: 11, color: AppTheme.teal)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...tips.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_right, size: 18,
                          color: AppTheme.teal),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(t,
                              style: const TextStyle(
                                  color: AppTheme.slate300,
                                  fontSize: 13))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Cohort comparison (Premium) ─────────────────────────────────────────────

class _CohortCard extends StatelessWidget {
  final Wall wall;
  const _CohortCard({required this.wall});

  String _label(double score) {
    if (score >= 4.5) return 'top 10%';
    if (score >= 4.0) return 'top 25%';
    if (score >= 3.5) return 'top 50%';
    return 'below average — keep going!';
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.people_outline, color: AppTheme.teal),
                  SizedBox(width: 8),
                  Text('Cohort comparison',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  Spacer(),
                  Chip(
                    label: Text('Premium',
                        style:
                            TextStyle(fontSize: 11, color: AppTheme.teal)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...FeedbackDimension.all.map((d) {
                final v = wall.dimensionAverages[d.key] ?? 0;
                if (v == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 110,
                          child: Text(d.label,
                              style: const TextStyle(fontSize: 13))),
                      const SizedBox(width: 8),
                      Text(_label(v),
                          style: const TextStyle(
                              color: AppTheme.teal,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
}

// ─── Premium upsell banner ────────────────────────────────────────────────────

class _PremiumBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _PremiumBanner({required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: const [
                Icon(Icons.workspace_premium_outlined,
                    color: AppTheme.amber, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Unlock Premium',
                          style: TextStyle(
                              fontWeight: FontWeight.w700)),
                      Text(
                          'Coaching tips, cohort comparison, trend charts & more.',
                          style: TextStyle(
                              color: AppTheme.slate300,
                              fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.slate500),
              ],
            ),
          ),
        ),
      );
}

// ─── Badges mini section ──────────────────────────────────────────────────────

class _BadgesMiniSection extends StatelessWidget {
  final List<BadgeEarned> badges;
  final VoidCallback onViewAll;
  const _BadgesMiniSection(
      {required this.badges, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final earnedIds = badges.map((b) => b.id).toSet();
    final shown = kBadges
        .where((d) => earnedIds.contains(d.id))
        .take(4)
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Badges',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                    onPressed: onViewAll,
                    child: Text(
                        '${earnedIds.length}/${kBadges.length} — View all')),
              ],
            ),
            const SizedBox(height: 8),
            if (shown.isEmpty)
              const Text(
                'No badges yet — give feedback to start earning!',
                style: TextStyle(color: AppTheme.slate500, fontSize: 13),
              )
            else
              Row(
                children: shown
                    .map((d) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              Icon(d.icon, color: d.color, size: 28),
                              const SizedBox(height: 4),
                              Text(d.label,
                                  style: const TextStyle(fontSize: 10),
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Feedback card ────────────────────────────────────────────────────────────

class _FeedbackCard extends StatelessWidget {
  final ReceivedFeedback f;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDispute;
  const _FeedbackCard(
      {required this.f, required this.onToggle, required this.onDispute});

  @override
  Widget build(BuildContext context) {
    final underReview = f.status == 'under_review';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: AppTheme.slate500, size: 18),
                const SizedBox(width: 6),
                Text(f.authorName ?? 'Anonymous',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (f.contextTag != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(f.contextTag!,
                        style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
                const Spacer(),
                if (underReview)
                  const Text('Under review',
                      style: TextStyle(
                          color: AppTheme.amber, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: f.dimensions.entries.map((e) {
                final dim = FeedbackDimension.all.firstWhere(
                    (d) => d.key == e.key,
                    orElse: () =>
                        FeedbackDimension(e.key, e.key, '', ''));
                return Text('${dim.label}: ${e.value}/5',
                    style: const TextStyle(
                        color: AppTheme.slate300, fontSize: 13));
              }).toList(),
            ),
            if (f.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: f.tags
                    .map((t) => Chip(
                          label: Text(t,
                              style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            if (f.comment != null && f.comment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('"${f.comment}"',
                  style:
                      const TextStyle(fontStyle: FontStyle.italic)),
            ],
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: f.disclosed,
                    onChanged: underReview ? null : onToggle,
                    title: const Text('Show on public Wall',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
                IconButton(
                  onPressed: underReview ? null : onDispute,
                  icon: const Icon(Icons.flag_outlined, size: 20),
                  tooltip: 'Dispute',
                ),
              ],
            ),
          ],
        ),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.tealDark.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.teal),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility, size: 14, color: AppTheme.teal),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.teal,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ─── Empty inbox ──────────────────────────────────────────────────────────────

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No feedback yet — invite your connections to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.slate500),
          ),
        ),
      );
}
