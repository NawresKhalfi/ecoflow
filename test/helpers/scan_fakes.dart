import 'dart:typed_data';

import 'package:ecoflow/features/profile/data/document_picker.dart';
import 'package:ecoflow/features/scan/data/photo_processor.dart';
import 'package:ecoflow/features/scan/data/scan_image_picker.dart';
import 'package:ecoflow/features/scan/data/waste_detector.dart';
import 'package:ecoflow/features/scan/domain/detection.dart';
import 'package:ecoflow/features/vision_admin/domain/model_version.dart';
import 'package:image/image.dart' as img;

/// JPEG de test : damier net et bien éclairé (ou uniforme sombre).
Uint8List testJpeg({bool dark = false, int size = 96}) {
  final image = img.Image(width: size, height: size);
  for (final p in image) {
    final on = ((p.x ~/ 6) + (p.y ~/ 6)).isEven;
    final v = dark ? 15 : (on ? 235 : 80);
    p
      ..r = v
      ..g = v
      ..b = v;
  }
  return img.encodeJpg(image);
}

class FakeScanPicker implements ScanImagePicker {
  List<PickedFile> next = [];
  int? lastMax;

  @override
  Future<List<PickedFile>> pick(PickSource source, {required int max}) async {
    lastMax = max;
    return next.take(max).toList();
  }
}

class FakeDetector implements WasteDetector {
  List<RawDetection> result = const [];
  bool fail = false;
  final seenModels = <String>[];

  @override
  Future<List<RawDetection>> detect(Uint8List jpeg, ModelVersion model) async {
    seenModels.add(model.id);
    if (fail) throw const DetectorUnavailable('boom');
    return result;
  }
}

/// Traitement synchrone (pas d'isolate dans les tests).
Future<ProcessedPhoto> syncProcessor(Uint8List bytes) async => processPhotoSync(bytes);

RawDetection rawDet(String label, double conf) =>
    RawDetection(label: label, confidence: conf, box: const BoundingBox(.1, .1, .7, .7));
