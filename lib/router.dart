import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/analytics.dart';
import 'core/prefs.dart';
import 'data/repositories.dart';
import 'features/auth/login_screen.dart';
import 'features/onboarding/consent_screen.dart';
import 'features/onboarding/walkthrough_screen.dart';
import 'features/shell/home_shell.dart';

/// Routing driven by walkthrough + auth + onboarding state.
///
/// A [ValueNotifier] bridges Riverpod state changes into GoRouter's
/// `refreshListenable`, so the redirect re-runs whenever auth resolves, the
/// user's profile/consent completes, or the walkthrough is finished — without
/// rebuilding the router (which would drop navigation state).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  void bump() => refresh.value++;
  ref.listen(authStateProvider, (_, _) => bump());
  ref.listen(appUserProvider, (_, _) => bump());
  ref.listen(walkthroughSeenProvider, (_, _) => bump());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    observers: [ref.read(analyticsObserverProvider)],
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);

      // While auth is resolving, stay put (avoids a login flash on cold start).
      if (authAsync.isLoading) return null;

      final loc = state.matchedLocation;
      final signedIn = authAsync.value != null;

      if (!signedIn) {
        // First launch: show the intro walkthrough before login.
        final seenWalkthrough = ref.read(walkthroughSeenProvider);
        if (!seenWalkthrough) {
          return loc == '/walkthrough' ? null : '/walkthrough';
        }
        return loc == '/login' ? null : '/login';
      }

      // Signed in but profile/consent not complete -> onboarding.
      final user = ref.read(appUserProvider).value;
      final onboarded = user?.onboarded ?? false;
      if (!onboarded) return loc == '/onboarding' ? null : '/onboarding';

      // Fully onboarded: keep out of pre-auth routes.
      if (loc == '/login' || loc == '/onboarding' || loc == '/walkthrough') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
          path: '/walkthrough', builder: (_, _) => const WalkthroughScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const ConsentScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeShell()),
    ],
  );
});
