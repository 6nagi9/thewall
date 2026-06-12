// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'The Wall';

  @override
  String get tabMyWall => 'My Wall';

  @override
  String get tabGive => 'Give';

  @override
  String get tabDiscover => 'Discover';

  @override
  String get tabSettings => 'Settings';

  @override
  String get giveFeedbackTitle => 'Give feedback';

  @override
  String get layABrick => 'Lay a brick';

  @override
  String get layThisBrick => 'Lay this brick';

  @override
  String get askForFeedback => 'Ask for feedback';

  @override
  String get shareOnWhatsApp => 'Share on WhatsApp';

  @override
  String get moreOptions => 'More options';

  @override
  String get yourWall => 'Your wall';

  @override
  String get feedbackFriday =>
      'Feedback Friday — double contribution points on every brick today!';

  @override
  String get unlockHint => 'Give one piece of feedback to unlock this brick.';

  @override
  String get growthNotesPrivate =>
      'Growth notes stay private to them — they never appear on a public wall.';

  @override
  String get claimYourWall => 'Claim your own wall';
}
