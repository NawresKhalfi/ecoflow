import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base des controllers « action » : l'état reflète la dernière opération
/// (chargement, succès, erreur typée) et [run] renvoie `true` si elle a réussi.
abstract class ActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  bool get isBusy => state.isLoading;

  Future<bool> run(Future<void> Function() action) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await action();
      if (ref.mounted) state = const AsyncData(null);
      return true;
    } catch (e, st) {
      if (ref.mounted) state = AsyncError(e, st);
      return false;
    }
  }
}
