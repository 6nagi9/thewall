import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/repositories.dart';
import 'features/auth/login_screen.dart';
import 'features/onboarding/consent_screen.dart';
import 'features/shell/home_shell.dart';

/// Routing driven by auth + onboarding state.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);
      final userAsync = ref.read(appUserProvider);

      // While auth is resolving, stay put.
      if (authAsync.isLoading) return null;

      final signedIn = authAsync.value != null;
      final loc = state.matchedLocation;

      if (!signedIn) return loc == '/login' ? null : '/login';

      // Signed in but profile/consent not complete -> onboarding.
      final user = userAsync.value;
      final onboarded = user?.onboarded ?? false;
      if (!onboarded) return loc == '/onboarding' ? null : '/onboarding';

      // Fully onboarded: keep out of auth/onboarding routes.
      if (loc == '/login' || loc == '/onboarding') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const ConsentScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeShell()),
    ],
  );
});
