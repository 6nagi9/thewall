import 'package:flutter_test/flutter_test.dart';
import 'package:wall/core/moderation.dart';

void main() {
  group('ClientModeration (Layer 1)', () {
    test('constructive feedback passes', () {
      expect(
        ClientModeration.isClean('Great communication and very reliable'),
        isTrue,
      );
      expect(ClientModeration.check('Punctual and professional'), isNull);
    });

    test('a blocklisted term is rejected with an explanatory reason', () {
      expect(ClientModeration.isClean('you idiot'), isFalse);
      expect(ClientModeration.check('you idiot'), contains('idiot'));
    });

    test('matching is case-insensitive', () {
      expect(ClientModeration.isClean('You STUPID person'), isFalse);
    });

    test('empty text is clean', () {
      expect(ClientModeration.isClean(''), isTrue);
    });
  });
}
