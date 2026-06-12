/// App-wide constants and structured taxonomies.
///
/// IMPORTANT (compliance): the tag taxonomy deliberately EXCLUDES any
/// protected attribute (caste, religion, health, sexuality, politics, race).
/// Dimensions are subjective, behavioural, and framed as opinion.
///
/// The taxonomy is CONTEXT-ADAPTIVE: the relationship context is chosen first
/// and selects which dimensions and tags apply. Personal contexts power the
/// emotional/viral loops; professional contexts power usefulness + B2B.
/// Keep in sync with the server mirror in `functions/src/util.ts`.
class K {
  static const String appName = 'The Wall';

  /// Public web base for invite / campaign / circle / wall links.
  /// Served by Firebase Hosting; swap for thewall.app once configured.
  static const String webBase = 'https://the-wall-app-260609.web.app';

  /// Give-to-get: number of feedback "units" to clear the FULL gate
  /// (aggregates + viewing other walls). Individual received items unlock
  /// progressively — 1 give = 1 unlock (see MyWall).
  static const int giveToGetThreshold = 5;

  /// Minimum reviews before any public aggregate surfaces (k-anonymity).
  static const int minReviewsForAggregate = 3;

  /// Escrow TTL for feedback on not-yet-joined targets.
  static const Duration escrowTtl = Duration(days: 30);

  /// Decay constant lambda (per day) for time-weighted aggregation.
  static const double decayLambda = 0.005;

  /// Minimum age (DPDP s.9 — no minors without verifiable parental consent).
  static const int minAge = 18;

  static const int maxCommentLength = 250;

  /// Max constructive growth tags per review.
  static const int maxGrowthTags = 2;

  /// Max circles a user can belong to.
  static const int maxCircles = 10;
}

/// A subjective behavioural dimension rated 1-5.
class FeedbackDimension {
  final String key;
  final String label;
  final String lowLabel;
  final String highLabel;
  const FeedbackDimension(this.key, this.label, this.lowLabel, this.highLabel);

  /// Professional set (Work / Client / Other) — the original four.
  static const List<FeedbackDimension> professional = [
    FeedbackDimension('punctuality', 'Punctuality', 'Often late', 'Always on time'),
    FeedbackDimension('professionalism', 'Professionalism', 'Casual', 'Highly professional'),
    FeedbackDimension('communication', 'Communication', 'Hard to reach', 'Clear & responsive'),
    FeedbackDimension('reliability', 'Reliability', 'Inconsistent', 'Dependable'),
  ];

  static const List<FeedbackDimension> friend = [
    FeedbackDimension('trustworthiness', 'Trustworthiness', 'Guarded', 'Vault-level trust'),
    FeedbackDimension('fun', 'Fun to be around', 'Low-key', 'Life of the room'),
    FeedbackDimension('listening', 'Listens', 'Waits to talk', 'Really hears you'),
    FeedbackDimension('shows_up', 'Shows up', 'Hard to pin down', 'Always there'),
  ];

  static const List<FeedbackDimension> college = [
    FeedbackDimension('team_player', 'Team player', 'Solo flyer', 'Lifts the group'),
    FeedbackDimension('dependable', 'Dependable', 'Wing-it energy', 'Counted on'),
    FeedbackDimension('ideas', 'Ideas', 'Follows along', 'Idea machine'),
    FeedbackDimension('energy', 'Energy', 'Reserved', 'Brings the vibe'),
  ];

  static const List<FeedbackDimension> family = [
    FeedbackDimension('caring', 'Caring', 'Distant', 'Deeply caring'),
    FeedbackDimension('dependable_fam', 'Dependable', 'Hit or miss', 'Rock solid'),
    FeedbackDimension('patience', 'Patience', 'Quick fuse', 'Endless patience'),
    FeedbackDimension('generosity', 'Generosity', 'Keeps to self', 'Gives freely'),
  ];

