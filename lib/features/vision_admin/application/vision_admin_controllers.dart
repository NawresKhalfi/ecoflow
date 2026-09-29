import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/action_controller.dart';
import '../../scan/application/scan_providers.dart';
import '../../scan/domain/waste_category.dart';
import '../data/dataset_exporter.dart';
import '../domain/model_version.dart';
import '../domain/yolo_dataset.dart';

/// CRUD du catalogue des classes de déchets (US-022).
class CatalogAdminController extends ActionController {
  Future<bool> save(WasteCategory c) => run(() => ref.read(catalogRepositoryProvider).save(c));
  Future<bool> delete(String id) => run(() => ref.read(catalogRepositoryProvider).delete(id));
  Future<bool> seedDefaults() => run(() => ref.read(catalogRepositoryProvider).seedDefaults());
}

final catalogAdminControllerProvider =
    NotifierProvider.autoDispose<CatalogAdminController, AsyncValue<void>>(
      CatalogAdminController.new,
    );

/// Versions du modèle, activation / retour arrière et seuil (US-019, US-013).
class ModelAdminController extends ActionController {
  VisionConfig get _config => ref.read(visionConfigProvider).value ?? const VisionConfig();

  Future<bool> addVersion(ModelVersion v) =>
      run(() => ref.read(modelRegistryRepositoryProvider).addVersion(v));

  Future<bool> activate(String versionId) =>
      run(() => ref.read(modelRegistryRepositoryProvider).saveConfig(_config.activate(versionId)));

  Future<bool> rollback() =>
      run(() => ref.read(modelRegistryRepositoryProvider).saveConfig(_config.rollback()));

  Future<bool> setThreshold(double t) =>
      run(() => ref.read(modelRegistryRepositoryProvider).saveConfig(_config.withThreshold(t)));
}

final modelAdminControllerProvider =
    NotifierProvider.autoDispose<ModelAdminController, AsyncValue<void>>(ModelAdminController.new);

/// Rien à exporter : aucun scan corrigé avec consentement.
class NothingToExport implements Exception {
  const NothingToExport();
}

/// Partage (ou enregistrement) d'un fichier produit par l'application.
typedef FileSharer = Future<void> Function(String path);

final fileSharerProvider = Provider<FileSharer>(
  (ref) =>
      (path) async => SharePlus.instance.share(ShareParams(files: [XFile(path)])),
);

/// Export des corrections au format YOLO (US-020).
class DatasetExportController extends ActionController {
  int lastExportCount = 0;

  /// Construit le ZIP ; exposé pour les tests.
  Future<Uint8List> buildZip() async {
    final repo = ref.read(scanRepositoryProvider);
    final catalog = ref.read(catalogProvider).value ?? defaultCatalog;
    final scans = await repo.correctedForTraining();
    final items = <DatasetItem>[];
    var n = 0;
    for (final s in scans) {
      final photos = await repo.photos(s.id);
      for (final (i, p) in photos.indexed) {
        items.add((
          jpeg: p.jpeg,
          annotations: AnnotatedImage(
            name: 'img_${(++n).toString().padLeft(5, '0')}',
            detections: s.detections.where((d) => d.photoIndex == i).toList(),
          ),
        ));
      }
    }
    if (items.isEmpty) throw const NothingToExport();
    lastExportCount = items.length;
    return buildYoloDatasetZip(items, catalog);
  }

  Future<bool> export() => run(() async {
    final zip = await buildZip();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ecoflow_yolo_dataset.zip');
    await file.writeAsBytes(zip);
    await ref.read(fileSharerProvider)(file.path);
  });
}

/// Purge globale des photos expirées (US-021, sans TTL côté serveur).
class PhotoPurgeController extends ActionController {
  int lastPurged = 0;

  Future<bool> purge() => run(() async {
    lastPurged = await ref
        .read(scanRepositoryProvider)
        .purgeExpired(now: ref.read(clockProvider)());
  });
}

final photoPurgeControllerProvider =
    NotifierProvider.autoDispose<PhotoPurgeController, AsyncValue<void>>(PhotoPurgeController.new);

final datasetExportControllerProvider =
    NotifierProvider.autoDispose<DatasetExportController, AsyncValue<void>>(
      DatasetExportController.new,
    );
