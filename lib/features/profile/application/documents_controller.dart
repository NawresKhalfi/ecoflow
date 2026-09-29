import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/action_controller.dart';
import '../data/document_picker.dart';
import '../domain/collector_document.dart';
import 'profile_providers.dart';

/// Fichier trop volumineux même après compression.
class DocumentTooLarge implements Exception {
  const DocumentTooLarge();
}

/// Dossier de vérification du collecteur (US-006).
class DocumentsController extends ActionController {
  Future<bool> pickAndUpload(CollectorDocumentType type, PickSource source) =>
      run(() async {
        final file = await ref.read(documentPickerProvider).pick(source);
        if (file == null) return;
        if (file.bytes.length > maxDocumentBytes) throw const DocumentTooLarge();
        await ref
            .read(documentsRepositoryProvider)
            .upload(requireUid(ref), type, file.name, file.bytes);
      });

  Future<bool> submit() =>
      run(() => ref.read(documentsRepositoryProvider).submitForReview(requireUid(ref)));
}

final documentsControllerProvider =
    NotifierProvider.autoDispose<DocumentsController, AsyncValue<void>>(
        DocumentsController.new);
