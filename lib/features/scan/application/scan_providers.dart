import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../vision_admin/data/model_registry_repository.dart';
import '../../vision_admin/domain/model_version.dart';
import '../data/catalog_repository.dart';
import '../data/photo_processor.dart';
import '../data/scan_image_picker.dart';
import '../data/scan_repository.dart';
import '../data/waste_detector.dart';
import '../domain/waste_category.dart';

final wasteDetectorProvider = Provider<WasteDetector>((ref) => YoloWasteDetector());
final scanImagePickerProvider = Provider<ScanImagePicker>((ref) => ImagePickerScanPicker());

/// Traitement des photos, injectable (les tests évitent l'isolate).
final photoProcessorProvider = Provider<Future<ProcessedPhoto> Function(Uint8List)>(
  (ref) => processPhoto,
);

final scanRepositoryProvider = Provider<ScanRepository>(
  (ref) => FirestoreScanRepository(ref.watch(firestoreProvider)),
);
final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => FirestoreCatalogRepository(ref.watch(firestoreProvider)),
);
final modelRegistryRepositoryProvider = Provider<ModelRegistryRepository>(
  (ref) => FirestoreModelRegistryRepository(ref.watch(firestoreProvider)),
);

final catalogProvider = StreamProvider<List<WasteCategory>>(
  (ref) => ref.watch(catalogRepositoryProvider).watch(),
);

final visionConfigProvider = StreamProvider<VisionConfig>(
  (ref) => ref.watch(modelRegistryRepositoryProvider).watchConfig(),
);

final modelVersionsProvider = StreamProvider<List<ModelVersion>>(
  (ref) => ref.watch(modelRegistryRepositoryProvider).watchVersions(),
);

/// Version du modèle à utiliser (repli : modèle embarqué).
final activeModelProvider = Provider<ModelVersion>((ref) {
  final id = ref.watch(visionConfigProvider).value?.activeVersionId ?? bundledModel.id;
  final versions = ref.watch(modelVersionsProvider).value ?? const [bundledModel];
  return versions.where((v) => v.id == id).firstOrNull ?? bundledModel;
});