  /// Every dimension across all contexts (for label lookup on walls that mix
  /// contexts).
  static final List<FeedbackDimension> all = [
    ...professional,
    ...friend,
    ...college,
    ...family,
  ];

  static FeedbackDimension byKey(String key) => all.firstWhere(
        (d) => d.key == key,
        orElse: () => FeedbackDimension(key, key, '', ''),
      );
}

/// A relationship context — picked FIRST in the give flow; selects the
/// dimension + tag sets.
class FeedbackContext {
  final String tag; // stored value, matches server ContextTag
  final String label;
  final String emoji;
  final List<FeedbackDimension> dimensions;
  final List<String> tags;
  const FeedbackContext({
    required this.tag,
    required this.label,
    required this.emoji,
    required this.dimensions,
    required this.tags,
  });

  static const _workTags = [
    'Great listener', 'Solution-oriented', 'Collaborative', 'Well prepared',
    'Follows through', 'Calm under pressure', 'Detail-oriented',
    'Big-picture thinker', 'Generous with time', 'Direct', 'Patient',
    'Motivating',
  ];

  static const List<FeedbackContext> all = [
    FeedbackContext(
      tag: 'Friend',
      label: 'Friend',
      emoji: '🤝',
      dimensions: FeedbackDimension.friend,
      tags: [
        'Hype person', 'Keeps secrets', 'Brutally honest', 'Always down',
        'Great company', 'Remembers the little things', 'Shows up in a crisis',
        'Makes you laugh',
      ],
    ),
    FeedbackContext(
      tag: 'Work',
      label: 'Work',
      emoji: '💼',
      dimensions: FeedbackDimension.professional,
      tags: _workTags,
    ),
    FeedbackContext(
      tag: 'College',
      label: 'College',
      emoji: '🎓',
      dimensions: FeedbackDimension.college,
      tags: [
        'Carries group projects', 'Notes dealer', 'Chill under deadline',
        'Idea machine', 'Study buddy', 'Lab partner of dreams',
      ],
    ),
    FeedbackContext(
      tag: 'Family',
      label: 'Family',
      emoji: '🏠',
      dimensions: FeedbackDimension.family,
      tags: [
        'Shows up when it matters', 'Good with kids', 'Fixer',
        'Holds everyone together', 'Quietly generous', 'Wise counsel',
      ],
    ),
    FeedbackContext(
      tag: 'Client',
      label: 'Client',
      emoji: '🧾',
      dimensions: FeedbackDimension.professional,
      tags: _workTags,
    ),
    FeedbackContext(
      tag: 'Community',
      label: 'Community',
      emoji: '🌱',
      dimensions: FeedbackDimension.family,
      tags: [
        'Shows up when it matters', 'Good with kids', 'Fixer',
        'Holds everyone together', 'Quietly generous', 'Wise counsel',
      ],
    ),
  ];

  static FeedbackContext byTag(String? tag) => all.firstWhere(
        (c) => c.tag == tag,
        orElse: () => all[1], // Work — matches legacy reviews with no context
      );
}

/// Constructive growth tags (rose-styled, max [K.maxGrowthTags] per review).
/// Owner-visible only; never enter public aggregates.
class GrowthTags {
  static const List<String> all = [
    'Could be more punctual', 'Hard to reach sometimes',
    'Interrupts when excited', 'Could listen more', 'Spreads too thin',
    'Could follow through more', 'Takes on too much', 'Could be more patient',
    'Cancels plans sometimes', 'Could share more openly',
  ];
}

/// Legacy alias — positive tags of the Work context (kept so older code and
/// tests keep compiling; prefer FeedbackContext.tags).
class FeedbackTags {
  static const List<String> all = FeedbackContext._workTags;
}

/// Context tags weight credibility and segment dimensions (B6).
class ContextTag {
  static final List<String> all =
      FeedbackContext.all.map((c) => c.tag).toList();
}
