import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'firebase_options.dart';
import 'router.dart';

/// Set true to run the app against the local Firebase Emulator Suite
/// (`firebase emulators:start`). Lets the full flow be tested with no cloud
/// project and no billing.
const bool useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (useEmulator) {
      const host = 'localhost';
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFunctions.instanceFor(region: 'asia-south1')
          .useFunctionsEmulator(host, 5001);
    }
  } catch (e) {
    // Allows the UI shell to load even before a real Firebase project is wired.
    debugPrint('Firebase init skipped/failed (placeholder config?): $e');
  }
  _initFcm();
  runApp(const ProviderScope(child: WallApp()));
}

/// Requests notification permission and keeps the FCM token in sync with
/// Firestore so Cloud Functions can deliver push notifications.
void _initFcm() {
  final messaging = FirebaseMessaging.instance;
  messaging.requestPermission(provisional: true);

  void saveToken(String? token) {
    if (token == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'fcmToken': token}).catchError((_) {});
  }

  messaging.getToken().then(saveToken);
  messaging.onTokenRefresh.listen(saveToken);

  // Listen while app is in foreground — no-op here; handled by the app UI.
  FirebaseMessaging.onMessage.listen((_) {});
}

class WallApp extends ConsumerWidget {
  const WallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'The Wall',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
