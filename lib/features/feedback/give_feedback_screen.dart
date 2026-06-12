import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/moderation.dart';
import '../../core/phone_hash.dart';
import '../../core/remote_config.dart';
import '../../core/share_helpers.dart';
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
      builder: (_) => ComposeFeedbackScreen(
        targetName:
            _nameCtrl.text.trim().isEmpty ? phone : _nameCtrl.text.trim(),
        targetPhoneHash: PhoneHash.of(phone),
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

  bool get _isFriday => DateTime.now().weekday == DateTime.friday;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    final given = user?.giveToGetCount ?? 0;
    final cleared = user?.gateCleared ?? false;
    final friday = _isFriday &&
        ref
                .watch(remoteConfigProvider)
                .getBool(RemoteConfigKeys.feedbackFridayEnabled) !=
            false;
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
            if (friday) ...[
              WallCard(
                borderColor: AppTheme.flame.withValues(alpha: 0.45),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.flame.withValues(alpha: 0.12),
                    AppTheme.ink850,
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: AppTheme.flame),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Feedback Friday — double contribution points on every brick today!',
                        style: AppTheme.body(
                            size: 13.5,
                            weight: FontWeight.w600,
                            color: AppTheme.paper),
                      ),
                    ),
                  ],
                ),
              ).entrance(++i),
              const SizedBox(height: 14),
            ],
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
                        : 'Every brick you lay unlocks one waiting for you. ${K.giveToGetThreshold - given} more opens your full wall.',
                    style: AppTheme.body(
                        size: 12.5, color: AppTheme.ink400, height: 1.5),
                  ),
                ],
              ),
            ).entrance(++i),
            if ((user?.inviteJoins ?? 0) > 0) ...[
              const SizedBox(height: 14),
              WallCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard_rounded,
                        color: AppTheme.sage),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${user!.inviteJoins} ${user.inviteJoins == 1 ? "person" : "people"} joined from your invites — each one earned you 7 days of Premium.',
                        style: AppTheme.body(
                            size: 13, color: AppTheme.ink300, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ).entrance(++i),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Compose feedback ─────────────────────────────────────────────────────────

/// Context-first compose flow. Also reachable from a campaign deep link
/// (pass [campaign]) — then the target is the campaign owner and no phone
/// number ever changes hands.
class ComposeFeedbackScreen extends ConsumerStatefulWidget {
  final String targetName;
  final String targetPhoneHash;
  final FeedbackRequest? campaign;
  const ComposeFeedbackScreen({
    super.key,
    required this.targetName,
    required this.targetPhoneHash,
    this.campaign,
  });
  @override
  ConsumerState<ComposeFeedbackScreen> createState() =>
      _ComposeFeedbackScreenState();
}

class _ComposeFeedbackScreenState extends ConsumerState<ComposeFeedbackScreen> {
  FeedbackContext? _ctx;
  final Map<String, int> _dims = {};
  final Set<String> _tags = {};
  final Set<String> _growthTags = {};
  final _commentCtrl = TextEditingController();
  bool _anonymous = false;
  String? _commentError;
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _selectContext(FeedbackContext c) {
    HapticFeedback.selectionClick();
    setState(() {
      _ctx = c;
      _dims
        ..clear()
        ..addEntries(c.dimensions.map((d) => MapEntry(d.key, 3)));
      _tags.clear();
    });
  }

  void _onCommentChanged(String v) =>
      setState(() => _commentError = ClientModeration.check(v));

