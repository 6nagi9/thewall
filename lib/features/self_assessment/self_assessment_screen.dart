import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../shared/wall_ui.dart';

/// Day-1 single-player value: rate yourself on the dimensions of the
/// contexts that matter to you. When real feedback lands, MyWall shows the
/// "you vs how others see you" gap — compelling even at N=1 received.
class SelfAssessmentScreen extends ConsumerStatefulWidget {
  const SelfAssessmentScreen({super.key});
  @override
  ConsumerState<SelfAssessmentScreen> createState() =>
      _SelfAssessmentScreenState();
}

class _SelfAssessmentScreenState extends ConsumerState<SelfAssessmentScreen> {
  final Set<String> _contexts = {'Friend', 'Work'};
  final Map<String, int> _scores = {};
  bool _saving = false;

  List<FeedbackDimension> get _dims {
    final seen = <String>{};
    final out = <FeedbackDimension>[];
    for (final tag in _contexts) {
      for (final d in FeedbackContext.byTag(tag).dimensions) {
        if (seen.add(d.key)) out.add(d);
      }
    }
    return out;
  }

  Future<void> _save() async {
    final dims = _dims;
    final scores = {
      for (final d in dims) d.key: _scores[d.key] ?? 3,
    };
    setState(() => _saving = true);
    try {
      // Merge with existing scores from the user doc so re-running with a
      // different context set never wipes earlier answers.
      final existing =
          ref.read(appUserProvider).value?.selfScores ?? const <String, int>{};
      await ref.read(repoProvider).saveSelfScores({...existing, ...scores});
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Saved — your wall will show how others compare to your view.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var i = 0;
    return Scaffold(
      appBar: AppBar(title: const Text('How do you see yourself?')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Be honest — nobody else sees these. They power your private '
            '"you vs others" comparison.',
            style:
                AppTheme.body(size: 13, color: AppTheme.ink400, height: 1.5),
          ).entrance(i),
          const SizedBox(height: 20),
          SectionLabel('Which sides of you matter most?').entrance(++i),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FeedbackContext.all
                .map((c) => TagChip(
                      label: '${c.emoji} ${c.label}',
                      selected: _contexts.contains(c.tag),
                      accent: AppTheme.gold,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (_contexts.contains(c.tag)) {
                            if (_contexts.length > 1) _contexts.remove(c.tag);
                          } else {
                            _contexts.add(c.tag);
                          }
                        });
                      },
                    ))
                .toList(),
          ).entrance(++i),
          const SizedBox(height: 24),
          for (final d in _dims) ...[
            WallCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(d.label,
                          style: AppTheme.body(
                              size: 14.5,
                              weight: FontWeight.w700,
                              color: AppTheme.paper)),
                      const Spacer(),
                      Text('${_scores[d.key] ?? 3}/5',
                          style: AppTheme.display(
                              size: 16, color: AppTheme.sage)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RatingBricks(
                    value: _scores[d.key] ?? 3,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _scores[d.key] = v);
                    },
                  ),
                ],
              ),
            ).entrance(++i),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.ink950))
                : const Text('Save my self-view'),
          ).entrance(++i),
        ],
      ),
    );
  }
}
