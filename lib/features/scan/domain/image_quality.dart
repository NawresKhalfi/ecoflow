import 'dart:typed_data';

import 'detection.dart';

/// Problèmes de prise de vue détectables avant l'analyse (US-017).
enum PhotoIssue { blurry, dark, badFraming }

/// Seuils calibrés sur des images réduites à ~256 px de large.
class PhotoQualityThresholds {
  const PhotoQualityThresholds({
    this.minBrightness = 55,
    this.minSharpness = 60,
    this.minObjectArea = .03,
  });

  /// Luminance moyenne minimale (0..255).
  final double minBrightness;

  /// Variance minimale du laplacien (netteté).
  final double minSharpness;

  /// Surface minimale (fraction de l'image) du plus grand objet détecté.
  final double minObjectArea;
}

/// Mesures d'une image en niveaux de gris.
class PhotoMetrics {
  const PhotoMetrics({required this.brightness, required this.sharpness});

  final double brightness;
  final double sharpness;
}

/// Luminance moyenne et variance du laplacien (4-voisins) d'une image en
/// niveaux de gris de [width]×[height] pixels.
PhotoMetrics measurePhoto(Uint8List gray, int width, int height) {
  var sum = 0.0;
  for (final v in gray) {
    sum += v;
  }
  final brightness = gray.isEmpty ? 0.0 : sum / gray.length;
  var lapSum = 0.0, lapSq = 0.0, n = 0;
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final i = y * width + x;
      final lap = gray[i - 1] + gray[i + 1] + gray[i - width] + gray[i + width] - 4 * gray[i];
      lapSum += lap;
      lapSq += lap * lap;
      n++;
    }
  }
  final mean = n == 0 ? 0 : lapSum / n;
  final variance = n == 0 ? 0.0 : lapSq / n - mean * mean;
  return PhotoMetrics(brightness: brightness, sharpness: variance);
}

/// Problèmes détectés sur une photo. Le cadrage est jugé mauvais quand
/// aucun objet n'est reconnu ou que tous sont minuscules.
Set<PhotoIssue> photoIssues(
  PhotoMetrics m, {
  List<BoundingBox>? boxes,
  PhotoQualityThresholds t = const PhotoQualityThresholds(),
}) => {
  if (m.brightness < t.minBrightness) PhotoIssue.dark,
  if (m.sharpness < t.minSharpness) PhotoIssue.blurry,
  if (boxes != null && (boxes.isEmpty || boxes.every((b) => b.area < t.minObjectArea)))
    PhotoIssue.badFraming,
};
