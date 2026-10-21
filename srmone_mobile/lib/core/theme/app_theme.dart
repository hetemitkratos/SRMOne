// lib/core/theme/app_theme.dart
// The web app's visual language (academia-backend/frontend: index.css and
// tailwind.config.js) as Flutter themes: a cream page, white rounded cards,
// black pills, four pastel accents, Inter body text and Space Grotesk
// headings. Screens read colours from [SrmColors] so light and dark agree.

import 'package:flutter/material.dart';

/// Raw colours from the web app's stylesheet.
abstract final class SrmPalette {
  /// Page background (`body { background: #F4F0EB }`).
  static const cream = Color(0xFFF4F0EB);

  /// Text and the black pills/hero banners (`#1A1A1A`).
  static const ink = Color(0xFF1A1A1A);

  /// The nav bar's track (`bg-[#F9F7F4]`).
  static const creamLight = Color(0xFFF9F7F4);

  static const mint = Color(0xFFBDE3D5);
  static const mintText = Color(0xFF5B9E8B);
  static const terracotta = Color(0xFFD97757);
  static const terracottaText = Color(0xFFA6472A);
  static const lavender = Color(0xFFC7C9E0);
  static const lavenderText = Color(0xFF6E7196);
  static const beige = Color(0xFFE6D5C3);
  static const beigeText = Color(0xFFA38565);

  // Tailwind's `ink` scale, used for dark mode.
  static const ink900 = Color(0xFF0A0A0F);
  static const ink800 = Color(0xFF12121A);
  static const ink700 = Color(0xFF1A1A26);
  static const ink600 = Color(0xFF242435);
  static const ink500 = Color(0xFF2E2E42);

  // Tailwind slate, for secondary text and borders.
  static const slate200 = Color(0xFFE2E8F0);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate100 = Color(0xFFF1F5F9);

  /// Present / absent counts (`text-emerald-600`, `text-red-500`).
  static const emerald = Color(0xFF059669);
  static const red = Color(0xFFEF4444);
  static const amber = Color(0xFFD97706);
}

/// The theme's semantic colours, so widgets never hard-code light or dark.
@immutable
class SrmColors extends ThemeExtension<SrmColors> {
  /// The page behind everything.
  final Color page;

  /// White cards.
  final Color card;

  /// Faint card borders.
  final Color border;

  /// Main text.
  final Color text;

  /// Secondary text.
  final Color muted;

  /// Tertiary text, such as uppercase labels.
  final Color faint;

  /// Empty progress-bar tracks and quiet icon circles.
  final Color track;

  /// The black hero banners, pills and selected tabs.
  final Color hero;

  /// Text on [hero].
  final Color onHero;

  /// Present counts and on-track values.
  final Color good;

  /// Absent counts and errors.
  final Color bad;

  /// Warnings, such as stale data.
  final Color warn;

  const SrmColors({
    required this.page,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
    required this.faint,
    required this.track,
    required this.hero,
    required this.onHero,
    required this.good,
    required this.bad,
    required this.warn,
  });

  static const light = SrmColors(
    page: SrmPalette.cream,
    card: Colors.white,
    border: Color(0x99E2E8F0), // border-slate-200/60
    text: SrmPalette.ink,
    muted: SrmPalette.slate500,
    faint: SrmPalette.slate400,
    track: SrmPalette.slate100,
    hero: SrmPalette.ink,
    onHero: Colors.white,
    good: SrmPalette.emerald,
    bad: SrmPalette.red,
    warn: SrmPalette.amber,
  );

  static const dark = SrmColors(
    page: SrmPalette.ink900,
    card: SrmPalette.ink800,
    border: SrmPalette.ink600,
    text: SrmPalette.cream,
    muted: SrmPalette.slate400,
    faint: SrmPalette.slate500,
    track: SrmPalette.ink600,
    hero: SrmPalette.ink700,
    onHero: Colors.white,
    good: Color(0xFF34D399),
    bad: Color(0xFFF87171),
    warn: Color(0xFFFBBF24),
  );

  /// This theme's colours.
  static SrmColors of(BuildContext context) =>
      Theme.of(context).extension<SrmColors>() ?? light;

  @override
  SrmColors copyWith({
    Color? page,
    Color? card,
    Color? border,
    Color? text,
    Color? muted,
    Color? faint,
    Color? track,
    Color? hero,
    Color? onHero,
    Color? good,
    Color? bad,
    Color? warn,
  }) =>
      SrmColors(
        page: page ?? this.page,
        card: card ?? this.card,
        border: border ?? this.border,
        text: text ?? this.text,
        muted: muted ?? this.muted,
        faint: faint ?? this.faint,
        track: track ?? this.track,
        hero: hero ?? this.hero,
        onHero: onHero ?? this.onHero,
        good: good ?? this.good,
        bad: bad ?? this.bad,
        warn: warn ?? this.warn,
      );

