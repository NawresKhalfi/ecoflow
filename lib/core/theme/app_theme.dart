import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Thème EcoFlow « Modern Layered Premium » : fond teinté, typographie
/// Bricolage Grotesque à forte hiérarchie, coins très arrondis.
abstract final class AppTheme {
  static const fontFamily = 'Bricolage';

  static ThemeData light() => _build(EcoPalette.light, Brightness.light);
  static ThemeData dark() => _build(EcoPalette.dark, Brightness.dark);

  /// Style avec graisse appliquée aussi à l'axe `wght` de la police variable.
  static TextStyle weighted(
    double size,
    int weight, {
    Color? color,
    double? height,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
      fontVariations: [FontVariation.weight(weight.toDouble())],
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static ThemeData _build(EcoPalette p, Brightness b) {
    final scheme = ColorScheme.fromSeed(
      seedColor: EcoColors.primary,
      brightness: b,
      primary: EcoColors.primary,
      secondary: EcoColors.coral,
      tertiary: EcoColors.violet,
      error: const Color(0xFFD64545),
      surface: p.card,
      onSurface: p.ink,
    );
    final text = TextTheme(
      displayLarge: weighted(56, 800, color: p.ink, height: .95, letterSpacing: -2),
      displayMedium: weighted(44, 800, color: p.ink, height: 1, letterSpacing: -1.4),
      headlineLarge: weighted(34, 800, color: p.ink, height: 1.05, letterSpacing: -1),
      headlineMedium: weighted(28, 800, color: p.ink, letterSpacing: -.6),
      titleLarge: weighted(22, 800, color: p.ink),
      titleMedium: weighted(17, 700, color: p.ink),
      titleSmall: weighted(15, 700, color: p.ink),
      bodyLarge: weighted(17, 400, color: p.ink, height: 1.4),
      bodyMedium: weighted(15, 400, color: p.ink, height: 1.4),
      bodySmall: weighted(13, 400, color: p.muted, height: 1.35),
      labelLarge: weighted(16, 700, color: p.ink),
      labelMedium: weighted(13, 600, color: p.ink),
      labelSmall: weighted(11, 600, color: p.muted),
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: p.line, width: 2),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: p.background,
      extensions: [p],
      splashFactory: InkSparkle.splashFactory,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: EcoColors.primaryBright, width: 2),
        ),
        errorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: scheme.error, width: 2)),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: weighted(15, 600, color: p.muted),
        hintStyle: weighted(15, 400, color: p.muted),
        errorMaxLines: 3,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? EcoColors.primary : null,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? EcoColors.primaryBright : p.line,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        contentTextStyle: weighted(15, 600, color: p.background),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
