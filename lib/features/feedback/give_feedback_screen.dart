import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/moderation.dart';
import '../../core/phone_hash.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../shared/wall_ui.dart';

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
    HapticFeedback.lightImpact();
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
    final given = user?.giveToGetCount ?? 0;
    final cleared = user?.gateCleared ?? false;
    var i = 0;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          children: [
            const ScreenHeader(
              kicker: 'Lay a brick',
              title: 'Give feedback',
            ),
            WallCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Who is it for?', style: AppTheme.display(size: 18)),
                  const SizedBox(height: 5),
                  Text(
                    'Only people you actually know — pick a contact or enter their number.',
                    style: AppTheme.body(
                        size: 13, color: AppTheme.ink400, height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _open,
                          child: const Text('Continue'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: _pickFromContacts,
                          icon: const Icon(Icons.contacts_outlined,
                              size: 18),
                          label: const Text('Contacts'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).entrance(++i),
            const SizedBox(height: 14),
            WallCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        cleared
                            ? Icons.celebration_outlined
                            : Icons.bolt_rounded,
                        color: cleared ? AppTheme.sage : AppTheme.gold,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cleared ? 'Wall unlocked' : 'Building your wall',
                        style: AppTheme.body(
                            size: 14.5,
                            weight: FontWeight.w700,
                            color: AppTheme.paper),
                      ),
                      const Spacer(),
                      Text(
                        '$given/${K.giveToGetThreshold}',
                        style: AppTheme.display(
                            size: 16, color: AppTheme.clay),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  BrickProgress(
                      filled: given.clamp(0, K.giveToGetThreshold),
                      total: K.giveToGetThreshold),
                  const SizedBox(height: 10),
                  Text(
                    cleared
                        ? 'You can see everything on your wall. Keep giving — honest feedback keeps the community alive.'
                        : 'Each brick you lay for others builds your own wall. ${K.giveToGetThreshold - given} to go.',
                    style: AppTheme.body(
                        size: 12.5, color: AppTheme.ink400, height: 1.5),
                  ),
                ],
              ),
            ).entrance(++i),
          ],
        ),
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
    HapticFeedback.mediumImpact();
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
        await _celebrate();
      } else {
        _toast(res.reason ?? 'Feedback was rejected by moderation.');
      }
    } catch (e) {
      _toast('Could not submit: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Full-screen "brick laid" moment before popping back.
  Future<void> _celebrate() async {
    HapticFeedback.heavyImpact();
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'done',
      barrierColor: AppTheme.ink950.withValues(alpha: 0.92),
      transitionDuration: WallMotion.med,
      pageBuilder: (context, anim, secondary) => _BrickLaidOverlay(
        name: widget.targetName,
      ),
      transitionBuilder: (context, anim, secondary, child) =>
          FadeTransition(opacity: anim, child: child),
    );
    if (mounted) Navigator.pop(context);
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
    var i = 0;
    return Scaffold(
      appBar: AppBar(title: Text('For ${widget.targetName}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(
            'Rate honestly — they\'ll see patterns, not your individual scores.',
            style: AppTheme.body(
                size: 13, color: AppTheme.ink400, height: 1.5),
          ).entrance(i),
          const SizedBox(height: 18),
          for (final d in FeedbackDimension.all) ...[
            _DimRating(
              dim: d,
              value: _dims[d.key]!,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _dims[d.key] = v);
              },
            ).entrance(++i),
            const SizedBox(height: 18),
          ],
          SectionLabel('What stands out about them?').entrance(++i),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FeedbackTags.all.map((t) {
              final sel = _tags.contains(t);
              return TagChip(
                label: t,
                selected: sel,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => sel ? _tags.remove(t) : _tags.add(t));
                },
              );
            }).toList(),
          ).entrance(++i),
          const SizedBox(height: 22),
          SectionLabel('How do you know them?').entrance(++i),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ContextTag.all
                .map((c) => TagChip(
                      label: c,
                      selected: _context == c,
                      accent: AppTheme.gold,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(
                            () => _context = _context == c ? null : c);
                      },
                    ))
                .toList(),
          ).entrance(++i),
          const SizedBox(height: 22),
          SectionLabel('In your own words').entrance(++i),
          TextField(
            controller: _commentCtrl,
            maxLength: K.maxCommentLength,
            maxLines: 4,
            onChanged: _onCommentChanged,
            decoration: InputDecoration(
              hintText:
                  'Be specific and kind — framed as your own experience.',
              errorText: _commentError,
            ),
          ).entrance(++i),
          const SizedBox(height: 6),
          WallCard(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _anonymous,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _anonymous = v);
              },
              title: Text('Stay anonymous to them',
                  style: AppTheme.body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppTheme.paper)),
              subtitle: Text(
                'Only applies once they\'ve joined. Invites you send by SMS reveal your number.',
                style:
                    AppTheme.body(size: 11.5, color: AppTheme.ink400),
              ),
            ),
          ).entrance(++i),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed:
                (_commentError == null && !_submitting) ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.ink950))
                : const Text('Lay this brick'),
          ).entrance(++i),
        ],
      ),
    );
  }
}

// ─── Dimension rating (tappable bricks, not sliders) ─────────────────────────

class _DimRating extends StatelessWidget {
  final FeedbackDimension dim;
  final int value;
  final ValueChanged<int> onChanged;
  const _DimRating(
      {required this.dim, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => WallCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(dim.label,
                    style: AppTheme.body(
                        size: 14.5,
                        weight: FontWeight.w700,
                        color: AppTheme.paper)),
                const Spacer(),
                AnimatedSwitcher(
                  duration: WallMotion.fast,
                  transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child)),
                  child: Text(
                    '$value/5',
                    key: ValueKey(value),
                    style: AppTheme.display(
                        size: 16, color: AppTheme.clay),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RatingBricks(value: value, onChanged: onChanged),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dim.lowLabel,
                    style: AppTheme.body(
                        size: 11, color: AppTheme.ink400)),
                Text(dim.highLabel,
                    style: AppTheme.body(
                        size: 11, color: AppTheme.ink400)),
              ],
            ),
          ],
        ),
      );
}

// ─── Brick laid celebration ───────────────────────────────────────────────────

class _BrickLaidOverlay extends StatelessWidget {
  final String name;
  const _BrickLaidOverlay({required this.name});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.clayBright, AppTheme.clayDeep],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.clay.withValues(alpha: .45),
                      blurRadius: 40,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppTheme.ink950, size: 48),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.3, 0.3),
                    end: const Offset(1, 1),
                    duration: WallMotion.slow,
                    curve: WallMotion.spring,
                  )
                  .then()
                  .shake(hz: 3, rotation: 0.015, duration: 300.ms),
              const SizedBox(height: 24),
              Text('Brick laid',
                      style: AppTheme.display(size: 26))
                  .animate()
                  .fadeIn(delay: 250.ms, duration: WallMotion.med)
                  .slideY(begin: 0.2, end: 0, delay: 250.ms),
              const SizedBox(height: 8),
              Text(
                'Your feedback is on its way to $name.',
                style: AppTheme.body(size: 14, color: AppTheme.ink300),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: WallMotion.med),
              const SizedBox(height: 28),
              Text('Tap anywhere to continue',
                      style: AppTheme.body(
                          size: 12, color: AppTheme.ink400))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fade(begin: 0.4, end: 1, duration: 900.ms),
            ],
          ),
        ),
      ),
    );
  }
}
