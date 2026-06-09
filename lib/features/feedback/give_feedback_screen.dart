import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/moderation.dart';
import '../../core/phone_hash.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';

class GiveFeedbackScreen extends ConsumerStatefulWidget {
  const GiveFeedbackScreen({super.key});
  @override
  ConsumerState<GiveFeedbackScreen> createState() =>
      _GiveFeedbackScreenState();
}

class _GiveFeedbackScreenState extends ConsumerState<GiveFeedbackScreen> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _open() {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ComposeFeedback(
        targetName:
            _nameCtrl.text.trim().isEmpty ? phone : _nameCtrl.text.trim(),
        targetPhone: phone,
      ),
    ));
  }

  Future<void> _pickFromContacts() async {
    try {
      final contact = await ref.read(repoProvider).pickContact();
      if (contact == null || !mounted) return;
      final phones = contact.phones;
      if (phones.isEmpty) {
        _snack('No phone number found for this contact.');
        return;
      }
      final number = phones.first.number;
      if (number.isEmpty) {
        _snack('No phone number found for this contact.');
        return;
      }
      setState(() {
        _nameCtrl.text = contact.displayName ?? '';
        _phoneCtrl.text = number;
      });
    } catch (e) {
      if (mounted) _snack('Could not access contacts: $e');
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Give Feedback')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Who do you want to give feedback to?',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                    'You can only review people you know — pick a contact '
                    'or enter their number.',
                    style: TextStyle(
                        color: AppTheme.slate500, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Their name (optional)',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Their mobile number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                            onPressed: _open,
                            child: const Text('Continue')),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _pickFromContacts,
                        icon: const Icon(Icons.contacts_outlined, size: 18),
                        label: const Text('Contacts'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: AppTheme.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You\'ve given ${user?.giveToGetCount ?? 0}/'
                      '${K.giveToGetThreshold} pieces of feedback. '
                      '${(user?.gateCleared ?? false) ? "Your Wall is unlocked!" : "Reach ${K.giveToGetThreshold} to unlock your Wall."}',
                      style: const TextStyle(color: AppTheme.slate300),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Compose feedback ─────────────────────────────────────────────────────────

class _ComposeFeedback extends ConsumerStatefulWidget {
  final String targetName;
  final String targetPhone;
  const _ComposeFeedback(
      {required this.targetName, required this.targetPhone});
  @override
  ConsumerState<_ComposeFeedback> createState() => _ComposeFeedbackState();
}

class _ComposeFeedbackState extends ConsumerState<_ComposeFeedback> {
  final Map<String, int> _dims = {
    for (final d in FeedbackDimension.all) d.key: 3,
  };
  final Set<String> _tags = {};
  final _commentCtrl = TextEditingController();
  bool _anonymous = false;
  String? _context;
  String? _commentError;
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _onCommentChanged(String v) =>
      setState(() => _commentError = ClientModeration.check(v));

  Future<void> _submit() async {
    if (_commentError != null) return;
    setState(() => _submitting = true);
    final draft = FeedbackDraft(
      targetPhoneHash: PhoneHash.of(widget.targetPhone),
      dimensions: _dims,
      tags: _tags.toList(),
      comment: _commentCtrl.text.trim().isEmpty
          ? null
          : _commentCtrl.text.trim(),
      anonymous: _anonymous,
      contextTag: _context,
    );
    try {
      final res = await ref.read(repoProvider).submitReview(draft);
      if (!mounted) return;
      if (res.ok && res.escrowed) {
        await _sendInvite();
      } else if (res.ok) {
        _toast('Feedback sent to ${widget.targetName}.');
        Navigator.pop(context);
      } else {
        _toast(res.reason ?? 'Feedback was rejected by moderation.');
      }
    } catch (e) {
      _toast('Could not submit: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _sendInvite() async {
    final hash = PhoneHash.of(widget.targetPhone);
    final link = 'https://thewall.app/i/$hash';
    await SharePlus.instance.share(ShareParams(
      text: 'I left you some feedback on The Wall. Join to see it: $link',
      subject: 'The Wall',
    ));
    if (!mounted) return;
    _toast('${widget.targetName} isn\'t on The Wall yet — your feedback is '
        'saved and will unlock when they join.');
    Navigator.pop(context);
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Feedback for ${widget.targetName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final d in FeedbackDimension.all)
            _DimSlider(
              dim: d,
              value: _dims[d.key]!,
              onChanged: (v) => setState(() => _dims[d.key] = v),
            ),
          const SizedBox(height: 8),
          const Text('Tags',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: FeedbackTags.all.map((t) {
              final sel = _tags.contains(t);
              return FilterChip(
                label: Text(t),
                selected: sel,
                onSelected: (v) =>
                    setState(() => v ? _tags.add(t) : _tags.remove(t)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Context',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ContextTag.all.map((c) {
              return ChoiceChip(
                label: Text(c),
                selected: _context == c,
                onSelected: (v) =>
                    setState(() => _context = v ? c : null),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentCtrl,
            maxLength: K.maxCommentLength,
            maxLines: 3,
            onChanged: _onCommentChanged,
            decoration: InputDecoration(
              labelText: 'Constructive comment (optional)',
              hintText:
                  'Be specific and kind — framed as your own experience.',
              errorText: _commentError,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _anonymous,
            onChanged: (v) => setState(() => _anonymous = v),
            title: const Text('Stay anonymous to them'),
            subtitle: const Text(
                'Only applies once they\'ve joined. Invites you send by '
                'SMS reveal your number.',
                style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: (_commentError == null && !_submitting) ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.slate900))
                : const Text('Submit feedback'),
          ),
        ],
      ),
    );
  }
}

// ─── Dimension slider ─────────────────────────────────────────────────────────

class _DimSlider extends StatelessWidget {
  final FeedbackDimension dim;
  final int value;
  final ValueChanged<int> onChanged;
  const _DimSlider(
      {required this.dim, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(dim.label,
                    style:
                        const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('$value/5',
                    style: const TextStyle(color: AppTheme.teal)),
              ],
            ),
            Slider(
              value: value.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$value',
              onChanged: (v) => onChanged(v.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dim.lowLabel,
                    style: const TextStyle(
                        color: AppTheme.slate500, fontSize: 11)),
                Text(dim.highLabel,
                    style: const TextStyle(
                        color: AppTheme.slate500, fontSize: 11)),
              ],
            ),
          ],
        ),
      );
}
