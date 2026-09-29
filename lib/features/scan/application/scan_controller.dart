import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../profile/data/document_picker.dart';
import '../domain/detection.dart';
import '../domain/image_quality.dart';
import '../domain/scan_record.dart';
import '../domain/scan_rules.dart';
import '../domain/waste_category.dart';
import 'scan_providers.dart';

enum ScanPhase { empty, preview, analyzing, result }

/// Photo du scan après anonymisation.
class ScanPhoto {
  const ScanPhoto({
    required this.jpeg,
    required this.width,
    required this.height,
    required this.metrics,
    this.issues = const {},
  });

  final Uint8List jpeg;
  final int width;
  final int height;
  final PhotoMetrics metrics;
  final Set<PhotoIssue> issues;

  ScanPhoto withIssues(Set<PhotoIssue> i) =>
      ScanPhoto(jpeg: jpeg, width: width, height: height, metrics: metrics, issues: i);
}

/// Erreurs affichables du scan.
enum ScanError { tooManyPhotos, unsupportedFormat, unreadablePhoto, modelUnavailable, saveFailed }

class ScanException implements Exception {
  const ScanException(this.error);
  final ScanError error;
}

class ScanState {
  const ScanState({
    this.phase = ScanPhase.empty,
    this.photos = const [],
    this.detections = const [],
    this.original = const [],
    this.threshold = defaultConfidenceThreshold,
    this.inferenceMs,
    this.scanId,
    this.busy = false,
    this.error,
    this.correctionsSaved = false,
  });

  final ScanPhase phase;
  final List<ScanPhoto> photos;

  /// Toutes les détections (y compris sous le seuil) et les ajouts manuels.
  final List<Detection> detections;
  final List<Detection> original;
  final double threshold;
  final int? inferenceMs;
  final String? scanId;
  final bool busy;
  final ScanError? error;
  final bool correctionsSaved;

  List<Detection> get visible => visibleDetections(detections, threshold);
  List<Detection> get visibleOriginal => visibleDetections(original, threshold);
  bool get canAddPhotos => photos.length < maxPhotosPerScan && phase != ScanPhase.analyzing;

  ScanState copyWith({
    ScanPhase? phase,
    List<ScanPhoto>? photos,
    List<Detection>? detections,
    List<Detection>? original,
    double? threshold,
    int? inferenceMs,
    String? scanId,
    bool? busy,
    ScanError? error,
    bool clearError = false,
    bool? correctionsSaved,
  }) => ScanState(
    phase: phase ?? this.phase,
    photos: photos ?? this.photos,
    detections: detections ?? this.detections,
    original: original ?? this.original,
    threshold: threshold ?? this.threshold,
    inferenceMs: inferenceMs ?? this.inferenceMs,
    scanId: scanId ?? this.scanId,
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
    correctionsSaved: correctionsSaved ?? this.correctionsSaved,
  );
}

/// Parcours de scan (US-011 à US-017) : import, contrôle qualité, analyse
/// YOLO sur l'appareil, seuil, corrections et enregistrement.
class ScanController extends Notifier<ScanState> {
  int _manualSeq = 0;

  @override
  ScanState build() {
    _purgeExpired();
    return ScanState(
      threshold:
          ref.read(visionConfigProvider).value?.confidenceThreshold ?? defaultConfidenceThreshold,
    );
  }

