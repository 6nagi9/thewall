import 'package:flutter_test/flutter_test.dart';
import 'package:wall/core/phone_hash.dart';

void main() {
  group('PhoneHash.normalize', () {
    test('strips formatting and prefixes default country code for 10 digits',
        () {
      expect(PhoneHash.normalize('98765 43210'), '919876543210');
    });

    test('handles an explicit +country prefix', () {
      expect(PhoneHash.normalize('+91 98765 43210'), '919876543210');
    });

    test('handles a leading national 0', () {
      expect(PhoneHash.normalize('098765 43210'), '919876543210');
    });

    test('all common formats of the same number normalize identically', () {
      final a = PhoneHash.normalize('+91-98765-43210');
      final b = PhoneHash.normalize('98765 43210');
      final c = PhoneHash.normalize('098765-43210');
      expect(a, b);
      expect(b, c);
    });
  });

  group('PhoneHash.of', () {
    test('is deterministic across calls', () {
      expect(PhoneHash.of('9876543210'), PhoneHash.of('9876543210'));
    });

    test('same number in different formats yields the same hash', () {
      expect(PhoneHash.of('+91 9876543210'), PhoneHash.of('9876543210'));
    });

    test('different numbers yield different hashes', () {
      expect(PhoneHash.of('9876543210') == PhoneHash.of('9876543211'), isFalse);
    });

    test('produces a 64-character SHA-256 hex digest', () {
      expect(PhoneHash.of('9876543210').length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(PhoneHash.of('9876543210')),
          isTrue);
    });
  });
}
