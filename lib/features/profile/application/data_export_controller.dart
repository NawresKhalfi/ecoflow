import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/action_controller.dart';
import '../../auth/application/auth_providers.dart';
import '../../recycler/application/recycler_providers.dart';
import '../../vision_admin/application/vision_admin_controllers.dart';
import '../data/personal_data_export.dart';

/// Export de mes données (US-127) : fichier JSON partagé par la feuille
/// native (enregistrer, envoyer par e-mail…).
class DataExportController extends ActionController {
  @override
  AsyncValue<void> build() {
    ref.watch(currentUidProvider);
    return super.build();
  }

  String? lastPath;

  Future<bool> export() => run(() async {
    final uid = ref.read(currentUidProvider)!;
    final now = ref.read(clockProvider)();
    final data = await collectPersonalData(
      ref.read(firestoreProvider),
      uid,
      now: now,
      role: ref.read(sessionProvider).role?.name,
    );
    final dir = await ref.read(exportDirectoryProvider)();
    final day = now.toIso8601String().substring(0, 10);
    final file = File('${dir.path}/ecoflow-mes-donnees-$day.json');
    await file.writeAsString(encodeExport(data));
    lastPath = file.path;
    await ref.read(fileSharerProvider)(file.path);
  });
}

final dataExportControllerProvider =
    NotifierProvider.autoDispose<DataExportController, AsyncValue<void>>(DataExportController.new);
