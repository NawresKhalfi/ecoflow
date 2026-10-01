import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/action_controller.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/user_role.dart';
import '../../collection/application/collection_providers.dart';
import '../../estimation/application/estimation_providers.dart';
import '../../scan/application/scan_providers.dart';
import '../../scan/domain/waste_category.dart';
import '../../wallet/application/wallet_providers.dart';
import '../../wallet/domain/wallet.dart';
import '../data/challenge_repository.dart';
import '../domain/challenge.dart';
import '../domain/impact.dart';

/// Tableau de bord personnel (US-118, US-119).
final personalImpactProvider = Provider<PersonalImpact>(
  (ref) => personalImpact(
    estimates: ref.watch(myEstimatesProvider).value ?? const [],
    entries: ref.watch(myEntriesProvider).value ?? const [],
    catalog: ref.watch(catalogProvider).value ?? defaultCatalog,
    now: ref.watch(clockProvider)(),
  ),
);

/// Partage natif d'une image avec un texte (US-122) ; surchargé en test.
typedef ImageSharer = Future<void> Function(String path, String text);
final imageSharerProvider = Provider<ImageSharer>(
  (_) =>
      (path, text) => SharePlus.instance.share(ShareParams(files: [XFile(path)], text: text)),
);

final challengeRepositoryProvider = Provider<ChallengeRepository>(
  (ref) => ChallengeRepository(ref.watch(firestoreProvider)),
);

final challengesProvider = StreamProvider<List<Challenge>>(
  (ref) => ref.watch(challengeRepositoryProvider).watchChallenges(),
);

final challengeProvider = StreamProvider.family<Challenge?, String>(
  (ref, id) => ref.watch(challengeRepositoryProvider).watch(id),
);

final participantsProvider = StreamProvider.family<List<Participant>, String>(
  (ref, id) => ref.watch(challengeRepositoryProvider).watchParticipants(id),
);

final myParticipationProvider = StreamProvider.family<Participant?, String>((ref, id) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(challengeRepositoryProvider).watchMe(id, uid);
});

/// Zones où le citoyen a demandé des collectes, la plus fréquente d'abord.
final myZonesProvider = Provider<List<String>>((ref) {
  final count = <String, int>{};
  for (final c in ref.watch(myCollectionsProvider).value ?? const []) {
    if (c.place.zoneId.isNotEmpty) count[c.place.zoneId] = (count[c.place.zoneId] ?? 0) + 1;
  }
  return (count.keys.toList()..sort((a, b) => count[b]!.compareTo(count[a]!)));
});

/// Défis visibles : tous pour l'administration, nationaux ou de mes zones
/// pour un citoyen.
final visibleChallengesProvider = Provider<List<Challenge>>((ref) {
  final all = ref.watch(challengesProvider).value ?? const <Challenge>[];
  if (ref.watch(sessionProvider).role == UserRole.admin) return all;
  final zones = ref.watch(myZonesProvider).toSet();
  return [
    for (final c in all)
      if (c.visibleFor(zones)) c,
  ];
});

/// Défis dont la récompense a déjà été créditée.
final claimedChallengesProvider = Provider<Set<String>>(
  (ref) => {
    for (final e in ref.watch(myEntriesProvider).value ?? const <LedgerEntry>[])
      if (e.type == EntryType.challenge && e.challengeId != null) e.challengeId!,
  },
);

/// Reporte les kilos du citoyen sur ses défis en cours ; les défis où il
/// n'est pas inscrit sont ignorés. Utilisé à l'ouverture d'un défi et après
/// chaque gain (écoute du wallet dans le shell).
Future<double> syncChallenges(
  ChallengeRepository repo,
  String? uid,
  List<Challenge> challenges,
  DateTime now,
) async {
  if (uid == null) return 0;
  var total = 0.0;
  for (final c in challenges.where((c) => c.status(now) == ChallengeStatus.active)) {
    try {
      total += await repo.sync(c.id, uid);
    } catch (_) {
      // Hors ligne ou défi clos entre-temps : nouvel essai au prochain gain.
    }
  }
  return total;
}

/// Actions sur les défis (US-121).
class ChallengeController extends ActionController {
  @override
  AsyncValue<void> build() {
    ref.watch(currentUidProvider);
    ref.watch(currentProfileProvider);
    return super.build();
  }

  ChallengeRepository get _repo => ref.read(challengeRepositoryProvider);
  String get _uid => ref.read(currentUidProvider)!;
  ({String uid, String name}) get _actor =>
      (uid: _uid, name: ref.read(currentProfileProvider).value?.displayName ?? '');
  DateTime get _now => ref.read(clockProvider)();

  Future<bool> join(Challenge c) => run(() async {
    if (c.status(_now) != ChallengeStatus.active) throw const ChallengeClosed();
    final zones = ref.read(myZonesProvider);
    await _repo.join(
      c.id,
      _uid,
      name: publicName(ref.read(currentProfileProvider).value?.displayName ?? ''),
      zoneId: c.zoneId ?? zones.firstOrNull,
    );
  });

  Future<bool> claim(Challenge c) => run(() async {
    final me = await ref.read(challengeRepositoryProvider).watchMe(c.id, _uid).first;
    final claimed = ref.read(claimedChallengesProvider).contains(c.id);
    if (!canClaim(c, me, _now, claimed: claimed)) throw const ChallengeClosed();
    await _repo.claim(c, _uid);
  });

  /// Reporte mes kilos sur mes défis en cours (sans changer l'état affiché).
  Future<double> syncActive(List<Challenge> challenges) =>
      syncChallenges(_repo, ref.read(currentUidProvider), challenges, _now);

  Future<bool> create(Challenge draft) => run(() async {
    final error = validateChallenge(
      title: draft.title,
      goalKg: draft.goalKg,
      rewardPoints: draft.rewardPoints,
      startAt: draft.startAt,
      endAt: draft.endAt,
    );
    if (error != null) throw ArgumentError(error.name);
    await _repo.create(_actor, draft);
  });

  Future<bool> delete(Challenge c) => run(() => _repo.delete(_actor, c));
}

final challengeControllerProvider =
    NotifierProvider.autoDispose<ChallengeController, AsyncValue<void>>(ChallengeController.new);

/// Écoute du wallet (citoyen) : chaque hausse des kilos est reportée sur
/// les défis en cours, de même qu'au premier chargement (rattrapage).
final challengeSyncProvider = Provider<void>((ref) {
  ref.listen(challengesProvider, (_, _) {});
  ref.listen(myWalletProvider, (prev, next) {
    final after = next.value?.kg;
    final before = prev?.value?.kg;
    if (after == null || (before != null && after <= before)) return;
    syncChallenges(
      ref.read(challengeRepositoryProvider),
      ref.read(currentUidProvider),
      ref.read(challengesProvider).value ?? const [],
      ref.read(clockProvider)(),
    );
  });
});
