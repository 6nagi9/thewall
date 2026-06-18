import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_gate.dart';
import 'core/prefs.dart';
import 'core/remote_config.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'router.dart';
import 'shared/error_view.dart';

/// Global messenger so FCM foreground messages can surface an in-app banner
/// from outside the widget tree.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Set true to run the app against the local Firebase Emulator Suite
/// (`firebase emulators:start`). Lets the full flow be tested with no cloud
/// project and no billing.
const bool useEmulator =
    bool.fromEnvironment('USE_EMULATOR', defaultValue: false);

Future<void> main() async {
  // runZonedGuarded catches async errors outside the Flutter framework and
  // routes them to Crashlytics alongside FlutterError/PlatformDispatcher.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final prefs = await SharedPreferences.getInstance();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // App Check — protects callable Functions/Firestore from abuse. Debug
      // provider locally; attestation providers in release builds.
      await FirebaseAppCheck.instance.activate(
        providerAndroid:
            kDebugMode ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
        providerApple:
            kDebugMode ? AppleDebugProvider() : AppleAppAttestProvider(),
      );

      if (useEmulator) {
        const host = 'localhost';
        await FirebaseAuth.instance.useAuthEmulator(host, 9099);
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
        FirebaseFunctions.instanceFor(region: 'asia-south1')
            .useFunctionsEmulator(host, 5001);
      }

      // Crash reporting — disabled on the emulator/debug to avoid noise.
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode && !useEmulator);
      FlutterError.onError = (details) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        if (kDebugMode) FlutterError.presentError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      // Analytics — first-open / engagement baseline.
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
          !kDebugMode && !useEmulator);

      _initFcm();

      // Remote Config — growth levers (invite copy A/B, event flags).
      // Non-blocking with safe defaults.
      unawaited(initRemoteConfig());
    } catch (e, st) {
      // Allows the UI shell to load even before a real Firebase project is
      // wired; never let bootstrap failure white-screen the app.
      debugPrint('Firebase init skipped/failed: $e');
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
      }
    }

    // Friendly error widget in release instead of the grey/red crash box.
    if (!kDebugMode) {
      ErrorWidget.builder = (details) => const AppErrorView();
    }

    runApp(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const WallApp(),
      ),
    );
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

/// Requests notification permission and keeps the FCM token in sync with
/// Firestore so Cloud Functions can deliver push notifications.
///
/// Every FCM call is individually guarded: `getToken()` legitimately fails
/// with `SERVICE_NOT_AVAILABLE` on emulators and devices with stale/absent
/// Google Play Services, and on iOS Simulators without a configured APNS
/// token. Those are environmental, never fatal — push simply stays off for
/// that session, and the rest of the app must keep working.
void _initFcm() {
  final messaging = FirebaseMessaging.instance;

  Future<void> saveToken(String? token) async {
    if (token == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // re-synced on the next onTokenRefresh after login
    try {
      // `update` (not set+merge) so this never violates the users/{uid}
      // create rule, which only permits the onboarding field set.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': token});
    } catch (_) {
      // Doc may not exist yet (pre-onboarding) — harmless.
    }
  }

  // Permission + token fetch run in a guarded zone so a rejected Future never
  // escapes as an unhandled async error (which the debugger pauses on).
  () async {
    try {
      await messaging.requestPermission(provisional: true);
    } catch (e) {
      debugPrint('FCM requestPermission skipped: $e');
    }
    try {
      await saveToken(await messaging.getToken());
    } catch (e) {
      debugPrint('FCM getToken unavailable (push disabled this session): $e');
    }
  }();

  messaging.onTokenRefresh.listen(
    saveToken,
    onError: (Object e) =>
        debugPrint('FCM token refresh error (ignored): $e'),
  );

  // The first getToken() above runs before auth resolves, so its token is
  // dropped (no user yet). Re-fetch and persist whenever a user signs in —
  // without this the token never reaches Firestore and no push can be sent.
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user == null) return;
    try {
      await saveToken(await messaging.getToken());
    } catch (e) {
      debugPrint('FCM getToken on sign-in unavailable: $e');
    }
  });

  // Foreground messages: surface as an in-app banner (OS notifications only
  // show in background). Keeps streak-risk / campaign pushes visible mid-use.
  FirebaseMessaging.onMessage.listen((message) {
    final n = message.notification;
    if (n == null) return;
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      content: Text(
        n.body == null ? (n.title ?? '') : '${n.title ?? ''}\n${n.body!}',
      ),
    ));
  });
}

class WallApp extends ConsumerWidget {
  const WallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Known',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Whole-app maintenance / forced-update gate (Remote Config driven).
      builder: (context, child) => AppGate(child: child ?? const SizedBox()),
      routerConfig: router,
    );
  }
}