  Future<void> _submit() async {
    if (_ctx == null || _commentError != null) return;
    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    final draft = FeedbackDraft(
      targetPhoneHash: widget.targetPhoneHash,
      dimensions: _dims,
      tags: _tags.toList(),
      growthTags: _growthTags.toList(),
      comment: _commentCtrl.text.trim().isEmpty
          ? null
          : _commentCtrl.text.trim(),
      anonymous: _anonymous,
      contextTag: _ctx!.tag,
      campaignId: widget.campaign?.id,
    );
    try {
      final res = await ref.read(repoProvider).submitReview(draft);
      if (!mounted) return;
      if (res.ok && res.escrowed) {
        await _sendInvite(res.shareText);
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

  /// Escrow path: offer WhatsApp-first invite with the server's tease copy
  /// (falls back to the Remote Config template).
  Future<void> _sendInvite(String? serverShareText) async {
    final link = '${K.webBase}/i/${widget.targetPhoneHash}';
    final me = ref.read(appUserProvider).value;
    final count = _tags.length + (_commentCtrl.text.trim().isEmpty ? 0 : 1);
    final text = serverShareText ??
        renderTemplate(
          ref
              .read(remoteConfigProvider)
              .getString(RemoteConfigKeys.inviteTemplate),
          name: _anonymous ? null : me?.displayName,
          count: count,
          link: link,
        );

    if (!mounted) return;
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
              Text('Your feedback is in escrow',
                  style: AppTheme.display(size: 20)),
              const SizedBox(height: 8),
              Text(
                '${widget.targetName} isn\'t on The Wall yet. It unlocks the '
                'moment they join — send them the link:',
                style: AppTheme.body(
                    size: 13.5, color: AppTheme.ink300, height: 1.5),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetCtx);
                  await shareViaWhatsApp(text);
                },
                icon: const Icon(Icons.chat_rounded, size: 19),
                label: const Text('Share on WhatsApp'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetCtx);
                  await shareText(text, subject: 'The Wall');
                },
                icon: const Icon(Icons.ios_share_rounded, size: 19),
                label: const Text('More options'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    var i = 0;
    final ctx = _ctx;
    return Scaffold(
      appBar: AppBar(title: Text('For ${widget.targetName}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          if (widget.campaign?.message != null) ...[
            WallCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                '“${widget.campaign!.message}”',
                style: AppTheme.body(
                    size: 13.5, color: AppTheme.ink200, height: 1.5),
              ),
            ).entrance(i),
            const SizedBox(height: 16),
          ],
          SectionLabel('How do you know them?').entrance(++i),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FeedbackContext.all
                .map((c) => TagChip(
                      label: '${c.emoji} ${c.label}',
                      selected: ctx?.tag == c.tag,
                      accent: AppTheme.gold,
                      onTap: () => _selectContext(c),
                    ))
                .toList(),
          ).entrance(++i),
          if (ctx == null) ...[
            const SizedBox(height: 28),
            Text(
              'Pick a context first — the questions adapt to how you know them.',
              style: AppTheme.body(
                  size: 13, color: AppTheme.ink400, height: 1.5),
              textAlign: TextAlign.center,
            ).entrance(++i),
          ] else ...[
            const SizedBox(height: 22),
            Text(
              'Rate honestly — they\'ll see patterns, not your individual scores.',
              style: AppTheme.body(
                  size: 13, color: AppTheme.ink400, height: 1.5),
            ).entrance(++i),
            const SizedBox(height: 14),
            for (final d in ctx.dimensions) ...[
              _DimRating(
                dim: d,
                value: _dims[d.key] ?? 3,
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
              children: ctx.tags.map((t) {
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
            SectionLabel('Room to grow (optional, max ${K.maxGrowthTags})')
                .entrance(++i),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GrowthTags.all.map((t) {
                final sel = _growthTags.contains(t);
                return TagChip(
                  label: t,
                  selected: sel,
                  accent: AppTheme.rose,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (sel) {
                        _growthTags.remove(t);
                      } else if (_growthTags.length < K.maxGrowthTags) {
                        _growthTags.add(t);
                      }
                    });
                  },
                );
              }).toList(),
            ).entrance(++i),
            const SizedBox(height: 6),
            Text(
              'Growth notes stay private to them — they never appear on a public wall.',
              style: AppTheme.body(size: 11.5, color: AppTheme.ink400),
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
