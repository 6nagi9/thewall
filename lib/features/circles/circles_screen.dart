import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/remote_config.dart';
import '../../core/share_helpers.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../shared/wall_ui.dart';

/// Circles — small groups (friends, teams, class sections) joined by code.
/// Social proximity beats global rank: seeing *your people* give feedback is
/// the retention spine, and a "team circle" is the future B2B on-ramp.
class CirclesTab extends ConsumerWidget {
  const CirclesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circles = ref.watch(myCirclesProvider).value ?? const [];
    var i = 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _createDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _joinDialog(context, ref),
                icon: const Icon(Icons.tag_rounded, size: 18),
                label: const Text('Join by code'),
              ),
            ),
          ],
        ).entrance(++i),
        const SizedBox(height: 18),
        if (circles.isEmpty)
          const EmptyState(
            icon: Icons.group_work_outlined,
            title: 'No circles yet',
            message:
                'Start one with your flat, your team or your class — and see '
                'who actually shows up with feedback.',
          ).entrance(++i)
        else
          ...circles.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: WallCard(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CircleDetailScreen(circle: c))),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.sage.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.group_rounded,
                            color: AppTheme.sage),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name,
                                style: AppTheme.body(
                                    size: 15,
                                    weight: FontWeight.w700,
                                    color: AppTheme.paper)),
                            Text(
                                '${c.memberCount} member${c.memberCount == 1 ? "" : "s"} · code ${c.code}',
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
              )),
      ],
    );
  }

  void _createDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Create a circle'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 40,
          decoration:
              const InputDecoration(hintText: 'e.g. "Flat 4B" or "Design team"'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.length < 2) return;
              Navigator.pop(dialogCtx);
              try {
                final res = await ref.read(repoProvider).createCircle(name);
                final code = res['code'] as String? ?? '';
                final link = res['link'] as String? ?? K.webBase;
                await shareViaWhatsApp(
                    'Join my circle "$name" on Known — code $code or tap: $link');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('Create & invite'),
          ),
        ],
      ),
    );
  }

  void _joinDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Join a circle'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: '6-letter code'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final code = ctrl.text.trim().toUpperCase();
              Navigator.pop(dialogCtx);
              await joinCircleByCode(context, ref, code);
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

/// Shared join handler — used by the dialog and the /c/{code} deep link.
Future<void> joinCircleByCode(
    BuildContext context, WidgetRef ref, String code) async {
  try {
    HapticFeedback.mediumImpact();
    final res = await ref.read(repoProvider).joinCircle(code);
    if (!context.mounted) return;
    final name = res['name'] as String?;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['alreadyMember'] == true
            ? 'You\'re already in this circle.'
            : 'Welcome to ${name ?? "the circle"}!')));
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class CircleDetailScreen extends ConsumerWidget {
  final Circle circle;
  const CircleDetailScreen({super.key, required this.circle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members =
        ref.watch(circleMembersProvider(circle.id)).value ?? const [];
    var i = 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(circle.name),
        actions: [
          IconButton(
            tooltip: 'Leave circle',
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: () async {
              await ref.read(repoProvider).leaveCircle(circle.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          WallCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invite code',
                          style: AppTheme.body(
                              size: 11.5,
                              weight: FontWeight.w700,
                              color: AppTheme.ink400,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 4),
                      Text(circle.code,
                          style: AppTheme.display(
                              size: 24, color: AppTheme.clay)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => shareViaWhatsApp(renderTemplate(
                    'Join my circle "${circle.name}" on Known — code ${circle.code} or tap: {link}',
                    link: '${K.webBase}/c/${circle.code}',
                  )),
                  icon: const Icon(Icons.ios_share_rounded, size: 17),
                  label: const Text('Invite'),
                ),
              ],
            ),
          ).entrance(++i),
          const SizedBox(height: 22),
          SectionLabel('Who shows up · feedback given').entrance(++i),
          ...members.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: WallCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.clay.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Center(
                          child: Text(
                            m.displayName.isEmpty
                                ? '?'
                                : m.displayName[0].toUpperCase(),
                            style: AppTheme.display(
                                size: 15, color: AppTheme.clay),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(m.displayName,
                            style: AppTheme.body(
                                size: 14.5,
                                weight: FontWeight.w600,
                                color: AppTheme.paper)),
                      ),
                      Text('${m.given} given',
                          style: AppTheme.display(
                              size: 14, color: AppTheme.sage)),
                    ],
                  ),
                ).entrance((++i).clamp(0, 12)),
              )),
        ],
      ),
    );
  }
}
