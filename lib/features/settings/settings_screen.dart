import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_review.dart';
import '../../core/badge_definitions.dart';
import '../../core/constants.dart';
import '../../core/share_helpers.dart';
import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../shared/wall_ui.dart';
import '../feedback_to_us/feedback_to_us_screen.dart';
import '../gamification/badges_screen.dart';
import '../legal/legal_screens.dart';
import '../premium/analytics_screen.dart';
import '../premium/premium_screen.dart';
import '../self_assessment/self_assessment_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).value;
    final gam = ref.watch(gamificationProvider).value;
    final repo = ref.read(repoProvider);
    var i = 0;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          children: [
            const ScreenHeader(kicker: 'You', title: 'Settings'),
            // ── Profile card ─────────────────────────────────────────────
            WallCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.clayBright, AppTheme.clayDeep],
                      ),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Center(
                      child: Text(
                        (user?.displayName.isEmpty ?? true)
                            ? '?'
                            : user!.displayName[0].toUpperCase(),
                        style: AppTheme.display(
                            size: 22, color: AppTheme.ink950),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.displayName ?? '—',
                            style: AppTheme.display(size: 18)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (user?.isPremium == true) ...[
                              const Icon(Icons.verified_rounded,
                                  size: 14, color: AppTheme.goldSoft),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              user?.isPremium == true
                                  ? (user!.premium
                                      ? 'Premium'
                                      : 'Premium (referral reward)')
                                  : 'Free plan',
                              style: AppTheme.body(
                                  size: 12.5,
                                  color: user?.isPremium == true
                                      ? AppTheme.goldSoft
                                      : AppTheme.ink400),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (user?.isPremium != true)
                    TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PremiumScreen())),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.goldSoft),
                      child: const Text('Upgrade'),
                    ),
                ],
              ),
            ).entrance(++i),
            const SizedBox(height: 24),

            // ── Privacy (DPDP Act 2023) ──────────────────────────────────
            SectionLabel('Your privacy · DPDP Act, 2023').entrance(++i),
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.download_outlined,
                title: 'Export my data',
                subtitle: 'Download everything we hold about you',
                onTap: () => _exportData(context, repo),
              ),
              _SettingsTile(
                icon: Icons.shield_outlined,
                title: 'Consent & audit log',
                subtitle: 'Where your data lives and why',
                onTap: () => _showAuditLog(context, user?.consentAt),
              ),
              _SettingsTile(
                icon: Icons.delete_forever_outlined,
                title: 'Delete account & data',
                subtitle: 'Permanent erasure (right to be forgotten)',
                destructive: true,
                onTap: () => _confirmDelete(context, ref),
              ),
            ]).entrance(++i),
            const SizedBox(height: 24),

            // ── Achievements ─────────────────────────────────────────────
            SectionLabel('Achievements').entrance(++i),
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.emoji_events_outlined,
                iconColor: AppTheme.gold,
                title: 'Badges & streaks',
                subtitle:
                    '${gam?.badges.length ?? 0}/${kBadges.length} earned · ${gam?.streak.current ?? 0}-day streak',
                chevron: true,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BadgesScreen())),
              ),
              _SettingsTile(
                icon: Icons.show_chart,
                iconColor: AppTheme.clay,
                title: 'Trends',
                subtitle: 'How your scores change over time',
                trailing: user?.isPremium != true
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.gold.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('PREMIUM',
                            style: AppTheme.body(
                                size: 9,
                                weight: FontWeight.w800,
                                color: AppTheme.goldSoft,
                                letterSpacing: 0.8)),
                      )
                    : null,
                chevron: true,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnalyticsScreen())),
              ),
              _SwitchTile(
                icon: Icons.leaderboard_outlined,
                title: 'Appear on leaderboards',
                subtitle: 'Show your scores in Discover (opt-in)',
                value: gam?.leaderboardOptIn ?? false,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  repo.setLeaderboardOptIn(v);
                },
              ),
            ]).entrance(++i),
            const SizedBox(height: 24),

            // ── Sharing & growth ─────────────────────────────────────────
            SectionLabel('Sharing & growth').entrance(++i),
            _SettingsGroup(children: [
              _SwitchTile(
                icon: Icons.public_rounded,
                title: 'Public web wall',
                subtitle: user?.publicSlug != null
                    ? 'Live — share your page from here'
                    : 'Publish a page with only what you disclose',
                value: user?.publicSlug != null,
                onChanged: (v) => _togglePublish(context, repo, v),
              ),
              if (user?.publicSlug != null)
                _SettingsTile(
                  icon: Icons.link_rounded,
                  iconColor: AppTheme.clay,
                  title: 'Share my wall link',
                  subtitle: '${K.webBase}/w/${user!.publicSlug}',
                  onTap: () => shareViaWhatsApp(
                      'See what people who know me say — my Wall: '
                      '${K.webBase}/w/${user.publicSlug}'),
                ),
              _SettingsTile(
                icon: Icons.psychology_outlined,
                iconColor: AppTheme.sage,
                title: 'My self-assessment',
                subtitle:
                    'Powers the "you vs others" comparison on your wall',
                chevron: true,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SelfAssessmentScreen())),
              ),
              _SettingsTile(
                icon: Icons.card_giftcard_rounded,
                iconColor: AppTheme.gold,
                title: 'Invite rewards',
                subtitle: (user?.inviteJoins ?? 0) == 0
                    ? 'Each friend who joins from your invite = 7 days Premium'
                    : '${user!.inviteJoins} joined · ${user.inviteJoins * 7} Premium days earned',
                onTap: () => _snack(context,
                    'Invites are sent when you give feedback to someone not yet on Known.'),
              ),
            ]).entrance(++i),
            const SizedBox(height: 24),

            // ── Safety ───────────────────────────────────────────────────
            SectionLabel('Safety').entrance(++i),
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.block_outlined,
                title: 'Blocked users',
                onTap: () => _snack(context, 'No blocked users.'),
              ),
              _SettingsTile(
                icon: Icons.support_agent_outlined,
                title: 'Grievance officer',
                subtitle: 'grievance@thewall.app · 7-day response',
                onTap: () =>
                    _snack(context, 'Contact: grievance@thewall.app'),
              ),
            ]).entrance(++i),
            const SizedBox(height: 24),

            // ── Help & feedback ──────────────────────────────────────────
            SectionLabel('Help & feedback').entrance(++i),
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.campaign_outlined,
                iconColor: AppTheme.clay,
                title: 'Send feedback or suggest a feature',
                subtitle: 'Ideas, bugs, praise — straight to the team',
                chevron: true,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FeedbackToUsScreen())),
              ),
              _SettingsTile(
                icon: Icons.star_outline_rounded,
                iconColor: AppTheme.gold,
                title: 'Rate Known',
                subtitle: 'Enjoying the app? A review really helps',
                chevron: true,
                onTap: () => ref.read(appReviewProvider).openStoreListing(),
              ),
              _SettingsTile(
                icon: Icons.ios_share_rounded,
                title: 'Share Known',
                subtitle: 'Invite friends to claim their wall',
                onTap: () => shareViaWhatsApp(
                    'I\'m on Known — honest feedback from people who know '
                    'you, on your terms. Claim your wall: ${K.webBase}'),
              ),
            ]).entrance(++i),
            const SizedBox(height: 24),

            // ── Legal ────────────────────────────────────────────────────
            SectionLabel('Legal').entrance(++i),
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                chevron: true,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen())),
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms of Use',
                chevron: true,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TermsScreen())),
              ),
            ]).entrance(++i),
            const SizedBox(height: 24),

            // ── Account ──────────────────────────────────────────────────
            SectionLabel('Account').entrance(++i),
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.logout,
                title: 'Sign out',
                onTap: () => FirebaseAuth.instance.signOut(),
              ),
            ]).entrance(++i),
            const SizedBox(height: 28),
            const Center(child: _AppVersionFooter()).entrance(++i),
          ],
        ),
      ),
    );
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _togglePublish(
      BuildContext context, WallRepository repo, bool publish) async {
    HapticFeedback.selectionClick();
    if (!publish) {
      await repo.setWallPublish(false);
      if (context.mounted) _snack(context, 'Your public wall is offline.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Publish your wall?'),
        content: const Text(
            'Creates a public web page at a private random link showing ONLY '
            'what you\'ve disclosed: your name, top tags, scores and openness. '
            'You can take it down anytime.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Publish')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final link = await repo.setWallPublish(true);
      if (context.mounted && link != null) {
        _snack(context, 'Live at $link');
      }
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not publish: $e');
    }
  }

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
                      const SnackBar(
                          content: Text('Copied to clipboard.')));
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
        content: SingleChildScrollView(
          child: Column(
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
              Text('All data stored in asia-south1 (Mumbai, India).',
                  style: AppTheme.body(
                      size: 12, color: AppTheme.ink300)),
            ],
          ),
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
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.rose,
                minimumSize: const Size(120, 48)),
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

