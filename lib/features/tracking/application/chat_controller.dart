import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/action_controller.dart';
import '../../auth/application/auth_providers.dart';
import '../../collection/application/collection_providers.dart';
import '../domain/app_notification.dart';
import '../domain/chat.dart';
import 'tracking_providers.dart';

class InvalidMessage implements Exception {
  const InvalidMessage();
}

/// Messagerie citoyen ↔ collecteur (US-067).
class ChatController extends ActionController {
  Future<bool> send(String collectionId, String text) => run(() async {
    if (validateMessage(text) != null) throw const InvalidMessage();
    final uid = ref.read(authRepositoryProvider).currentUser!.uid;
    await ref.read(chatRepositoryProvider).send(collectionId, uid, text);
    final r = await ref.read(collectionRepositoryProvider).fetch(collectionId);
    if (r == null) return;
    final other = uid == r.citizenUid ? r.collectorUid : r.citizenUid;
    await notify(
      ref,
      toUid: other,
      type: NotificationType.message,
      r: r,
      preview: maskPhoneNumbers(text.trim()),
    );
  });
}

final chatControllerProvider = NotifierProvider.autoDispose<ChatController, AsyncValue<void>>(
  ChatController.new,
);
