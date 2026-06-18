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
import '../premium/premium_screen.dart';

/// B1 — Feedback campaigns: the owner solicits feedback via a shareable link.
///
/// FREE for everyone (one active campaign; unlimited with Premium) — the
/// ask-link is the app's strongest viral loop and must never sit behind the
/// paywall. Premium monetizes the insight on the results instead.
class RequestFeedbackScreen extends ConsumerStatefulWidget {
  const RequestFeedbackScreen({super.key});
  @override
  ConsumerState<RequestFeedbackScreen> createState() =>
      _RequestFeedbackScreenState();
}

class _RequestFeedbackScreenState
    extends ConsumerState<RequestFeedbackScreen> {
  final _msgCtrl = TextEditingController();
  final Set<String> _dims = {};
  bool _loading = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _launch() async {
    if (_dims.isEmpty) {
      _snack('Pick at least one focus area.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      final result = await ref.read(repoProvider).requestFeedback(
            message:
                _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
            focusDimensions: _dims.toList(),
          );
      if (!mounted) return;
      final link = result['link'] as String? ?? K.webBase;
      await _shareSheet(link);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = '$e';
      if (msg.contains('resource-exhausted') ||
          msg.contains('one active campaign')) {
        _upsell();
      } else {
        _snack(msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _shareSheet(String link, {String? customMessage}) async {
    final template = ref
        .read(remoteConfigProvider)
        .getString(RemoteConfigKeys.campaignTemplate);
    final base = renderTemplate(template, link: link);
    final msg = (customMessage ?? _msgCtrl.text.trim()).isEmpty
        ? base
        : '${customMessage ?? _msgCtrl.text.trim()}\n\n$base';
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.ink900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your link is live', style: AppTheme.display(size: 20)),
              const SizedBox(height: 8),
              Text(
                'Anyone who opens it can give you structured feedback — '
                'anonymously if they choose.',
                style: AppTheme.body(
                    size: 13.5, color: AppTheme.ink300, height: 1.5),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetCtx);
                  await shareViaWhatsApp(msg);
                },
                icon: const Icon(Icons.chat_rounded, size: 19),
                label: const Text('Share on WhatsApp'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetCtx);
                  await shareText(msg, subject: 'Feedback request — Known');
                },
                icon: const Icon(Icons.ios_share_rounded, size: 19),
                label: const Text('More options'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _upsell() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('One campaign at a time'),
        content: const Text(
            'Free includes one active campaign. Close your current one below, '
            'or go Premium for unlimited campaigns.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PremiumScreen()));
            },
            child: const Text('Go Premium'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final campaigns = ref.watch(myFeedbackRequestsProvider).value ?? const [];
    final active =
        campaigns.where((c) => c.status == 'active').toList();
    var i = 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Ask for feedback')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          WallCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ask for feedback that matters to you.',
                    style: AppTheme.display(size: 19)),
                const SizedBox(height: 8),
                Text(
                  'Choose focus areas, write an optional note, and share the '
                  'link anywhere — WhatsApp status, group chats, your bio.',
                  style: AppTheme.body(
                      size: 13, color: AppTheme.ink300, height: 1.5),
                ),
              ],
            ),
          ).entrance(++i),
          if (active.isNotEmpty) ...[
            const SizedBox(height: 22),
            SectionLabel('Your active campaigns').entrance(++i),
            ...active.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CampaignCard(
                    campaign: c,
                    onShare: () =>
                        _shareSheet('${K.webBase}/r/${c.id}',
                            customMessage: c.message),
                    onClose: () async {
                      await ref.read(repoProvider).closeCampaign(c.id);
                    },
                  ).entrance(++i),
                )),
          ],
          const SizedBox(height: 22),
          SectionLabel('Focus areas').entrance(++i),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FeedbackDimension.all.map((d) {
              final sel = _dims.contains(d.key);
              return TagChip(
                label: d.label,
                selected: sel,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(
                      () => sel ? _dims.remove(d.key) : _dims.add(d.key));
                },
              );
            }).toList(),
          ).entrance(++i),
          const SizedBox(height: 22),
          SectionLabel('Personal message').entrance(++i),
          TextField(
            controller: _msgCtrl,
            maxLength: 200,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText:
                  'e.g. "I would love your take on my communication style."',
            ),
          ).entrance(++i),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loading ? null : _launch,
            icon: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.ink950))
                : const Icon(Icons.send_outlined, size: 19),
            label: const Text('Generate & share link'),
          ).entrance(++i),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final FeedbackRequest campaign;
  final VoidCallback onShare;
  final VoidCallback onClose;
  const _CampaignCard({
    required this.campaign,
    required this.onShare,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return WallCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_outlined,
                  color: AppTheme.clay, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  campaign.message ?? 'Open feedback request',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: AppTheme.paper),
                ),
              ),
              Text(
                '${campaign.responseCount} ${campaign.responseCount == 1 ? "reply" : "replies"}',
                style: AppTheme.body(
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: AppTheme.sage),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.ios_share_rounded, size: 16),
                label: const Text('Share again'),
              ),
              const Spacer(),
              TextButton(
                onPressed: onClose,
                child: Text('Close',
                    style: AppTheme.body(
                        size: 13, color: AppTheme.rose)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
