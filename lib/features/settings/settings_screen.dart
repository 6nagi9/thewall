import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/badge_definitions.dart';
import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../gamification/badges_screen.dart';
import '../legal/legal_screens.dart';
import '../premium/analytics_screen.dart';
import '../premium/premium_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).value;
    final gam = ref.watch(gamificationProvider).value;
    final repo = ref.read(repoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Profile ──────────────────────────────────────────────────────
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.tealDark,
              child: Text(
                (user?.displayName.isEmpty ?? true)
                    ? '?'
                    : user!.displayName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(user?.displayName ?? '—'),
            subtitle: Row(
              children: [
                Text(user?.premium == true ? 'Premium' : 'Free plan'),
                if (user?.premium == true) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified,
                      size: 14, color: AppTheme.teal),
                ],
              ],
            ),
            trailing: user?.premium != true
                ? TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PremiumScreen())),
                    child: const Text('Upgrade'))
                : null,
          ),
          const Divider(),

          // ── Privacy (DPDP Act 2023) ───────────────────────────────────────
          const _SectionHeader('Your privacy (DPDP Act, 2023)'),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Export my data'),
            subtitle: const Text('Download everything we hold about you'),
            onTap: () => _exportData(context, repo),
          ),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Consent & audit log'),
            subtitle: const Text('Where your data lives and why'),
            onTap: () => _showAuditLog(context, user?.consentAt),
          ),
          ListTile(
            leading:
                const Icon(Icons.delete_forever, color: AppTheme.rose),
            title: const Text('Delete account & data',
                style: TextStyle(color: AppTheme.rose)),
            subtitle:
                const Text('Permanent erasure (right to be forgotten)'),
            onTap: () => _confirmDelete(context, ref),
          ),
          const Divider(),

          // ── Gamification ──────────────────────────────────────────────────
          const _SectionHeader('Achievements'),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined,
                color: AppTheme.amber),
            title: const Text('Badges & streaks'),
            subtitle: Text(
                '${gam?.badges.length ?? 0}/${kBadges.length} earned · '
                '${gam?.streak.current ?? 0}-day streak'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BadgesScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.show_chart, color: AppTheme.teal),
            title: const Text('Trend analytics'),
            subtitle: const Text('See how your scores change over time'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user?.premium != true)
                  const Chip(
                      label: Text('Premium',
                          style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.leaderboard_outlined),
            title: const Text('Appear on leaderboards'),
            subtitle: const Text(
                'Show your scores in the Discover tab (opt-in)'),
            value: gam?.leaderboardOptIn ?? false,
            onChanged: (v) => repo.setLeaderboardOptIn(v),
          ),
          const Divider(),

          // ── Safety ───────────────────────────────────────────────────────
          const _SectionHeader('Safety'),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Blocked users'),
            onTap: () => _snack(context, 'No blocked users.'),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Grievance officer'),
            subtitle:
                const Text('grievance@thewall.app · 7-day response'),
            onTap: () => _snack(context, 'Contact: grievance@thewall.app'),
          ),
          const Divider(),

          // ── Legal ────────────────────────────────────────────────────────
          const _SectionHeader('Legal'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Use'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TermsScreen())),
          ),
          const Divider(),

          // ── Account ───────────────────────────────────────────────────────
          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => FirebaseAuth.instance.signOut(),
          ),
          const SizedBox(height: 24),
          const Center(child: _AppVersionFooter()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _exportData(
      BuildContext context, WallRepository repo) async {
    try {
      _snack(context, 'Generating export…');
      final json = await repo.generateDataExport();
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Your data export'),
            content: SizedBox(
              width: double.maxFinite,
              height: 200,
              child: SingleChildScrollView(
                child: Text(json,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 11)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: json));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard.')));
                },
                child: const Text('Copy'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await SharePlus.instance.share(ShareParams(
                    text: json,
                    subject: 'My Wall data export',
                  ));
                },
                child: const Text('Share'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) _snack(context, 'Export failed: $e');
    }
  }

  void _showAuditLog(BuildContext context, DateTime? consentAt) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Consent & data audit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (consentAt != null)
              Text(
                  'Consent given: ${consentAt.toLocal().toString().split('.').first}'),
            const SizedBox(height: 12),
            const Text('Where your data lives:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('• users/{uid} — your profile (private to you)'),
            const Text(
                '• users/{uid}/inbox — feedback you received (private to you)'),
            const Text(
                '• walls/{phoneHash} — your public aggregate (scores + disclosed comments only)'),
            const Text(
                '• gamification/{uid} — your badges, streak, leaderboard score'),
            const Text(
                '• reviews/{id} — raw reviews (never readable by clients; Functions-only)'),
            const SizedBox(height: 12),
            const Text('All data stored in asia-south1 (Mumbai, India).',
                style: TextStyle(color: AppTheme.slate300, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete everything?'),
        content: const Text(
            'This permanently erases your account, your Wall, and all '
            'feedback about you. Feedback you wrote about others stays '
            '(anonymised), as it is their data. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(functionsProvider)
                  .httpsCallable('handleErasure')
                  .call();
              await FirebaseAuth.instance.signOut();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Footer showing data-residency note + the app version/build number.
class _AppVersionFooter extends StatelessWidget {
  const _AppVersionFooter();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final v = snap.hasData
            ? 'v${snap.data!.version} (${snap.data!.buildNumber})'
            : '';
        return Column(
          children: [
            const Text(
              'The Wall · Data stored in India (asia-south1)',
              style: TextStyle(color: AppTheme.slate500, fontSize: 12),
            ),
            if (v.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(v,
                  style: const TextStyle(
                      color: AppTheme.slate700, fontSize: 11)),
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
              color: AppTheme.slate500,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5),
        ),
      );
}
