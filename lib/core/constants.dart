/// App-wide constants and structured taxonomies.
///
/// IMPORTANT (compliance): the tag taxonomy deliberately EXCLUDES any
/// protected attribute (caste, religion, health, sexuality, politics, race).
/// Dimensions are subjective, professional/behavioural, and framed as opinion.
class K {
  static const String appName = 'The Wall';

  /// Give-to-get: number of feedback "units" to clear the soft gate.
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
}

/// Fixed, subjective behavioural dimensions rated 1-5.
class FeedbackDimension {
  final String key;
  final String label;
  final String lowLabel;
  final String highLabel;
  const FeedbackDimension(this.key, this.label, this.lowLabel, this.highLabel);

  static const List<FeedbackDimension> all = [
    FeedbackDimension('punctuality', 'Punctuality', 'Often late', 'Always on time'),
    FeedbackDimension('professionalism', 'Professionalism', 'Casual', 'Highly professional'),
    FeedbackDimension('communication', 'Communication', 'Hard to reach', 'Clear & responsive'),
    FeedbackDimension('reliability', 'Reliability', 'Inconsistent', 'Dependable'),
  ];
}

/// Curated, positive/neutral tag chips. No protected attributes. No slurs.
class FeedbackTags {
  static const List<String> all = [
    'Great listener',
    'Solution-oriented',
    'Collaborative',
    'Well prepared',
    'Follows through',
    'Calm under pressure',
    'Detail-oriented',
    'Big-picture thinker',
    'Generous with time',
    'Direct',
    'Patient',
    'Motivating',
  ];
}

/// Context tags weight credibility and segment dimensions (B6).
class ContextTag {
  static const List<String> all = ['Work', 'College', 'Client', 'Community', 'Other'];
}
