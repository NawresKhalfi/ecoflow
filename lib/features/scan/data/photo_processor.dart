import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../domain/image_quality.dart';

/// Photo prête pour l'analyse et le stockage.
class ProcessedPhoto {
  const ProcessedPhoto({
    required this.jpeg,
    required this.width,
    required this.height,
    required this.metrics,
  });

  /// JPEG ré-encodé sans aucune métadonnée (EXIF, GPS…) — US-021.
  final Uint8List jpeg;
  final int width;
  final int height;
  final PhotoMetrics metrics;
}

/// Photo illisible (format non supporté ou fichier corrompu).
class UnreadablePhoto implements Exception {
  const UnreadablePhoto();
}

/// Taille maximale conservée : suffisante pour le modèle (512 px) et
/// compatible avec la limite de 1 Mio d'un document Firestore.
const maxPhotoSide = 1024;

/// Décode, redresse (orientation EXIF), réduit, mesure la qualité et
/// ré-encode l'image sans métadonnées. Exécuté hors du thread UI.
Future<ProcessedPhoto> processPhoto(Uint8List original) => compute(processPhotoSync, original);

ProcessedPhoto processPhotoSync(Uint8List original) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(original);
  } catch (_) {
    decoded = null; // octets corrompus : le décodeur peut lever n'importe quoi
  }
  if (decoded == null) throw const UnreadablePhoto();
  var image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > maxPhotoSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxPhotoSide)
        : img.copyResize(image, height: maxPhotoSide);
  }
  // Nouvelle image sans EXIF, ICC ni texte : aucune donnée de localisation.
  final clean = img.Image.from(image)..exif = img.ExifData();
  final jpeg = img.encodeJpg(clean, quality: 78);

  final small = img.grayscale(img.copyResize(clean, width: 256));
  final gray = Uint8List(small.width * small.height);
  var i = 0;
  for (final p in small) {
    gray[i++] = p.r.toInt();
  }
  return ProcessedPhoto(
    jpeg: jpeg,
    width: clean.width,
    height: clean.height,
    metrics: measurePhoto(gray, small.width, small.height),
  );
}
