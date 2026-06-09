import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/badge_definitions.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamAsync = ref.watch(gamificationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Badges & Achievements')),
      body: gamAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (gam) {
          final earned = gam?.badges ?? [];
          final earnedIds = earned.map((b) => b.id).toSet();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StreakCard(streak: gam?.streak ?? const Streak()),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text('${earnedIds.length}/${kBadges.length} earned',
                      style: const TextStyle(
                          color: AppTheme.slate500, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                ),
                itemCount: kBadges.length,
                itemBuilder: (_, i) {
                  final def = kBadges[i];
                  final earnedBadge = earned
                      .where((b) => b.id == def.id)
                      .firstOrNull;
                  return _BadgeTile(
                      def: def, earnedBadge: earnedBadge);
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
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                streak.current >= 7
                    ? Icons.local_fire_department
                    : Icons.local_fire_department_outlined,
                color: streak.current >= 1 ? AppTheme.rose : AppTheme.slate700,
                size: 40,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${streak.current}-day streak',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Best: ${streak.longest} days',
                    style: const TextStyle(color: AppTheme.slate500),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _BadgeTile extends StatelessWidget {
  final BadgeDef def;
  final BadgeEarned? earnedBadge;
  const _BadgeTile({required this.def, this.earnedBadge});

  @override
  Widget build(BuildContext context) {
    final earned = earnedBadge != null;
    return GestureDetector(
      onTap: () => _showDetail(context, earned),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                def.icon,
                size: 38,
                color: earned ? def.color : AppTheme.slate700,
              ),
              const SizedBox(height: 8),
              Text(
                def.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: earned ? Colors.white : AppTheme.slate500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (earned) ...[
                const SizedBox(height: 4),
                const Icon(Icons.check_circle,
                    size: 13, color: AppTheme.emerald),
              ] else
                const SizedBox(height: 17),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, bool earned) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(def.icon, color: earned ? def.color : AppTheme.slate700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(def.label,
                  style: TextStyle(
                      color: earned ? Colors.white : AppTheme.slate500)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(def.description),
            if (earnedBadge != null) ...[
              const SizedBox(height: 12),
              Text(
                'Earned ${DateFormat('d MMM yyyy').format(earnedBadge!.awardedAt)}',
                style: const TextStyle(
                    color: AppTheme.emerald, fontSize: 12),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text('Not yet earned.',
                  style: TextStyle(color: AppTheme.slate500, fontSize: 12)),
            ],
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
