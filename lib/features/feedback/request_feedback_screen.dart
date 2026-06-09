import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/repositories.dart';

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
    setState(() => _loading = true);
    try {
      final result = await ref.read(repoProvider).requestFeedback(
            message: _msgCtrl.text.trim().isEmpty
                ? null
                : _msgCtrl.text.trim(),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Request Feedback')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Ask for feedback that matters to you.',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Choose which areas to focus on, write an optional personal '
                    'message, and share the campaign link with people you trust. '
                    'Only people who have joined The Wall can respond.',
                    style: TextStyle(
                        color: AppTheme.slate300, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Focus areas',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: FeedbackDimension.all.map((d) {
              final sel = _dims.contains(d.key);
              return FilterChip(
                label: Text(d.label),
                selected: sel,
                onSelected: (v) => setState(
                    () => v ? _dims.add(d.key) : _dims.remove(d.key)),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _msgCtrl,
            maxLength: 200,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Personal message (optional)',
              hintText:
                  'e.g. "I would love your take on my communication style."',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loading ? null : _launch,
            icon: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.slate900))
                : const Icon(Icons.send_outlined),
            label: const Text('Generate & share campaign link'),
          ),
        ],
      ),
    );
  }
}
