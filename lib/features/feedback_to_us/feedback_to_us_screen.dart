import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/analytics.dart';
import '../../core/app_review.dart';
import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../shared/wall_ui.dart';

/// In-app feedback to the team — suggestions, bug reports, praise. This is the
/// "tell us what you think" channel, distinct from the peer-feedback core.
class FeedbackToUsScreen extends ConsumerStatefulWidget {
  const FeedbackToUsScreen({super.key});

  @override
  ConsumerState<FeedbackToUsScreen> createState() => _FeedbackToUsScreenState();
}

class _Category {
  final String key;
  final String label;
  final IconData icon;
  const _Category(this.key, this.label, this.icon);
}

const _categories = [
  _Category('suggestion', 'Suggestion', Icons.lightbulb_outline),
  _Category('bug', 'Bug', Icons.bug_report_outlined),
  _Category('praise', 'Praise', Icons.favorite_outline),
  _Category('other', 'Other', Icons.chat_bubble_outline),
];

class _FeedbackToUsScreenState extends ConsumerState<FeedbackToUsScreen> {
  final _msgCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  String _category = 'suggestion';
  bool _sending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _msgCtrl.text.trim();
    if (message.length < 3) {
      _snack('Please add a little more detail.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _sending = true);
    try {
      String? version;
      try {
        final info = await PackageInfo.fromPlatform();
        version = '${info.version}+${info.buildNumber}';
      } catch (_) {}
      final platform = Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
              ? 'android'
              : 'other';

      await ref.read(repoProvider).submitAppFeedback(
            category: _category,
            message: message,
            contact: _contactCtrl.text.trim().isEmpty
                ? null
                : _contactCtrl.text.trim(),
            appVersion: version,
            platform: platform,
          );
      ref.read(appAnalyticsProvider).appFeedbackSent(_category);
      if (!mounted) return;
      // Praise is a positive moment — a good time to ask for a store review.
      if (_category == 'praise') {
        await ref.read(appReviewProvider).maybeAsk(ref, force: true);
      }
      if (!mounted) return;
      await _thankYou();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack(_friendly(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('resource-exhausted')) {
      return "Thanks! You've sent a lot just now — try again in a bit.";
    }
    return 'Could not send right now. Please try again.';
  }

  Future<void> _thankYou() => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Thank you 🧱'),
          content: const Text(
              'Your feedback goes straight to the team. We read every message — '
              'it genuinely shapes what we build next.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ],
        ),
      );

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    var i = 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Send feedback')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          WallCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Help us build a better Wall.',
                    style: AppTheme.display(size: 19)),
                const SizedBox(height: 8),
                Text(
                  'Found a bug? Have an idea? Just want to say hi? Tell us — '
                  'this goes directly to the people building the app.',
                  style: AppTheme.body(
                      size: 13, color: AppTheme.ink300, height: 1.5),
                ),
              ],
            ),
          ).entrance(++i),
          const SizedBox(height: 22),
          SectionLabel('What kind of feedback?').entrance(++i),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((c) {
              final sel = _category == c.key;
              return Pressable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _category = c.key);
                },
                pressedScale: 0.94,
                child: AnimatedContainer(
                  duration: WallMotion.med,
                  curve: WallMotion.ease,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppTheme.clay.withValues(alpha: 0.16)
                        : AppTheme.ink850,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: sel ? AppTheme.clay : AppTheme.ink700,
                      width: sel ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(c.icon,
                          size: 16,
                          color: sel ? AppTheme.clay : AppTheme.ink300),
                      const SizedBox(width: 7),
                      Text(c.label,
                          style: AppTheme.body(
                              size: 13,
                              weight:
                                  sel ? FontWeight.w700 : FontWeight.w500,
                              color: sel ? AppTheme.clay : AppTheme.ink300)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ).entrance(++i),
          const SizedBox(height: 22),
          SectionLabel('Your message').entrance(++i),
          TextField(
            controller: _msgCtrl,
            maxLength: 2000,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText:
                  'The more detail the better — what happened, or what you’d love to see.',
            ),
          ).entrance(++i),
          const SizedBox(height: 6),
          SectionLabel('Email (optional)').entrance(++i),
          TextField(
            controller: _contactCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'So we can reply if you’d like',
              prefixIcon: Icon(Icons.alternate_email, size: 19),
            ),
          ).entrance(++i),
          const SizedBox(height: 8),
          Text(
            'We attach your app version and platform to help us debug. '
            'No feedback content is ever shown on your Wall.',
            style: AppTheme.body(size: 11.5, color: AppTheme.ink400, height: 1.4),
          ).entrance(++i),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.ink950))
                : const Icon(Icons.send_rounded, size: 19),
            label: Text(_sending ? 'Sending…' : 'Send feedback'),
          ).entrance(++i),
        ],
      ),
    );
  }
}
