import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../shared/wall_ui.dart';

/// B1 — Feedback campaigns: the owner solicits targeted feedback from
/// specific people. Fully consent-forward and DPDP-ideal (owner initiates).
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
      final link = result['link'] as String? ?? 'https://thewall.app';
      final msg = _msgCtrl.text.trim().isEmpty
          ? "I'd love your honest feedback. Join me on The Wall: $link"
          : '${_msgCtrl.text.trim()}\n\nJoin here: $link';
      await SharePlus.instance.share(ShareParams(
        text: msg,
        subject: 'Feedback request — The Wall',
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    var i = 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Request feedback')),
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
                  'link with people you trust. Only members of The Wall can respond.',
                  style: AppTheme.body(
                      size: 13, color: AppTheme.ink300, height: 1.5),
                ),
              ],
            ),
          ).entrance(++i),
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
