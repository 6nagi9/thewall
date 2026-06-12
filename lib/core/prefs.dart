import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides the [SharedPreferences] instance. Overridden in `main()` after async
/// init so the rest of the app (router, screens) can read prefs synchronously.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
      'sharedPrefsProvider must be overridden in main()'),
);

const String _kSeenWalkthrough = 'seen_walkthrough';

/// Whether the user has finished the intro walkthrough. First launch → false.
/// Flipping this triggers the router's refresh listenable to redirect onward.
final walkthroughSeenProvider =
    NotifierProvider<WalkthroughSeenNotifier, bool>(
        WalkthroughSeenNotifier.new);

class WalkthroughSeenNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPrefsProvider).getBool(_kSeenWalkthrough) ?? false;

  /// Persist completion and flip state so the router redirects to login.
  Future<void> markSeen() async {
    await ref.read(sharedPrefsProvider).setBool(_kSeenWalkthrough, true);
    state = true;
  }
}

const String _kPendingDeepLink = 'pending_deep_link';

/// A deep link (/i/…, /r/…, /c/…) that arrived before the user was signed in
/// and onboarded. Persisted so the invite survives the install→OTP→consent
/// journey; replayed by the router right after onboarding completes.
final pendingDeepLinkProvider =
    NotifierProvider<PendingDeepLinkNotifier, String?>(
        PendingDeepLinkNotifier.new);

class PendingDeepLinkNotifier extends Notifier<String?> {
  @override
  String? build() => ref.watch(sharedPrefsProvider).getString(_kPendingDeepLink);

  Future<void> save(String path) async {
    await ref.read(sharedPrefsProvider).setString(_kPendingDeepLink, path);
    state = path;
  }

  Future<void> clear() async {
    await ref.read(sharedPrefsProvider).remove(_kPendingDeepLink);
    state = null;
  }
}
