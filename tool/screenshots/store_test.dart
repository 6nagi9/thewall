// ignore_for_file: invalid_use_of_visible_for_testing_member
//
// Renders real Known screens to PNG with demo data, for the store listings.
//
//   flutter test tool/screenshots/store_test.dart
//   python3 tool/make_store_assets.py      # captions + store sizes
//
// Writes build/screens/store/*.png at 430×932 logical × 3 (1290×2796, the
// 6.9" iPhone frame). No Firebase: every data provider is overridden.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wall/core/prefs.dart';
import 'package:wall/core/remote_config.dart';
import 'package:wall/core/theme.dart';
import 'package:wall/data/models.dart';
import 'package:wall/data/repositories.dart';
import 'package:wall/features/feedback/give_feedback_screen.dart';
import 'package:wall/features/gamification/badges_screen.dart';
import 'package:wall/features/premium/analytics_screen.dart';
import 'package:wall/features/shell/home_shell.dart';
import 'package:wall/l10n/app_localizations.dart';
import 'package:wall/shared/connectivity_banner.dart';

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) {
    final l = FontLoader(name);
    for (final f in files) {
      l.addFont(rootBundle.load('assets/fonts/$f'));
    }
    return l.load();
  }

  var dir = File(Platform.resolvedExecutable).parent;
  while (!File('${dir.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').existsSync() &&
      dir.parent.path != dir.path) {
    dir = dir.parent;
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(
        File('${dir.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync().buffer)));
  await Future.wait([
    family('Bricolage Grotesque', [for (final w in [400, 600, 700, 800]) 'BricolageGrotesque-$w.ttf']),
    family('BricolageGrotesque', [for (final w in [400, 600, 700, 800]) 'BricolageGrotesque-$w.ttf']),
    family('Schibsted Grotesk', [for (final w in [400, 500, 600, 700, 800]) 'SchibstedGrotesk-$w.ttf']),
    family('SchibstedGrotesk', [for (final w in [400, 500, 600, 700, 800]) 'SchibstedGrotesk-$w.ttf']),
    icons.load(),
  ]);
}

class _RC extends Fake implements FirebaseRemoteConfig {
  @override
  bool getBool(String key) => false;
  @override
  int getInt(String key) => 0;
  @override
  double getDouble(String key) => 0;
  @override
  String getString(String key) => RemoteConfigKeys.defaults[key]?.toString() ?? '';
}

final _now = DateTime.now();

ReceivedFeedback _fb(int i, String ctx, Map<String, int> d, List<String> tags,
        {String? comment, String? author, bool disclosed = false, List<String> growth = const []}) =>
    ReceivedFeedback(
      id: 'f$i',
      dimensions: d,
      tags: tags,
      growthTags: growth,
      comment: comment,
      authorName: author,
      contextTag: ctx,
      createdAt: _now.subtract(Duration(days: i * 9 + 1)),
      disclosed: disclosed,
    );

final _feedback = [
  _fb(0, 'Work', {'punctuality': 4, 'professionalism': 5, 'communication': 5, 'reliability': 5},
      ['Great listener', 'Follows through', 'Calm under pressure'],
      comment: 'You make every project feel calmer. Thank you for the way you ran the launch.',
      author: 'Priya', disclosed: true),
  _fb(1, 'Friend', {'trustworthiness': 5, 'fun': 4, 'listening': 5, 'shows_up': 4},
      ['Keeps secrets', 'Shows up in a crisis', 'Makes you laugh'],
      comment: 'The friend everyone calls first.', author: 'Arjun', disclosed: true),
  _fb(2, 'Work', {'punctuality': 3, 'professionalism': 5, 'communication': 4, 'reliability': 4},
      ['Solution-oriented', 'Detail-oriented'], growth: ['Could be more punctual'],
      comment: 'Brilliant in reviews. Mornings could start a little earlier!'),
  _fb(3, 'Family', {'caring': 5, 'dependable_fam': 5, 'patience': 4, 'generosity': 5},
      ['Holds everyone together', 'Quietly generous'], author: 'Meera', disclosed: true),
  _fb(4, 'Work', {'punctuality': 4, 'professionalism': 4, 'communication': 5, 'reliability': 5},
      ['Collaborative', 'Generous with time', 'Motivating']),
  _fb(5, 'Friend', {'trustworthiness': 5, 'fun': 5, 'listening': 4, 'shows_up': 5},
      ['Hype person', 'Remembers the little things']),
  _fb(6, 'Work', {'punctuality': 3, 'professionalism': 4, 'communication': 4, 'reliability': 4},
      ['Big-picture thinker', 'Direct'], growth: ['Takes on too much']),
  _fb(7, 'College', {'team_player': 5, 'dependable': 4, 'ideas': 5, 'energy': 4},
      ['Idea machine', 'Carries group projects']),
];

final _user = AppUser(
  uid: 'demo',
  phoneHash: 'demo',
  displayName: 'Aanya',
  consentAt: _now.subtract(const Duration(days: 90)),
  ageConfirmed: true,
  premium: true,
  giveToGetCount: 12,
  inviteJoins: 4,
  selfScores: const {'punctuality': 4, 'professionalism': 4, 'communication': 3, 'reliability': 4},
);

final _wall = Wall(
  phoneHash: 'demo',
  dimensionAverages: const {'punctuality': 3.6, 'professionalism': 4.5, 'communication': 4.6, 'reliability': 4.6},
  tagCounts: const {'Great listener': 6, 'Follows through': 5, 'Calm under pressure': 4, 'Collaborative': 3},
  reviewCount: _feedback.length,
  opennessScore: 0.62,
  opennessLabel: 'Open',
  disclosedComments: [
    DisclosedComment(text: _feedback[0].comment!, authorName: 'Priya', contextTag: 'Work'),
    DisclosedComment(text: _feedback[1].comment!, authorName: 'Arjun', contextTag: 'Friend'),
  ],
);

final _gam = GamificationState(
  uid: 'demo',
  contributionPoints: 340,
  growthScore: 72,
  opennessScore: 0.62,
  badges: [
    for (final id in ['wall_claimed', 'first_feedback', 'giver_5', 'giver_10', 'first_review', 'five_reviews', 'open_book', 'streak_7'])
      BadgeEarned(id: id, awardedAt: _now.subtract(const Duration(days: 20))),
  ],
  streak: const Streak(current: 9, longest: 14),
);

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('build/screens/store/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('store captures', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> settle([int ms = 1500]) async {
      for (var t = 0; t < ms; t += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> shot(String name, Widget screen, {double scroll = 0}) async {
      final key = GlobalKey();
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          remoteConfigProvider.overrideWithValue(_RC()),
          connectivityProvider.overrideWith((_) => Stream.value([ConnectivityResult.wifi])),
          appUserProvider.overrideWith((_) => Stream.value(_user)),
          myWallProvider.overrideWith((_) => Stream.value(_wall)),
          receivedFeedbackProvider.overrideWith((_) => Stream.value(_feedback)),
          gamificationProvider.overrideWith((_) => Stream.value(_gam)),
          myFeedbackRequestsProvider.overrideWith((_) => Stream.value(const [])),
          myCirclesProvider.overrideWith((_) => Stream.value(const [])),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: screen,
          ),
        ),
      ));
      await settle();
      if (scroll != 0) {
        await tester.drag(find.byType(Scrollable).first, Offset(0, -scroll));
        await settle(800);
      }
      await _capture(tester, key, name);
    }

    await shot('01-wall', const HomeShell());
    await shot('02-feedback', const HomeShell(), scroll: 900);
    await shot('03-give', const GiveFeedbackScreen());
    await shot('04-trends', const AnalyticsScreen());
    await shot('05-badges', const BadgesScreen());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
