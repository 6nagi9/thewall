import 'dart:convert';
import 'package:crypto/crypto.dart';

/// On-device phone hashing for privacy-safe contact mapping.
///
/// Compliance: raw contact numbers are hashed locally and NEVER sent to the
/// server. The server only ever sees these hashes. Note (per plan): a phone
/// hash still "singles out" a person, so it is treated as personal data — it
/// is not a substitute for consent, only for data minimisation.
class PhoneHash {
  /// Normalises a phone number to E.164-ish digits before hashing so the same
  /// number hashes identically across address books.
  static String normalize(String raw, {String defaultCountryCode = '91'}) {
    var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) {
      digits = digits.substring(1);
    } else if (digits.length == 10) {
      // Assume local number — prefix default country code.
      digits = '$defaultCountryCode$digits';
    } else if (digits.startsWith('0')) {
      digits = '$defaultCountryCode${digits.substring(1)}';
    }
    return digits;
  }

  /// SHA-256 of the normalised number. Deterministic across devices.
  static String of(String raw, {String defaultCountryCode = '91'}) {
    final normalized = normalize(raw, defaultCountryCode: defaultCountryCode);
    return sha256.convert(utf8.encode(normalized)).toString();
  }
}