// ─── Grouped tiles ────────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var j = 0; j < children.length; j++) {
      items.add(children[j]);
      if (j != children.length - 1) {
        items.add(const Divider(height: 1, indent: 56));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.ink850,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.ink700),
      ),
      child: Column(children: items),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;
  final bool chevron;
  final Color? iconColor;
  final Widget? trailing;
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.destructive = false,
    this.chevron = false,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = destructive
        ? AppTheme.rose
        : (iconColor ?? AppTheme.ink300);
    return ListTile(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: c, size: 22),
      title: Text(title,
          style: AppTheme.body(
              size: 14.5,
              weight: FontWeight.w600,
              color: destructive ? AppTheme.rose : AppTheme.paper)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              style: AppTheme.body(
                  size: 12, color: AppTheme.ink400, height: 1.35)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?trailing,
          if (chevron) ...[
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right,
                color: AppTheme.ink600, size: 20),
          ],
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
        secondary: Icon(icon, color: AppTheme.ink300, size: 22),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        title: Text(title,
            style: AppTheme.body(
                size: 14.5,
                weight: FontWeight.w600,
                color: AppTheme.paper)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!,
                style: AppTheme.body(
                    size: 12, color: AppTheme.ink400, height: 1.35)),
        value: value,
        onChanged: onChanged,
      );
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
            const BrickMark(size: 22, animate: false),
            const SizedBox(height: 10),
            Text(
              'Known · Data stored in India (asia-south1)',
              style: AppTheme.body(size: 12, color: AppTheme.ink400),
            ),
            if (v.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(v,
                  style: AppTheme.body(
                      size: 11, color: AppTheme.ink600)),
            ],
          ],
        );
      },
    );
  }
}