  @override
  SrmColors lerp(SrmColors? other, double t) {
    if (other == null) return this;
    return SrmColors(
      page: Color.lerp(page, other.page, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      track: Color.lerp(track, other.track, t)!,
      hero: Color.lerp(hero, other.hero, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
      good: Color.lerp(good, other.good, t)!,
      bad: Color.lerp(bad, other.bad, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
    );
  }
}

/// Font families bundled in pubspec.yaml.
abstract final class SrmFonts {
  static const body = 'Inter';
  static const display = 'SpaceGrotesk';
  static const mono = 'JetBrainsMono';
}

/// Corner radii the web app uses (`rounded-[24px]`, `rounded-[32px]`).
abstract final class SrmRadii {
  static const card = 24.0;
  static const panel = 32.0;
  static const field = 16.0;
}

/// The light (cream) theme, matching the web app.
ThemeData srmLightTheme() => _build(Brightness.light, SrmColors.light);

/// The dark theme, from the web app's `ink` palette.
ThemeData srmDarkTheme() => _build(Brightness.dark, SrmColors.dark);

ThemeData _build(Brightness brightness, SrmColors c) {
  final scheme = ColorScheme.fromSeed(
    seedColor: SrmPalette.ink,
    brightness: brightness,
  ).copyWith(
    primary: c.hero == SrmPalette.ink ? SrmPalette.ink : SrmPalette.cream,
    onPrimary: c.hero == SrmPalette.ink ? Colors.white : SrmPalette.ink,
    secondary: SrmPalette.terracotta,
    onSecondary: Colors.white,
    tertiary: SrmPalette.mintText,
    surface: c.card,
    onSurface: c.text,
    onSurfaceVariant: c.muted,
    surfaceContainerHighest: c.track,
    outline: c.border,
    outlineVariant: c.border,
    error: c.bad,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: SrmFonts.body,
  );

  TextStyle display(TextStyle? s, double size) =>
      (s ?? const TextStyle()).copyWith(
        fontFamily: SrmFonts.display,
        fontWeight: FontWeight.w700,
        fontSize: size,
        letterSpacing: -0.5,
        color: c.text,
      );

  final text = base.textTheme.apply(bodyColor: c.text, displayColor: c.text);

  return base.copyWith(
    scaffoldBackgroundColor: c.page,
    canvasColor: c.page,
    dividerColor: c.border,
    extensions: [c],
    textTheme: text.copyWith(
      displaySmall: display(text.displaySmall, 34),
      headlineMedium: display(text.headlineMedium, 28),
      headlineSmall: display(text.headlineSmall, 24),
      titleLarge: display(text.titleLarge, 20),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.page,
      foregroundColor: c.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: SrmFonts.display,
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: c.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: c.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SrmRadii.card),
        side: BorderSide(color: c.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.page,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: c.hero,
      indicatorShape: const StadiumBorder(),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? c.onHero : c.muted,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected) ? c.text : c.muted,
          )),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor:
            c.hero == SrmPalette.ink ? SrmPalette.ink : SrmPalette.cream,
        foregroundColor:
            c.hero == SrmPalette.ink ? Colors.white : SrmPalette.ink,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            c.hero == SrmPalette.ink ? SrmPalette.ink : SrmPalette.cream,
        foregroundColor:
            c.hero == SrmPalette.ink ? Colors.white : SrmPalette.ink,
        elevation: 0,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        side: BorderSide(color: c.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.text,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        side: WidgetStatePropertyAll(BorderSide(color: c.border)),
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.hero : c.card),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.onHero : c.muted),
        textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.card,
      selectedColor: c.hero,
      side: BorderSide(color: c.border),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(fontWeight: FontWeight.w700, color: c.text),
      secondaryLabelStyle:
          TextStyle(fontWeight: FontWeight.w700, color: c.onHero),
      checkmarkColor: c.onHero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: c.faint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SrmRadii.field),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SrmRadii.field),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SrmRadii.field),
        borderSide: BorderSide(color: c.text, width: 1.5),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onHero : c.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.hero : c.track),
      trackOutlineColor: WidgetStatePropertyAll(c.border),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: c.onHero,
      unselectedLabelColor: c.muted,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      indicator: ShapeDecoration(color: c.hero, shape: const StadiumBorder()),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(SrmRadii.panel)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SrmRadii.card),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SrmPalette.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.text,
      linearTrackColor: c.track,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.muted,
      textColor: c.text,
    ),
  );
}
