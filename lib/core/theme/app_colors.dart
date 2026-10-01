import 'package:flutter/material.dart';

/// Couleurs de marque EcoFlow (reprises du prototype cliquable).
abstract final class EcoColors {
  static const primary = Color(0xFF0B7A4B);
  static const primaryBright = Color(0xFF19B26B);
  static const coral = Color(0xFFFF7A59);
  static const pink = Color(0xFFFF5E7E);
  static const sun = Color(0xFFFFC53D);
  static const sunDeep = Color(0xFFF5A800);
  static const sky = Color(0xFF4C9AFF);
  static const skyDeep = Color(0xFF3B82F6);
  static const violet = Color(0xFF7B61FF);
  static const violetDeep = Color(0xFF6C4DF0);

  /// Texte sur le dégradé « soleil » (ambre profond).
  static const onSun = Color(0xFFFFFFFF);
}

/// Dégradés expressifs utilisés pour différencier les fonctionnalités.
/// Teintes assez profondes pour un texte blanc lisible (WCAG AA, US-129).
abstract final class EcoGradients {
  static const green = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF075C38), EcoColors.primary],
  );
  static const coral = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB8381F), Color(0xFFB52D52)],
  );
  static const sky = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1C4FC0), Color(0xFF1F63D8)],
  );
  static const violet = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4A31C0), Color(0xFF5B3FD9)],
  );
  static const sun = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8A4600), Color(0xFFA35400)],
  );
}

/// Palette dépendante du thème (clair / sombre), accessible via
/// `Theme.of(context).extension<EcoPalette>()!` ou `context.eco`.
@immutable
class EcoPalette extends ThemeExtension<EcoPalette> {
  const EcoPalette({
    required this.background,
    required this.ink,
    required this.muted,
    required this.card,
    required this.line,
    required this.shadow,
    required this.chipGreen,
    required this.chipCoral,
    required this.chipSun,
    required this.chipSky,
    required this.chipViolet,
  });

  final Color background;
  final Color ink;
  final Color muted;
  final Color card;
  final Color line;
  final Color shadow;
  final (Color bg, Color fg) chipGreen;
  final (Color bg, Color fg) chipCoral;
  final (Color bg, Color fg) chipSun;
  final (Color bg, Color fg) chipSky;
  final (Color bg, Color fg) chipViolet;

  static const light = EcoPalette(
    background: Color(0xFFF4EFE4),
    ink: Color(0xFF12261D),
    muted: Color(0xFF56645B),
    card: Colors.white,
    line: Color(0x1412261D),
    shadow: Color(0xFF12261D),
    chipGreen: (Color(0xFFE3F5EA), EcoColors.primary),
    chipCoral: (Color(0xFFFFE7E0), Color(0xFFC4482A)),
    chipSun: (Color(0xFFFFF1C7), Color(0xFF8A6500)),
    chipSky: (Color(0xFFE1EEFF), Color(0xFF1F5FB8)),
    chipViolet: (Color(0xFFECE7FF), Color(0xFF4A34C9)),
  );

  static const dark = EcoPalette(
    background: Color(0xFF0F1A15),
    ink: Color(0xFFEDF3EE),
    muted: Color(0xFF93A69A),
    card: Color(0xFF1A2B23),
    line: Color(0x1AFFFFFF),
    shadow: Colors.black,
    chipGreen: (Color(0xFF1E4A34), Color(0xFF8BE3B4)),
    chipCoral: (Color(0xFF4A2A22), Color(0xFFFFB39F)),
    chipSun: (Color(0xFF4A3B12), Color(0xFFFFDC7A)),
    chipSky: (Color(0xFF1C3350), Color(0xFFA8CBFF)),
    chipViolet: (Color(0xFF2E2656), Color(0xFFC7BAFF)),
  );

  /// Ombre douce et profonde en deux couches (cf. `--sh` du prototype).
  List<BoxShadow> get softShadow => [
    BoxShadow(color: shadow.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
    BoxShadow(
      color: shadow.withValues(alpha: 0.18),
      blurRadius: 30,
      spreadRadius: -10,
      offset: const Offset(0, 14),
    ),
  ];

  @override
  EcoPalette copyWith() => this;

  @override
  EcoPalette lerp(ThemeExtension<EcoPalette>? other, double t) {
    if (other is! EcoPalette) return this;
    (Color, Color) l((Color, Color) a, (Color, Color) b) =>
        (Color.lerp(a.$1, b.$1, t)!, Color.lerp(a.$2, b.$2, t)!);
    return EcoPalette(
      background: Color.lerp(background, other.background, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      card: Color.lerp(card, other.card, t)!,
      line: Color.lerp(line, other.line, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      chipGreen: l(chipGreen, other.chipGreen),
      chipCoral: l(chipCoral, other.chipCoral),
      chipSun: l(chipSun, other.chipSun),
      chipSky: l(chipSky, other.chipSky),
      chipViolet: l(chipViolet, other.chipViolet),
    );
  }
}

extension EcoPaletteContext on BuildContext {
  EcoPalette get eco => Theme.of(this).extension<EcoPalette>()!;
}
