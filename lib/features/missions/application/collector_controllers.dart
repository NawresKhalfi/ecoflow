import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/action_controller.dart';
import '../../auth/application/auth_providers.dart';
import '../../collection/application/collection_providers.dart';
import '../../collection/domain/collection_request.dart';
import '../../collection/domain/geo.dart';
import '../../estimation/application/estimation_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../data/collector_repositories.dart';
import '../domain/deposit.dart';
import '../domain/earnings.dart';
import '../domain/vehicle.dart';
import 'missions_providers.dart';

/// Retrait refusé : montant hors limites (minimum ou solde).
class InvalidWithdrawal implements Exception {
  const InvalidWithdrawal();
}

/// Revenus : crédit des missions terminées et retraits (US-050 à US-052).
class EarningsController extends ActionController {
  /// Crédite chaque mission terminée qui n'a pas encore de revenu.
  Future<void> syncCompleted(List<CollectionRequest> missions, List<Earning> earnings) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final credited = {for (final e in earnings) e.missionId};
    for (final m in missions.where(
      (m) => m.status == CollectionStatus.completed && !credited.contains(m.id),
    )) {
      final w = (await ref.read(estimateRepositoryProvider).fetch(m.estimateCode))?.weighing;
      if (w == null) continue;
      await ref
          .read(earningsRepositoryProvider)
          .ensureEarning(missionId: m.id, uid: uid, amountDt: w.finalDt, kg: w.actualKg);
    }
  }

  Future<bool> withdraw(double amount, PayoutMethod method) => run(() async {
    final balance = availableBalance(
      ref.read(earningsProvider).value ?? const [],
      ref.read(payoutsProvider).value ?? const [],
    );
    if (!canWithdraw(balance, amount)) throw const InvalidWithdrawal();
    await ref
        .read(earningsRepositoryProvider)
        .requestPayout(ref.read(currentUidProvider)!, amount, method);
  });
}

final earningsControllerProvider =
    NotifierProvider.autoDispose<EarningsController, AsyncValue<void>>(EarningsController.new);

/// Véhicule (US-054) et zone de travail (US-042).
class CollectorSettingsController extends ActionController {
  Future<bool> saveVehicle(Vehicle v) =>
      run(() => ref.read(vehicleRepositoryProvider).save(ref.read(currentUidProvider)!, v));

  /// Zone centrée sur la position actuelle (ou la dernière connue).
  Future<bool> saveZone(double radiusKm, {GeoPoint? center}) => run(() async {
    var c = center ?? ref.read(myPresenceDataProvider).value?.point;
    if (c == null) {
      final pos = await ref.read(locationServiceProvider).currentPosition();
      if (pos != null) c = GeoPoint(pos.latitude, pos.longitude);
    }
    if (c == null) throw StateError('no position');
    await ref
        .read(presenceRepositoryProvider)
        .setWorkZone(ref.read(currentUidProvider)!, center: c, radiusKm: radiusKm);
  });
}

final collectorSettingsControllerProvider =
    NotifierProvider.autoDispose<CollectorSettingsController, AsyncValue<void>>(
      CollectorSettingsController.new,
    );

/// Dépôt de tournée (US-055) et revue par le recycleur.
class DepositController extends ActionController {
  /// Missions pesées pas encore déposées.
  List<CollectionRequest> depositable(List<CollectionRequest> mine) => [
    for (final m in mine)
      if ((m.status == CollectionStatus.completed || m.status == CollectionStatus.handedOver) &&
          m.depositId == null)
        m,
  ];

  Future<bool> deposit(Recycler recycler, List<CollectionRequest> missions) => run(() async {
    if (missions.isEmpty) throw StateError('empty');
    final estimates = ref.read(estimateRepositoryProvider);
    final perMission = <Map<String, double>>[];
    for (final m in missions) {
      perMission.add((await estimates.fetch(m.estimateCode))?.actualKg ?? const {});
    }
    await ref
        .read(depositRepositoryProvider)
        .create(
          Deposit(
            id: '',
            collectorUid: ref.read(currentUidProvider)!,
            recyclerUid: recycler.uid,
            recyclerName: recycler.name,
            missionIds: [for (final m in missions) m.id],
            byCategoryKg: aggregateByCategory(perMission),
          ),
        );
  });

  Future<bool> review(Deposit d, {required bool confirmed, String note = ''}) =>
      run(() => ref.read(depositRepositoryProvider).review(d.id, confirmed: confirmed, note: note));
}

final depositControllerProvider = NotifierProvider.autoDispose<DepositController, AsyncValue<void>>(
  DepositController.new,
);

/// Lecture d'une balance Bluetooth (US-049).
class ScaleState {
  const ScaleState({
    this.devices = const [],
    this.scanning = false,
    this.connectedId,
    this.kg,
    this.error,
  });
  final List<({String id, String name})> devices;
  final bool scanning;
  final String? connectedId;
  final double? kg;
  final Object? error;
}

class ScaleController extends Notifier<ScaleState> {
  StreamSubscription<Object?>? _sub;

  @override
  ScaleState build() {
    ref.onDispose(() => _sub?.cancel());
    return const ScaleState();
  }

  void scan() {
    _sub?.cancel();
    state = const ScaleState(scanning: true);
    _sub = ref
        .read(scaleServiceProvider)
        .scan()
        .listen(
          (d) => state = ScaleState(devices: d, scanning: true),
          onError: (Object e) => state = ScaleState(error: e),
          onDone: () => state = ScaleState(devices: state.devices),
        );
  }

  void connect(String id) {
    _sub?.cancel();
    state = ScaleState(devices: state.devices, connectedId: id);
    _sub = ref
        .read(scaleServiceProvider)
        .readings(id)
        .listen(
          (kg) => state = ScaleState(devices: state.devices, connectedId: id, kg: kg),
          onError: (Object e) => state = ScaleState(devices: state.devices, error: e),
        );
  }
}

final scaleControllerProvider = NotifierProvider.autoDispose<ScaleController, ScaleState>(
  ScaleController.new,
);

/// Horloge qui avance chaque seconde (compte à rebours des propositions).
final tickerProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) => clock());
});

/// Crédit automatique des missions terminées (à écouter dans l'espace
/// collecteur) : un revenu par mission, idempotent.
final earningsSyncProvider = Provider<void>((ref) {
  var running = false;
  Future<void> sync() async {
    if (running) return;
    running = true;
    try {
      await ref
          .read(earningsControllerProvider.notifier)
          .syncCompleted(
            ref.read(myMissionsProvider).value ?? const [],
            ref.read(earningsProvider).value ?? const [],
          );
    } catch (_) {
    } finally {
      running = false;
    }
  }

  final keep = ref.listen(earningsControllerProvider, (_, _) {});
  ref.onDispose(keep.close);
  ref.listen(myMissionsProvider, (_, _) => sync(), fireImmediately: true);
  ref.listen(earningsProvider, (_, _) => sync());
});
