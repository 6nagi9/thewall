import 'package:flutter_test/flutter_test.dart';
import 'package:wall/core/constants.dart';

void main() {
  group('FeedbackContext', () {
    test('every context has 4 dimensions and at least 6 tags', () {
      for (final c in FeedbackContext.all) {
        expect(c.dimensions.length, 4, reason: '${c.tag} dimensions');
        expect(c.tags.length, greaterThanOrEqualTo(6),
            reason: '${c.tag} tags');
      }
    });

    test('byTag falls back to Work for unknown / null context', () {
      expect(FeedbackContext.byTag(null).tag, 'Work');
      expect(FeedbackContext.byTag('Nope').tag, 'Work');
      expect(FeedbackContext.byTag('Friend').tag, 'Friend');
    });

    test('personal contexts use warmth dimensions, not punctuality', () {
      final friend = FeedbackContext.byTag('Friend');
      final keys = friend.dimensions.map((d) => d.key).toSet();
      expect(keys.contains('punctuality'), isFalse);
      expect(keys.contains('trustworthiness'), isTrue);
    });
  });

  group('FeedbackDimension.byKey', () {
    test('resolves labels across all context sets', () {
      expect(FeedbackDimension.byKey('punctuality').label, 'Punctuality');
      expect(FeedbackDimension.byKey('fun').label, 'Fun to be around');
      expect(FeedbackDimension.byKey('caring').label, 'Caring');
    });

    test('unknown key degrades to the raw key as a label', () {
      expect(FeedbackDimension.byKey('mystery').label, 'mystery');
    });
  });

  group('GrowthTags', () {
    test('are all constructively framed and bounded', () {
      expect(GrowthTags.all, isNotEmpty);
      expect(K.maxGrowthTags, 2);
    });
  });

  test('ContextTag.all mirrors the contexts', () {
    expect(ContextTag.all, contains('Friend'));
    expect(ContextTag.all, contains('Work'));
    expect(ContextTag.all.length, FeedbackContext.all.length);
  });
}