  /// Purge silencieuse des photos expirées de l'utilisateur (US-021).
  Future<void> _purgeExpired() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    try {
      await ref.read(scanRepositoryProvider).purgeExpired(uid: uid, now: ref.read(clockProvider)());
    } catch (_) {
      // Réessayée à la prochaine ouverture.
    }
  }

  List<WasteCategory> get _catalog => ref.read(catalogProvider).value ?? defaultCatalog;

  void _fail(ScanError e) => state = state.copyWith(error: e, busy: false);

  /// Ajoute des photos (appareil photo ou galerie, 5 maximum, JPG/PNG).
  Future<void> addPhotos(PickSource source) async {
    final remaining = maxPhotosPerScan - state.photos.length;
    if (remaining <= 0) return _fail(ScanError.tooManyPhotos);
    final picked = await ref.read(scanImagePickerProvider).pick(source, max: remaining);
    if (!ref.mounted || picked.isEmpty) return;
    state = state.copyWith(busy: true, clearError: true);
    final process = ref.read(photoProcessorProvider);
    final added = <ScanPhoto>[];
    ScanError? error;
    for (final f in picked) {
      if (!isAllowedImage(f.name)) {
        error = ScanError.unsupportedFormat;
        continue;
      }
      try {
        final p = await process(f.bytes);
        added.add(
          ScanPhoto(
            jpeg: p.jpeg,
            width: p.width,
            height: p.height,
            metrics: p.metrics,
            issues: photoIssues(p.metrics),
          ),
        );
      } catch (_) {
        error = ScanError.unreadablePhoto;
      }
    }
    if (!ref.mounted) return;
    state = ScanState(
      phase: [...state.photos, ...added].isEmpty ? ScanPhase.empty : ScanPhase.preview,
      photos: [...state.photos, ...added],
      threshold: state.threshold,
      error: error,
    );
  }

  void removePhoto(int index) {
    final photos = [...state.photos]..removeAt(index);
    state = ScanState(
      phase: photos.isEmpty ? ScanPhase.empty : ScanPhase.preview,
      photos: photos,
      threshold: state.threshold,
    );
  }

  /// Analyse toutes les photos puis enregistre automatiquement le scan.
  Future<void> analyze() async {
    if (state.photos.isEmpty || state.phase == ScanPhase.analyzing) return;
    state = state.copyWith(phase: ScanPhase.analyzing, busy: true, clearError: true);
    final detector = ref.read(wasteDetectorProvider);
    final model = ref.read(activeModelProvider);
    final catalog = _catalog;
    final watch = Stopwatch()..start();
    final all = <Detection>[];
    final photos = <ScanPhoto>[];
    try {
      for (final (i, p) in state.photos.indexed) {
        final raw = await detector.detect(p.jpeg, model);
        final dets = toDetections(raw, catalog, photoIndex: i);
        all.addAll(dets);
        final boxes = [for (final d in visibleDetections(dets, state.threshold)) d.box!];
        photos.add(p.withIssues(photoIssues(p.metrics, boxes: boxes)));
      }
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: ScanPhase.preview,
        busy: false,
        error: ScanError.modelUnavailable,
      );
      return;
    }
    watch.stop();
    if (!ref.mounted) return;
    state = state.copyWith(
      phase: ScanPhase.result,
      photos: photos,
      detections: all,
      original: all,
      inferenceMs: watch.elapsedMilliseconds,
    );
    await _save();
  }

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final s = state;
    final consent = ref.read(currentProfileProvider).value?.aiTrainingConsent ?? false;
    try {
      final id = await ref
          .read(scanRepositoryProvider)
          .save(
            ScanRecord(
              id: '',
              uid: uid,
              photoCount: s.photos.length,
              detections: s.visible,
              originalDetections: s.visibleOriginal,
              modelVersionId: ref.read(activeModelProvider).id,
              threshold: s.threshold,
              inferenceMs: s.inferenceMs,
              trainingConsent: consent,
            ),
            [for (final p in s.photos) (jpeg: p.jpeg, width: p.width, height: p.height)],
            _catalog,
            now: ref.read(clockProvider)(),
          );
      if (ref.mounted) state = state.copyWith(scanId: id, busy: false);
    } catch (_) {
      if (ref.mounted) _fail(ScanError.saveFailed);
    }
  }

  /// Seuil de confiance d'affichage (US-013).
  void setThreshold(double value) =>
      state = state.copyWith(threshold: value.clamp(inferenceFloor, .95), correctionsSaved: false);

  // --- Corrections manuelles (US-016) ---

  void relabel(String detectionId, String categoryId) => state = state.copyWith(
    detections: [for (final d in state.detections) d.id == detectionId ? d.relabel(categoryId) : d],
    correctionsSaved: false,
  );

  void remove(String detectionId) => state = state.copyWith(
    detections: state.detections.where((d) => d.id != detectionId).toList(),
    correctionsSaved: false,
  );

  void addManual(String categoryId, {int photoIndex = 0}) => state = state.copyWith(
    detections: [
      ...state.detections,
      Detection(
        id: 'manual-${_manualSeq++}',
        photoIndex: photoIndex,
        categoryId: categoryId,
        confidence: 1,
        source: DetectionSource.manual,
      ),
    ],
    correctionsSaved: false,
  );

  /// Enregistre les corrections sur le scan sauvegardé.
  Future<bool> saveCorrections() async {
    final id = state.scanId;
    if (id == null) return false;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final consent = ref.read(currentProfileProvider).value?.aiTrainingConsent;
      await ref
          .read(scanRepositoryProvider)
          .updateDetections(id, state.visible, _catalog, trainingConsent: consent);
      if (ref.mounted) state = state.copyWith(busy: false, correctionsSaved: true);
      return true;
    } catch (_) {
      if (ref.mounted) _fail(ScanError.saveFailed);
      return false;
    }
  }

  /// Consentement au partage des corrections pour l'entraînement (US-020).
  Future<void> setTrainingConsent(bool value) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    await ref.read(userProfileRepositoryProvider).updateAiTrainingConsent(uid, value);
  }

  void reset() => state = ScanState(threshold: state.threshold);
}

final scanControllerProvider = NotifierProvider<ScanController, ScanState>(ScanController.new);
