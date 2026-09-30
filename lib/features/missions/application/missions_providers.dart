import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../collection/application/collection_providers.dart';
import '../../collection/domain/collection_request.dart';
import '../../collection/domain/geo.dart';
import '../data/collector_repositories.dart';
import '../data/mission_repository.dart';
import '../data/scale_service.dart';
import '../domain/deposit.dart';
import '../domain/earnings.dart';
import '../domain/mission_rules.dart';
import '../domain/vehicle.dart';
import '../domain/work_zone.dart';

final missionRepositoryProvider = Provider<MissionRepository>(
  (ref) => FirestoreMissionRepository(ref.watch(firestoreProvider)),
);
final earningsRepositoryProvider = Provider<EarningsRepository>(
  (ref) => FirestoreEarningsRepository(ref.watch(firestoreProvider)),
);
final vehicleRepositoryProvider = Provider<VehicleRepository>(
  (ref) => FirestoreVehicleRepository(ref.watch(firestoreProvider)),
);
final depositRepositoryProvider = Provider<DepositRepository>(
  (ref) => FirestoreDepositRepository(ref.watch(firestoreProvider)),
);
final scaleServiceProvider = Provider<ScaleService>((ref) => BleScaleService());

Stream<T> _forUid<T>(Ref ref, T empty, Stream<T> Function(String) f) {
  final uid = ref.watch(currentUidProvider);
  return uid == null ? Stream.value(empty) : f(uid);
}

final openMissionsProvider = StreamProvider<List<CollectionRequest>>(
  (ref) => ref.watch(missionRepositoryProvider).watchOpen(),
);
final proposedToMeProvider = StreamProvider<List<CollectionRequest>>(
  (ref) => _forUid(ref, const [], ref.watch(missionRepositoryProvider).watchProposedTo),
);
final myMissionsProvider = StreamProvider<List<CollectionRequest>>(
  (ref) => _forUid(ref, const [], ref.watch(missionRepositoryProvider).watchMine),
);
final earningsProvider = StreamProvider<List<Earning>>(
  (ref) => _forUid(ref, const [], ref.watch(earningsRepositoryProvider).watchEarnings),
);
final payoutsProvider = StreamProvider<List<Payout>>(
  (ref) => _forUid(ref, const [], ref.watch(earningsRepositoryProvider).watchPayouts),
);
final vehicleProvider = StreamProvider<Vehicle?>(
  (ref) => _forUid(ref, null, ref.watch(vehicleRepositoryProvider).watch),
);
final myDepositsProvider = StreamProvider<List<Deposit>>(
  (ref) => _forUid(ref, const [], ref.watch(depositRepositoryProvider).watchByCollector),
);
final incomingDepositsProvider = StreamProvider<List<Deposit>>(
  (ref) => _forUid(ref, const [], ref.watch(depositRepositoryProvider).watchIncoming),
);
final approvedRecyclersProvider = FutureProvider<List<Recycler>>(
  (ref) => ref.watch(depositRepositoryProvider).approvedRecyclers(),
);
final hasProofProvider = StreamProvider.family<bool, String>(
  (ref, id) => watchHasProof(ref.watch(firestoreProvider), id),
);

/// Disponibilité : position arrondie et zone de travail du collecteur.
final myPresenceDataProvider = StreamProvider<({GeoPoint? point, WorkZone? zone, bool online})>((
  ref,
) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value((point: null, zone: null, online: false));
  return ref
      .watch(presenceRepositoryProvider)
      .watch(uid)
      .map(
        (m) => (
          point: GeoPoint.fromMap(m['point']),
          zone: WorkZone.fromMap(m['workZone']),
          online: m['online'] as bool? ?? false,
        ),
      );
});

class MissionFilterController extends Notifier<MissionFilter> {
  @override
  MissionFilter build() => const MissionFilter();
  void set(MissionFilter f) => state = f;
}

final missionFilterProvider = NotifierProvider<MissionFilterController, MissionFilter>(
  MissionFilterController.new,
);

/// Missions acceptables autour du collecteur, filtrées et triées (US-043).
final availableMissionsProvider = Provider<List<(CollectionRequest, double?)>>((ref) {
  final uid = ref.watch(currentUidProvider) ?? '';
  final now = ref.watch(clockProvider)();
  final presence = ref.watch(myPresenceDataProvider).value;
  // Mes propositions restent visibles même expirées : la carte les refuse
  // automatiquement et les rend aux autres collecteurs (sinon la demande
  // resterait bloquée tant que l'application du citoyen est fermée).
  final all = {
    for (final r in ref.watch(openMissionsProvider).value ?? const <CollectionRequest>[])
      if (canAccept(r, uid, now)) r.id: r,
    for (final r in ref.watch(proposedToMeProvider).value ?? const <CollectionRequest>[])
      if (!r.refusedBy.contains(uid)) r.id: r,
  }.values.toList();
  return selectMissions(
    all,
    filter: ref.watch(missionFilterProvider),
    from: presence?.point,
    zone: presence?.zone,
  );
});
