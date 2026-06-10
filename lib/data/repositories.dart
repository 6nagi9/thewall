import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/phone_hash.dart';
import 'models.dart';

// ---- Firebase singletons ----
final firebaseAuthProvider = Provider((_) => FirebaseAuth.instance);
final firestoreProvider = Provider((_) => FirebaseFirestore.instance);
final functionsProvider =
    Provider((_) => FirebaseFunctions.instanceFor(region: 'asia-south1'));

// ---- Auth state ----
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

/// The current user's profile document (users/{uid}), or null when signed out.
final appUserProvider = StreamProvider<AppUser?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(authUser.uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromDoc(doc) : null);
});

/// The current user's own wall (walls/{phoneHash}).
final myWallProvider = StreamProvider<Wall?>((ref) {
  final user = ref.watch(appUserProvider).value;
  if (user == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('walls')
      .doc(user.phoneHash)
      .snapshots()
      .map((doc) =>
          doc.exists ? Wall.fromDoc(doc) : Wall(phoneHash: user.phoneHash));
});

/// The current user's received-feedback inbox.
final receivedFeedbackProvider = StreamProvider<List<ReceivedFeedback>>((ref) {
  final user = ref.watch(appUserProvider).value;
  if (user == null) return Stream.value([]);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .collection('inbox')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ReceivedFeedback.fromDoc).toList());
});

/// The current user's gamification state (badges, streak, scores).
final gamificationProvider = StreamProvider<GamificationState?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('gamification')
      .doc(authUser.uid)
      .snapshots()
      .map((doc) => doc.exists ? GamificationState.fromDoc(doc) : null);
});

/// The current user's feedback campaigns.
final myFeedbackRequestsProvider =
    StreamProvider<List<FeedbackRequest>>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value([]);
  return ref
      .watch(firestoreProvider)
      .collection('feedbackRequests')
      .where('ownerUid', isEqualTo: authUser.uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(FeedbackRequest.fromDoc).toList());
});

/// Repository — all writes go through here; mutating ops call Cloud Functions.
final repoProvider = Provider((ref) => WallRepository(ref));

class WallRepository {
  final Ref _ref;
  WallRepository(this._ref);

  FirebaseAuth get _auth => _ref.read(firebaseAuthProvider);
  FirebaseFirestore get _db => _ref.read(firestoreProvider);
  FirebaseFunctions get _fns => _ref.read(functionsProvider);

  // ---- Onboarding ----

  Future<void> completeOnboarding({
    required String displayName,
    required String phoneNumber,
  }) async {
    final user = _auth.currentUser!;
    final phoneHash = PhoneHash.of(phoneNumber);
    final appUser = AppUser(
      uid: user.uid,
      phoneHash: phoneHash,
      displayName: displayName,
      consentAt: DateTime.now(),
      ageConfirmed: true,
    );
    await _db
        .collection('users')
        .doc(user.uid)
        .set(appUser.toMap(), SetOptions(merge: true));
    try {
      await _fns
          .httpsCallable('onUserJoin')
          .call({'phoneHash': phoneHash});
    } catch (_) {}
  }

  // ---- Giving feedback ----

  Future<SubmitResult> submitReview(FeedbackDraft draft) async {
    final res = await _fns.httpsCallable('submitReview').call(draft.toCallable());
    final data = Map<String, dynamic>.from(res.data as Map);
    return SubmitResult(
      ok: data['ok'] == true,
      escrowed: data['escrowed'] == true,
      reason: data['reason'] as String?,
    );
  }

  /// Edit feedback the current user previously gave (latest-wins, fresh time).
  Future<SubmitResult> editReview(FeedbackDraft draft) async {
    final res = await _fns.httpsCallable('editReview').call(draft.toCallable());
    final data = Map<String, dynamic>.from(res.data as Map);
    return SubmitResult(
      ok: data['ok'] == true,
      escrowed: data['escrowed'] == true,
      reason: data['reason'] as String?,
    );
  }

  /// Delete feedback the current user gave to [targetPhoneHash].
  Future<void> deleteReview(String targetPhoneHash) => _fns
      .httpsCallable('deleteReview')
      .call({'targetPhoneHash': targetPhoneHash}).then((_) {});

  /// Server-gated read of another user's public wall (give-to-get + blocks).
  Future<Map<String, dynamic>?> getPublicWall(String phoneHash) async {
    final res = await _fns
        .httpsCallable('getPublicWall')
        .call({'phoneHash': phoneHash});
    final data = Map<String, dynamic>.from(res.data as Map);
    final wall = data['wall'];
    return wall == null ? null : Map<String, dynamic>.from(wall as Map);
  }

  // ---- Owner disclosure control ----

  Future<void> setDisclosure(String feedbackId, bool disclosed) =>
      _fns.httpsCallable('setDisclosure').call({
        'feedbackId': feedbackId,
        'disclosed': disclosed,
      }).then((_) {});

  // ---- DPDP §11 always-free access path ----

  Future<void> requestDataAccess() =>
      _fns.httpsCallable('requestDataAccess').call().then((_) {});

  // ---- Safety ----

  Future<void> fileDispute(String feedbackId, String reason) =>
      _fns.httpsCallable('fileDispute').call({
        'feedbackId': feedbackId,
        'reason': reason,
      }).then((_) {});

  // ---- Feedback campaigns (B1) ----

  Future<Map<String, dynamic>> requestFeedback({
    String? message,
    required List<String> focusDimensions,
  }) async {
    final res = await _fns.httpsCallable('requestFeedback').call({
      'message': message,
      'focusDimensions': focusDimensions,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ---- Gamification ----

  Future<void> setLeaderboardOptIn(bool optIn) =>
      _fns.httpsCallable('setLeaderboardOptIn').call({'optIn': optIn}).then((_) {});

  // ---- Monetization (IAP) ----

  Future<void> verifyPurchase({
    required String productId,
    required String verificationData,
    required String source,
  }) =>
      _fns.httpsCallable('verifyPurchase').call({
        'productId': productId,
        'verificationData': verificationData,
        'source': source,
      }).then((_) {});

  // ---- DPDP data export ----

  Future<String> generateDataExport() async {
    final res = await _fns.httpsCallable('generateDataExport').call();
    final data = Map<String, dynamic>.from(res.data as Map);
    return data['json'] as String? ?? '{}';
  }

  // ---- Contacts helper (on-device; raw contacts never leave the device) ----

  /// Open the native contact picker and return the selected contact with phones.
  /// Uses the system picker UI — permissionless on iOS; on Android falls back to
  /// requesting READ_CONTACTS if needed for phone properties.
  Future<Contact?> pickContact() async {
    try {
      return await FlutterContacts.native
          .showPicker(properties: {ContactProperty.phone});
    } on PlatformException {
      final status =
          await FlutterContacts.permissions.request(PermissionType.read);
      if (status != PermissionStatus.granted &&
          status != PermissionStatus.limited) {
        return null;
      }
      return FlutterContacts.native
          .showPicker(properties: {ContactProperty.phone});
    }
  }
}

class SubmitResult {
  final bool ok;
  final bool escrowed;
  final String? reason;
  SubmitResult({required this.ok, required this.escrowed, this.reason});
}
