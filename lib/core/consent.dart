import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs.dart';

/// SharedPreferences key for the analytics/crash-reporting consent decision.
/// Read synchronously in `main()` before any telemetry is enabled.
const String kAnalyticsConsentKey = 'analytics_consent';

/// Whether the user has consented to pseudonymised analytics & crash reporting.
///
/// Defaults to **false** — no telemetry is collected until the user consents at
/// the consent screen. This is what makes the "GDPR/ePrivacy: prior consent"
/// and "CCPA: opt-out honoured" claims true: collection is off at first launch
/// and stays off if the user later toggles it off in Settings.
final analyticsConsentProvider =
    NotifierProvider<AnalyticsConsentNotifier, bool>(
        AnalyticsConsentNotifier.new);

class AnalyticsConsentNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPrefsProvider).getBool(kAnalyticsConsentKey) ?? false;

  /// Persist the decision, flip state, and push it into the Firebase SDKs live.
  Future<void> set(bool value) async {
    await ref.read(sharedPrefsProvider).setBool(kAnalyticsConsentKey, value);
    state = value;
    await applyAnalyticsConsent(value);
  }
}

/// Push the consent decision into the Firebase Analytics & Crashlytics SDKs.
/// No-op in debug builds (we never collect from developer devices).
Future<void> applyAnalyticsConsent(bool granted) async {
  if (kDebugMode) return;
  try {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(granted);
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(granted);
  } catch (_) {
    // Telemetry must never break the app; a failed toggle simply leaves the
    // previous collection state in place.
  }
}
