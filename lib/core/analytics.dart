import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Analytics singleton.
final analyticsProvider =
    Provider<FirebaseAnalytics>((_) => FirebaseAnalytics.instance);

/// Navigation observer that logs screen views automatically.
final analyticsObserverProvider = Provider<FirebaseAnalyticsObserver>(
  (ref) => FirebaseAnalyticsObserver(analytics: ref.watch(analyticsProvider)),
);

/// Thin wrapper so feature code can log domain events without importing Firebase
/// directly. Names follow snake_case per the GA4 event convention.
class Analytics {
  final FirebaseAnalytics _a;
  const Analytics(this._a);

  Future<void> log(String name, [Map<String, Object>? params]) =>
      _a.logEvent(name: name, parameters: params);

  Future<void> reviewSubmitted({required bool escrowed}) =>
      log('review_submitted', {'escrowed': escrowed.toString()});
  Future<void> wallClaimed() => log('wall_claimed');
  Future<void> disclosureToggled(bool disclosed) =>
      log('disclosure_toggled', {'disclosed': disclosed.toString()});
  Future<void> premiumViewed() => log('premium_viewed');
  Future<void> purchaseCompleted(String productId) =>
      log('purchase_completed', {'product_id': productId});
  Future<void> campaignCreated() => log('campaign_created');

  // ── Growth + product surfaces ────────────────────────────────────────
  Future<void> inviteShared(String channel) =>
      log('invite_shared', {'channel': channel});
  Future<void> circleCreated() => log('circle_created');
  Future<void> circleJoined() => log('circle_joined');
  Future<void> wrappedShared() => log('wrapped_shared');
  Future<void> wallPublished(bool published) =>
      log('wall_published', {'published': published.toString()});
  Future<void> aiSummaryGenerated() => log('ai_summary_generated');
  Future<void> selfAssessmentSaved() => log('self_assessment_saved');

  /// In-app feedback to the team (suggestion / bug / praise / other).
  Future<void> appFeedbackSent(String category) =>
      log('app_feedback_sent', {'category': category});
  Future<void> appReviewRequested() => log('app_review_requested');
}

final appAnalyticsProvider =
    Provider<Analytics>((ref) => Analytics(ref.watch(analyticsProvider)));
