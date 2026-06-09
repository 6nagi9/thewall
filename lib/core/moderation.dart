/// Layer 1 moderation — instant, on-device, zero-latency.
///
/// Checked as-you-type (debounced) so the submit button disables and an inline
/// message shows before any network call. Layer 2 (server moderation API in the
/// `submitReview` Cloud Function) is the authoritative gate.
class ClientModeration {
  // Compact blocklist of slurs / targeted-insult stems. Kept intentionally
  // small here; the authoritative check is server-side. Extend as needed.
  static const List<String> _blocked = [
    'idiot', 'stupid', 'moron', 'loser', 'ugly', 'fool', 'dumb',
    'hate you', 'worthless', 'pathetic', 'disgusting', 'trash',
    'kill', 'die ', 'scum',
  ];

  /// Returns a human-readable rejection reason, or null if the text is clean.
  static String? check(String text) {
    final lower = text.toLowerCase();
    for (final term in _blocked) {
      if (lower.contains(term)) {
        return 'Please keep feedback constructive — "$term" isn\'t allowed.';
      }
    }
    return null;
  }

  static bool isClean(String text) => check(text) == null;
}
