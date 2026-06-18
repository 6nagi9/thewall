import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import 'analytics.dart';
import 'prefs.dart';

/// Store-review prompting, throttled to respect Apple/Google guidelines:
/// the native review sheet should appear rarely and only after a genuinely
/// positive moment (receiving feedback, earning a badge, sending praise).
///
/// Hard limits, regardless of how many positive moments occur:
///   • never within [_minIntervalDays] of the last prompt
///   • at most [_maxPrompts] times, ever
///   • only after [_positiveMomentsBeforeFirst] positive moments (unless forced)
final appReviewProvider = Provider<AppReview>((ref) => const AppReview());

class AppReview {
  const AppReview();

  static const _kLastAskedMs = 'review_last_asked_ms';
  static const _kAskedCount = 'review_asked_count';
  static const _kPositiveMoments = 'review_positive_moments';

  static const _minIntervalDays = 60;
  static const _maxPrompts = 3;
  static const _positiveMomentsBeforeFirst = 3;

  /// Record a positive moment and, if the thresholds allow, show the native
  /// review sheet. [force] skips the positive-moment count (e.g. user just sent
  /// praise) but still honours the hard interval + max-count limits.
  Future<void> maybeAsk(WidgetRef ref, {bool force = false}) async {
    final prefs = ref.read(sharedPrefsProvider);

    final asked = prefs.getInt(_kAskedCount) ?? 0;
    if (asked >= _maxPrompts) return;

    final lastMs = prefs.getInt(_kLastAskedMs) ?? 0;
    final daysSince =
        (DateTime.now().millisecondsSinceEpoch - lastMs) / 86_400_000;
    if (lastMs != 0 && daysSince < _minIntervalDays) return;

    if (!force) {
      final moments = (prefs.getInt(_kPositiveMoments) ?? 0) + 1;
      await prefs.setInt(_kPositiveMoments, moments);
      if (moments < _positiveMomentsBeforeFirst) return;
    }

    try {
      final inAppReview = InAppReview.instance;
      if (!await inAppReview.isAvailable()) return;
      await inAppReview.requestReview();
      await prefs.setInt(
          _kLastAskedMs, DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt(_kAskedCount, asked + 1);
      ref.read(appAnalyticsProvider).appReviewRequested();
    } catch (_) {
      // Review sheet is best-effort; never surface an error.
    }
  }

  /// Open the store listing directly (e.g. from a "Rate us" settings row).
  Future<void> openStoreListing() async {
    try {
      await InAppReview.instance.openStoreListing();
    } catch (_) {}
  }
}
