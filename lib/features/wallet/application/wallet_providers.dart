import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/action_controller.dart';
import '../../auth/application/auth_providers.dart';
import '../../collection/application/collection_providers.dart';
import '../../collection/domain/collection_request.dart';
import '../data/rewards_repository.dart';
import '../data/wallet_repository.dart';
import '../domain/points_rules.dart';
import '../domain/rewards.dart';
import '../domain/wallet.dart';

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepository(ref.watch(firestoreProvider)),
);
final rewardsRepositoryProvider = Provider<RewardsRepository>(
  (ref) => RewardsRepository(ref.watch(firestoreProvider)),
);
final pointsRulesRepositoryProvider = Provider<PointsRulesRepository>(
  (ref) => PointsRulesRepository(ref.watch(firestoreProvider)),
);

final pointsRulesProvider = StreamProvider<PointsRules>(
  (ref) => ref.watch(pointsRulesRepositoryProvider).watch(),
);
final pointsRulesHistoryProvider = StreamProvider(
  (ref) => ref.watch(pointsRulesRepositoryProvider).watchHistory(),
);

final myWalletProvider = StreamProvider<Wallet>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const Wallet());
  return ref.watch(walletRepositoryProvider).watch(uid);
});

final myEntriesProvider = StreamProvider<List<LedgerEntry>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(walletRepositoryProvider).watchEntries(uid);
});

final rewardsProvider = StreamProvider<List<Reward>>(
  (ref) => ref.watch(rewardsRepositoryProvider).watchRewards(),
);
final partnersProvider = StreamProvider<List<Partner>>(
  (ref) => ref.watch(rewardsRepositoryProvider).watchPartners(),
);

final myRedemptionsProvider = StreamProvider<List<Redemption>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(rewardsRepositoryProvider).watchMine(uid);
});

final heldEntriesProvider = StreamProvider<List<LedgerEntry>>(
  (ref) => ref.watch(walletRepositoryProvider).watchHeld(),
);

/// Crédite une collecte terminée ; `null` si déjà créditée ou non pesée.
Future<LedgerEntry?> awardCollection(Ref ref, CollectionRequest r) async {
  // Lecture ponctuelle : un provider non écouté reste en pause (Riverpod 3).
  final rules = await ref.read(pointsRulesRepositoryProvider).watch().first;
  return ref
      .read(walletRepositoryProvider)
      .awardCollection(
        uid: r.citizenUid,
        collectionId: r.id,
        estimateCode: r.estimateCode,
        rules: rules,
        now: ref.read(clockProvider)(),
      );
}

/// Rattrapage, une fois par ouverture du wallet : collectes terminées sans
/// gain (échec réseau, collectes antérieures au wallet) et points arrivés
/// à échéance. Lectures ponctuelles : les écritures ne le relancent pas.
final walletSyncProvider = FutureProvider.autoDispose<void>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return;
  final collections = await ref.read(collectionRepositoryProvider).watchMine(uid).first;
  final entries = await ref.read(walletRepositoryProvider).watchEntries(uid).first;
  final rules = await ref.read(pointsRulesRepositoryProvider).watch().first;
  final credited = {for (final e in entries) e.collectionId};
  for (final c in collections) {
    if (c.status == CollectionStatus.completed && !credited.contains(c.id)) {
      try {
        await awardCollection(ref, c);
      } catch (_) {
        // Réessayé à la prochaine ouverture du wallet.
      }
    }
  }
  await ref
      .read(walletRepositoryProvider)
      .expireDue(uid, entries, rules.expiryMonths, ref.read(clockProvider)());
});

/// Actions du citoyen sur son wallet (US-073, US-077).
class WalletController extends ActionController {
  /// Garde la session active tant que l'écran utilise le contrôleur.
  @override
  AsyncValue<void> build() {
    ref.watch(currentUidProvider);
    return super.build();
  }

  String? lastRedemptionId;
  String? referralCode;

  String get _uid => ref.read(currentUidProvider)!;

  Future<bool> redeem(Reward r) => run(() async {
    lastRedemptionId = await ref.read(walletRepositoryProvider).redeem(_uid, r);
  });

  Future<bool> loadReferralCode() => run(() async {
    referralCode = await ref.read(walletRepositoryProvider).ensureReferralCode(_uid);
  });

  Future<bool> applyReferral(String code) =>
      run(() => ref.read(walletRepositoryProvider).applyReferralCode(_uid, code));
}

final walletControllerProvider = NotifierProvider.autoDispose<WalletController, AsyncValue<void>>(
  WalletController.new,
);

/// Actions de l'administrateur : règles, catalogue, contrôle (US-071, 074, 075).
class WalletAdminController extends ActionController {
  /// Garde la session active tant que l'écran utilise le contrôleur.
  @override
  AsyncValue<void> build() {
    ref.watch(currentUidProvider);
    return super.build();
  }

  Redemption? found;

  String get _uid => ref.read(currentUidProvider)!;

  Future<bool> publishRules(PointsRules r) =>
      run(() => ref.read(pointsRulesRepositoryProvider).publish(r, _uid));

  Future<bool> savePartner(Partner p) =>
      run(() => ref.read(rewardsRepositoryProvider).savePartner(p));

  Future<bool> saveReward(Reward r) => run(() => ref.read(rewardsRepositoryProvider).saveReward(r));

  Future<bool> review(LedgerEntry e, {required bool approve}) =>
      run(() => ref.read(walletRepositoryProvider).review(e, approve: approve, adminUid: _uid));

  Future<bool> setFrozen(String uid, {required bool frozen, String? reason}) =>
      run(() => ref.read(walletRepositoryProvider).setFrozen(uid, frozen: frozen, reason: reason));

  Future<bool> findCoupon(String code) => run(() async {
    found = await ref.read(rewardsRepositoryProvider).findByCode(code);
  });

  Future<bool> markUsed(Redemption r) => run(() async {
    await ref.read(rewardsRepositoryProvider).markUsed(r.id);
    found = null;
  });
}

final walletAdminControllerProvider =
    NotifierProvider.autoDispose<WalletAdminController, AsyncValue<void>>(
      WalletAdminController.new,
    );
