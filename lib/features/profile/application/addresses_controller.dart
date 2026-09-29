import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/action_controller.dart';
import '../domain/address.dart';
import 'profile_providers.dart';

/// Ajout / modification / suppression d'adresses et adresse par défaut (US-005).
class AddressesController extends ActionController {
  Future<bool> save(SavedAddress a) =>
      run(() => ref.read(addressRepositoryProvider).save(requireUid(ref), a));

  Future<bool> delete(String id) =>
      run(() => ref.read(addressRepositoryProvider).delete(requireUid(ref), id));

  Future<bool> setDefault(String id) =>
      run(() => ref.read(addressRepositoryProvider).setDefault(requireUid(ref), id));

  /// Position GPS courante, ou `null` si indisponible / refusée.
  Future<({double latitude, double longitude})?> locate() =>
      ref.read(locationServiceProvider).currentPosition();
}

final addressesControllerProvider =
    NotifierProvider.autoDispose<AddressesController, AsyncValue<void>>(
        AddressesController.new);
