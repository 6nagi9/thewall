import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../shared/error_view.dart';
import '../../shared/wall_ui.dart';
import 'give_feedback_screen.dart';

/// Deep-link target for campaign links (/r/{campaignId}): loads the campaign
/// and opens the compose flow aimed at the owner — no phone numbers change
/// hands, which is what makes the link safely shareable in public.
class CampaignRespondScreen extends ConsumerStatefulWidget {
  final String campaignId;
  const CampaignRespondScreen({super.key, required this.campaignId});

  @override
  ConsumerState<CampaignRespondScreen> createState() =>
      _CampaignRespondScreenState();
}

class _CampaignRespondScreenState
    extends ConsumerState<CampaignRespondScreen> {
  FeedbackRequest? _campaign;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await ref.read(repoProvider).getCampaign(widget.campaignId);
      if (!mounted) return;
      if (c == null || c.status != 'active' || c.ownerPhoneHash == null) {
        setState(() {
          _error = 'This feedback request is no longer open.';
          _loading = false;
        });
        return;
      }
      final me = ref.read(appUserProvider).value;
      if (me != null && me.uid == c.ownerUid) {
        setState(() {
          _error = "That's your own campaign — share it with others instead.";
          _loading = false;
        });
        return;
      }
      setState(() {
        _campaign = c;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load this request: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: WallLoader());
    }
    if (_error != null || _campaign == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Feedback request')),
        body: InlineError(message: _error ?? 'Not found.'),
      );
    }
    final c = _campaign!;
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback request')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          WallCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c.ownerName ?? "Someone"} wants your honest take',
                    style: AppTheme.display(size: 20)),
                if (c.message != null) ...[
                  const SizedBox(height: 10),
                  Text('“${c.message}”',
                      style: AppTheme.body(
                          size: 14, color: AppTheme.ink200, height: 1.5)),
                ],
                const SizedBox(height: 10),
                Text(
                  'Takes ~2 minutes. You can stay anonymous.',
                  style: AppTheme.body(size: 12.5, color: AppTheme.ink400),
                ),
              ],
            ),
          ).entrance(1),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ComposeFeedbackScreen(
                    targetName: c.ownerName ?? 'them',
                    targetPhoneHash: c.ownerPhoneHash!,
                    campaign: c,
                  ),
                ),
              );
            },
            child: const Text('Give feedback'),
          ).entrance(2),
        ],
      ),
    );
  }
}
