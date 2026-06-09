import 'package:cloud_firestore/cloud_firestore.dart';

/// User account / profile. Stored at users/{uid}. Private to owner.
class AppUser {
  final String uid;
  final String phoneHash;
  final String displayName;
  final DateTime? consentAt;
  final bool ageConfirmed;
  final bool premium;
  final int giveToGetCount;
  final List<String> unlockedWalls;
  final DateTime? dataAccessGrantedAt;

  AppUser({
    required this.uid,
    required this.phoneHash,
    this.displayName = '',
    this.consentAt,
    this.ageConfirmed = false,
    this.premium = false,
    this.giveToGetCount = 0,
    this.unlockedWalls = const [],
    this.dataAccessGrantedAt,
  });

  bool get gateCleared => giveToGetCount >= 5;
  bool get onboarded => consentAt != null && ageConfirmed;

  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    return AppUser(
      uid: doc.id,
      phoneHash: d['phoneHash'] ?? '',
      displayName: d['displayName'] ?? '',
      consentAt: (d['consentAt'] as Timestamp?)?.toDate(),
      ageConfirmed: d['ageConfirmed'] ?? false,
      premium: d['premium'] ?? false,
      giveToGetCount: d['giveToGetCount'] ?? 0,
      unlockedWalls: List<String>.from(d['unlockedWalls'] ?? const []),
      dataAccessGrantedAt: (d['dataAccessGrantedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'phoneHash': phoneHash,
        'displayName': displayName,
        'consentAt': consentAt == null ? null : Timestamp.fromDate(consentAt!),
        'ageConfirmed': ageConfirmed,
        'premium': premium,
        'giveToGetCount': giveToGetCount,
        'unlockedWalls': unlockedWalls,
      };
}

/// Public aggregate wall. Stored at walls/{phoneHash}. Written only by Functions.
class Wall {
  final String phoneHash;
  final Map<String, double> dimensionAverages;
  final Map<String, int> tagCounts;
  final int reviewCount;
  final double opennessScore;
  final String opennessLabel;
  final List<DisclosedComment> disclosedComments;

  Wall({
    required this.phoneHash,
    this.dimensionAverages = const {},
    this.tagCounts = const {},
    this.reviewCount = 0,
    this.opennessScore = 0,
    this.opennessLabel = 'New',
    this.disclosedComments = const [],
  });

  bool get meetsMinN => reviewCount >= 3;

  factory Wall.fromDoc(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    return Wall(
      phoneHash: doc.id,
      dimensionAverages: (d['dimensionAverages'] as Map?)?.map(
            (k, v) => MapEntry(k as String, (v as num).toDouble()),
          ) ??
          {},
      tagCounts: (d['tagCounts'] as Map?)?.map(
            (k, v) => MapEntry(k as String, (v as num).toInt()),
          ) ??
          {},
      reviewCount: d['reviewCount'] ?? 0,
      opennessScore: (d['opennessScore'] as num?)?.toDouble() ?? 0,
      opennessLabel: d['opennessLabel'] ?? 'New',
      disclosedComments: ((d['disclosedComments'] as List?) ?? [])
          .map((e) => DisclosedComment.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DisclosedComment {
  final String text;
  final String? authorName;
  final String? contextTag;
  DisclosedComment({required this.text, this.authorName, this.contextTag});

  factory DisclosedComment.fromMap(Map<String, dynamic> m) => DisclosedComment(
        text: m['text'] ?? '',
        authorName: m['authorName'],
        contextTag: m['contextTag'],
      );
}

/// A single review in the owner's inbox.
class ReceivedFeedback {
  final String id;
  final Map<String, int> dimensions;
  final List<String> tags;
  final String? comment;
  final String? authorName;
  final String? contextTag;
  final DateTime createdAt;
  final bool disclosed;
  final String status;

  ReceivedFeedback({
    required this.id,
    required this.dimensions,
    required this.tags,
    this.comment,
    this.authorName,
    this.contextTag,
    required this.createdAt,
    this.disclosed = false,
    this.status = 'active',
  });

  factory ReceivedFeedback.fromDoc(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    return ReceivedFeedback(
      id: doc.id,
      dimensions: (d['dimensions'] as Map?)?.map(
            (k, v) => MapEntry(k as String, (v as num).toInt()),
          ) ??
          {},
      tags: List<String>.from(d['tags'] ?? const []),
      comment: d['comment'],
      authorName: d['authorName'],
      contextTag: d['contextTag'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      disclosed: d['disclosed'] ?? false,
      status: d['status'] ?? 'active',
    );
  }
}

/// Draft a user composes about someone (sent to a Cloud Function).
class FeedbackDraft {
  final String targetPhoneHash;
  final Map<String, int> dimensions;
  final List<String> tags;
  final String? comment;
  final bool anonymous;
  final String? contextTag;

  FeedbackDraft({
    required this.targetPhoneHash,
    required this.dimensions,
    required this.tags,
    this.comment,
    this.anonymous = false,
    this.contextTag,
  });

  Map<String, dynamic> toCallable() => {
        'targetPhoneHash': targetPhoneHash,
        'dimensions': dimensions,
        'tags': tags,
        'comment': comment,
        'anonymous': anonymous,
        'contextTag': contextTag,
      };
}

// ─── Gamification ────────────────────────────────────────────────────────────

class BadgeEarned {
  final String id;
  final DateTime awardedAt;
  BadgeEarned({required this.id, required this.awardedAt});

  factory BadgeEarned.fromMap(Map<String, dynamic> m) => BadgeEarned(
        id: m['id'] as String? ?? '',
        awardedAt: (m['awardedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}

class Streak {
  final int current;
  final int longest;
  const Streak({this.current = 0, this.longest = 0});

  factory Streak.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const Streak();
    return Streak(
      current: (m['current'] as num?)?.toInt() ?? 0,
      longest: (m['longest'] as num?)?.toInt() ?? 0,
    );
  }
}

class GamificationState {
  final String uid;
  final int contributionPoints;
  final double growthScore;
  final double opennessScore;
  final List<BadgeEarned> badges;
  final Streak streak;
  final bool leaderboardOptIn;

  GamificationState({
    required this.uid,
    this.contributionPoints = 0,
    this.growthScore = 0,
    this.opennessScore = 0,
    this.badges = const [],
    this.streak = const Streak(),
    this.leaderboardOptIn = false,
  });

  factory GamificationState.fromDoc(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    return GamificationState(
      uid: doc.id,
      contributionPoints: (d['contributionPoints'] as num?)?.toInt() ?? 0,
      growthScore: (d['growthScore'] as num?)?.toDouble() ?? 0,
      opennessScore: (d['opennessScore'] as num?)?.toDouble() ?? 0,
      badges: ((d['badges'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => BadgeEarned.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      streak: Streak.fromMap(
          (d['streak'] as Map?)?.map((k, v) => MapEntry(k as String, v))),
      leaderboardOptIn: d['leaderboardOptIn'] == true,
    );
  }
}

// ─── Feedback campaigns (B1) ─────────────────────────────────────────────────

class FeedbackRequest {
  final String id;
  final String ownerUid;
  final String? message;
  final List<String> focusDimensions;
  final DateTime createdAt;
  final int responseCount;

  FeedbackRequest({
    required this.id,
    required this.ownerUid,
    this.message,
    this.focusDimensions = const [],
    required this.createdAt,
    this.responseCount = 0,
  });

  factory FeedbackRequest.fromDoc(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    return FeedbackRequest(
      id: doc.id,
      ownerUid: d['ownerUid'] as String? ?? '',
      message: d['message'] as String?,
      focusDimensions: List<String>.from(d['focusDimensions'] ?? const []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      responseCount: (d['responseCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toCallable() => {
        'message': message,
        'focusDimensions': focusDimensions,
      };
}
