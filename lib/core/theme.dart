import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// The Wall — "Clay & Ink" design system.
///
/// A warm gallery-dark foundation (ink) with a terracotta signature (clay):
/// every piece of feedback is a brick laid on your wall. Gold marks premium,
/// sage marks growth, rose marks destructive/error.
///
/// Type: Bricolage Grotesque (display) + Schibsted Grotesk (body).
/// Motion: see [WallMotion]. Spacing: see [WallSpace].
/// ─────────────────────────────────────────────────────────────────────────
class AppTheme {
  // ── Ink — warm charcoal scale ─────────────────────────────────────────
  static const Color ink950 = Color(0xFF13100D); // page background
  static const Color ink900 = Color(0xFF191511);
  static const Color ink850 = Color(0xFF201B16); // card surface
  static const Color ink800 = Color(0xFF282219); // raised surface
  static const Color ink700 = Color(0xFF38302A); // hairline borders
  static const Color ink600 = Color(0xFF4F4439);
  static const Color ink400 = Color(0xFF8E8174); // muted text
  static const Color ink300 = Color(0xFFB5A99B); // secondary text
  static const Color ink200 = Color(0xFFD8Cec2); // body text
  static const Color ink100 = Color(0xFFEFE8DE);
  static const Color paper = Color(0xFFFAF5EC); // headings / near-white

  // ── Signature & semantic accents ──────────────────────────────────────
  static const Color clay = Color(0xFFE07A5F); // signature terracotta
  static const Color clayBright = Color(0xFFF09877); // hover / gradients
  static const Color clayDeep = Color(0xFFB45C44); // pressed / depth
  static const Color gold = Color(0xFFD9A441); // premium
  static const Color goldSoft = Color(0xFFE8C07A);
  static const Color sage = Color(0xFF93B873); // positive / growth
  static const Color rose = Color(0xFFD95C6B); // error / destructive
  static const Color flame = Color(0xFFE8743F); // streaks

  // ── Legacy aliases (kept so older code keeps compiling) ──────────────
  static const Color slate900 = ink950;
  static const Color slate800 = ink850;
  static const Color slate700 = ink700;
  static const Color slate500 = ink400;
  static const Color slate300 = ink300;
  static const Color teal = clay;
  static const Color tealDark = clayDeep;
  static const Color amber = gold;
  static const Color emerald = sage;

  // ── Typography ────────────────────────────────────────────────────────
  // Fonts are bundled assets (see pubspec.yaml) — no runtime fetch, so the
  // brand type renders offline and on poor connections.
  static const String _displayFamily = 'BricolageGrotesque';
  static const String _bodyFamily = 'SchibstedGrotesk';

  /// Display face — used for screen titles, hero numbers, brand moments.
  static TextStyle display({
    double size = 28,
    FontWeight weight = FontWeight.w700,
    Color color = paper,
    double? height,
    double letterSpacing = -0.5,
  }) =>
      TextStyle(
        fontFamily: _displayFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Body face — everything else.
  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = ink200,
    double? height,
    double letterSpacing = 0,
  }) =>
      TextStyle(
        fontFamily: _bodyFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextTheme _textTheme(TextTheme base) {
    final t = base
        .apply(fontFamily: _bodyFamily)
        .apply(bodyColor: ink200, displayColor: paper);
    return t.copyWith(
      displayLarge: display(size: 44, weight: FontWeight.w800),
      displayMedium: display(size: 34, weight: FontWeight.w800),
      displaySmall: display(size: 28),
      headlineLarge: display(size: 26),
      headlineMedium: display(size: 22),
      headlineSmall: display(size: 19, letterSpacing: -0.3),
      titleLarge: display(size: 18, letterSpacing: -0.2),
      titleMedium: body(size: 15, weight: FontWeight.w600, color: paper),
      titleSmall: body(size: 13, weight: FontWeight.w600, color: ink100),
      bodyLarge: body(size: 16, height: 1.5),
      bodyMedium: body(size: 14, height: 1.45),
      bodySmall: body(size: 12, color: ink300),
      labelLarge: body(size: 15, weight: FontWeight.w700, color: paper),
      labelMedium: body(size: 12, weight: FontWeight.w600, color: ink300),
      labelSmall: body(
          size: 11,
          weight: FontWeight.w700,
          color: ink400,
          letterSpacing: 0.8),
    );
  }

  // ── ThemeData ─────────────────────────────────────────────────────────
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final text = _textTheme(base.textTheme);
    return base.copyWith(
      scaffoldBackgroundColor: ink950,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.dark(
        primary: clay,
        onPrimary: ink950,
        secondary: gold,
        onSecondary: ink950,
        surface: ink850,
        onSurface: ink200,
        surfaceContainerHighest: ink800,
        outline: ink700,
        error: rose,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: ink950,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: ink300),
        titleTextStyle: display(size: 20),
      ),
      cardTheme: CardThemeData(
        color: ink850,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ink700, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.disabled) ? ink700 : clay),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.disabled) ? ink400 : ink950),
          overlayColor: WidgetStateProperty.all(clayDeep.withValues(alpha: .3)),
          minimumSize: WidgetStateProperty.all(const Size.fromHeight(56)),
          textStyle: WidgetStateProperty.all(
              body(size: 16, weight: FontWeight.w700)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          )),
          elevation: WidgetStateProperty.all(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink100,
          side: const BorderSide(color: ink700),
          minimumSize: const Size.fromHeight(52),
          textStyle: body(size: 15, weight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: clay,
          textStyle: body(size: 14, weight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ink850,
        hintStyle: body(size: 15, color: ink400),
        labelStyle: body(size: 15, color: ink300),
        prefixIconColor: ink400,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ink700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ink700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: clay, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: rose, width: 1.6),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: rose, width: 1.6),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: ink850,
        selectedColor: clay.withValues(alpha: 0.18),
        checkmarkColor: clay,
        side: const BorderSide(color: ink700),
        labelStyle: body(size: 13, color: ink300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: clay,
        inactiveTrackColor: ink700,
        thumbColor: clayBright,
        overlayColor: clay.withValues(alpha: .12),
        valueIndicatorColor: clay,
        valueIndicatorTextStyle: body(
            size: 13, weight: FontWeight.w700, color: ink950),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? ink950 : ink400),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? clay : ink800),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? clay : ink700),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? clay : Colors.transparent),
        checkColor: WidgetStateProperty.all(ink950),
        side: const BorderSide(color: ink600, width: 1.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelColor: paper,
        unselectedLabelColor: ink400,
        indicatorColor: clay,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: ink700,
        labelStyle: body(size: 14, weight: FontWeight.w700),
        unselectedLabelStyle: body(size: 14, weight: FontWeight.w500),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ink850,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: ink700),
        ),
        titleTextStyle: display(size: 20),
        contentTextStyle: body(size: 14, height: 1.5, color: ink300),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ink900,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: ink900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink800,
        contentTextStyle: body(size: 14, color: ink100),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: ink700),
        ),
      ),
      dividerTheme: const DividerThemeData(color: ink700, thickness: 1),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: clay),
      listTileTheme: ListTileThemeData(
        iconColor: ink300,
        titleTextStyle: body(size: 15, weight: FontWeight.w600, color: paper),
        subtitleTextStyle: body(size: 12.5, color: ink400, height: 1.35),
      ),
    );
  }
}

/// Motion language — one set of durations & curves used everywhere.
class WallMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration med = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 560);
  static const Curve ease = Curves.easeOutCubic;
  static const Curve spring = Curves.easeOutBack;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
}

/// Spacing scale.
class WallSpace {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 36;
}
