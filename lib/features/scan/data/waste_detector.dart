import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../vision_admin/domain/model_version.dart';
import '../domain/detection.dart';
import '../domain/scan_rules.dart';

/// Modèle de vision indisponible (chargement impossible).
class DetectorUnavailable implements Exception {
  const DetectorUnavailable(this.cause);
  final Object cause;
}

/// Détection d'objets sur une image, exécutée sur l'appareil (hors ligne).
abstract interface class WasteDetector {
  Future<List<RawDetection>> detect(Uint8List jpeg, ModelVersion model);
}

/// Implémentation YOLO (Core ML sur iOS, LiteRT sur Android).
class YoloWasteDetector implements WasteDetector {
  YOLO? _yolo;
  String? _loadedPath;

  String _pathFor(ModelVersion m) => Platform.isIOS ? m.iosModel : m.androidModel;

  Future<YOLO> _ensure(ModelVersion model) async {
    // Détection embarquée (Core ML / LiteRT) : indisponible dans un navigateur.
    if (kIsWeb) throw const DetectorUnavailable('web');
    final path = _pathFor(model);
    if (_yolo != null && _loadedPath == path) return _yolo!;
    try {
      final yolo = YOLO(modelPath: path, task: YOLOTask.detect);
      if (!await yolo.loadModel()) throw StateError('loadModel returned false');
      _yolo = yolo;
      _loadedPath = path;
      return yolo;
    } catch (e) {
      throw DetectorUnavailable(e);
    }
  }

  @override
  Future<List<RawDetection>> detect(Uint8List jpeg, ModelVersion model) async {
    final yolo = await _ensure(model);
    final result = await yolo.predict(jpeg, confidenceThreshold: inferenceFloor, iouThreshold: .5);
    return [
      for (final d in (result['detections'] as List? ?? const []))
        if (d is Map && d['normalizedBox'] is Map)
          RawDetection(
            label: '${d['className']}',
            confidence: (d['confidence'] as num?)?.toDouble() ?? 0,
            box: BoundingBox(
              _n(d['normalizedBox']['left']),
              _n(d['normalizedBox']['top']),
              _n(d['normalizedBox']['right']),
              _n(d['normalizedBox']['bottom']),
            ),
          ),
    ];
  }

  static double _n(Object? v) => ((v as num?)?.toDouble() ?? 0).clamp(0, 1);
}
