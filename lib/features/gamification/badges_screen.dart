import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/badge_definitions.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../shared/wall_ui.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamAsync = ref.watch(gamificationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: gamAsync.when(
        loading: () => const WallLoader(),
        error: (e, _) => Center(
            child: Text('$e', style: AppTheme.body(color: AppTheme.rose))),
        data: (gam) {
          final earned = gam?.badges ?? [];
          final earnedIds = earned.map((b) => b.id).toSet();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _StreakCard(streak: gam?.streak ?? const Streak())
                  .entrance(0),
              const SizedBox(height: 22),
              SectionLabel(
                'Collection',
                trailing: Text(
                  '${earnedIds.length} of ${kBadges.length}',
                  style: AppTheme.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: AppTheme.clay),
                ),
              ).entrance(1),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.02,
                ),
                itemCount: kBadges.length,
                itemBuilder: (_, i) {
                  final def = kBadges[i];
                  final earnedBadge =
                      earned.where((b) => b.id == def.id).firstOrNull;
                  return _BadgeTile(def: def, earnedBadge: earnedBadge)
                      .entrance(i + 2);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final Streak streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final lit = streak.current >= 1;
    return WallCard(
      padding: const EdgeInsets.all(20),
      gradient: lit
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.flame.withValues(alpha: 0.14),
                AppTheme.ink850,
              ],
            )
          : null,
      borderColor:
          lit ? AppTheme.flame.withValues(alpha: 0.35) : null,
      child: Row(
        children: [
          Icon(
            lit
                ? Icons.local_fire_department_rounded
                : Icons.local_fire_department_outlined,
            color: lit ? AppTheme.flame : AppTheme.ink600,
            size: 44,
          )
              .animate(
                onPlay: (c) => lit ? c.repeat(reverse: true) : null,
              )
              .scale(
                begin: const Offset(1, 1),
                end: Offset(lit ? 1.1 : 1, lit ? 1.1 : 1),
                duration: 900.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${streak.current}-day streak',
                  style: AppTheme.display(size: 22)),
              const SizedBox(height: 2),
              Text('Best: ${streak.longest} days',
                  style: AppTheme.body(
                      size: 13, color: AppTheme.ink400)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final BadgeDef def;
  final BadgeEarned? earnedBadge;
  const _BadgeTile({required this.def, this.earnedBadge});

  @override
  Widget build(BuildContext context) {
    final earned = earnedBadge != null;
    return WallCard(
      onTap: () {
        HapticFeedback.lightImpact();
        _showDetail(context, earned);
      },
      padding: const EdgeInsets.all(14),
      borderColor:
          earned ? def.color.withValues(alpha: 0.45) : null,
      color: earned ? null : AppTheme.ink900,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: earned
                  ? def.color.withValues(alpha: 0.14)
                  : AppTheme.ink850,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: earned
                    ? def.color.withValues(alpha: 0.45)
                    : AppTheme.ink700,
              ),
            ),
            child: Icon(
              def.icon,
              size: 28,
              color: earned ? def.color : AppTheme.ink600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            def.label,
            textAlign: TextAlign.center,
            style: AppTheme.body(
              size: 12.5,
              weight: FontWeight.w700,
              color: earned ? AppTheme.paper : AppTheme.ink400,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          if (earned)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 13, color: AppTheme.sage),
                const SizedBox(width: 4),
                Text('Earned',
                    style: AppTheme.body(
                        size: 10.5,
                        weight: FontWeight.w700,
                        color: AppTheme.sage)),
              ],
            )
          else
            Text('Locked',
                style: AppTheme.body(
                    size: 10.5, color: AppTheme.ink600)),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, bool earned) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (earned ? def.color : AppTheme.ink600)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(def.icon,
                  color: earned ? def.color : AppTheme.ink600),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(def.label)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(def.description),
            const SizedBox(height: 12),
            if (earnedBadge != null)
              Text(
                'Earned ${DateFormat('d MMM yyyy').format(earnedBadge!.awardedAt)}',
                style: AppTheme.body(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppTheme.sage),
              )
            else
              Text('Not yet earned.',
                  style: AppTheme.body(
                      size: 12, color: AppTheme.ink400)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );
  }
}
