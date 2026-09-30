import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/action_controller.dart';
import '../../auth/application/auth_providers.dart';
import '../../missions/domain/deposit.dart';
import '../../vision_admin/application/vision_admin_controllers.dart';
import '../data/recycler_repository.dart';
import '../data/report_export.dart';
import '../domain/analytics.dart';
import '../domain/purchasing.dart';
import '../domain/reception.dart';
import '../domain/stock.dart';

/// Dossier des fichiers exportés (remplaçable en test).
final exportDirectoryProvider = Provider<Future<Directory> Function()>(
  (_) => getTemporaryDirectory,
);

final recyclerRepositoryProvider = Provider<RecyclerRepository>(
  (ref) => RecyclerRepository(ref.watch(firestoreProvider)),
);

final myLotsProvider = StreamProvider<List<StockLot>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(recyclerRepositoryProvider).watchLots(uid);
});

final myMovesProvider = StreamProvider<List<StockMove>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(recyclerRepositoryProvider).watchMoves(uid);
});

final myPurchasingProvider = StreamProvider<Purchasing>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const {});
  return ref.watch(recyclerRepositoryProvider).watchPurchasing(uid);
});

/// Recycleurs et conditions d'achat, pour le dépôt du collecteur (US-085).
final recyclerOffersProvider = FutureProvider<List<RecyclerOffer>>(
  (ref) => ref.watch(recyclerRepositoryProvider).recyclerOffers(),
);

/// Filtres du dashboard (US-082).
class DashboardFilterNotifier extends Notifier<DashboardFilter> {
  @override
  DashboardFilter build() => const DashboardFilter();

  void set(DashboardFilter f) => state = f;
}

final dashboardFilterProvider = NotifierProvider<DashboardFilterNotifier, DashboardFilter>(
  DashboardFilterNotifier.new,
);

final supplyReportProvider = Provider<SupplyReport>((ref) {
  final lots = ref.watch(myLotsProvider).value ?? const [];
  return supplyReport(lots, ref.watch(dashboardFilterProvider), ref.watch(clockProvider)());
});

/// Actions du recycleur (US-080, 081, 083, 085, 087).
class RecyclerController extends ActionController {
  String? lastLotId;

  /// Garde la session active tant que l'écran utilise le contrôleur.
  @override
  AsyncValue<void> build() {
    ref.watch(currentUidProvider);
    return super.build();
  }

  String get _uid => ref.read(currentUidProvider)!;
  RecyclerRepository get _repo => ref.read(recyclerRepositoryProvider);

  Future<bool> receive(Deposit d, ReceptionInput input) => run(() async {
    if (validateReception(input) != null) throw ArgumentError('reception');
    await _repo.receive(_uid, d, input);
  });

  Future<bool> moveOut(StockLot lot, double kg, MoveReason reason, String note) =>
      run(() => _repo.moveOut(_uid, lot, kg, reason, note));

  Future<bool> produce(List<StockLot> lots, ProductionInput p) => run(() async {
    if (validateProduction(p) != null) throw ArgumentError('production');
    lastLotId = await _repo.produce(_uid, lots, p);
  });

  Future<bool> setMarketplace(StockLot lot, bool on) => run(() => _repo.setMarketplace(lot, on));

  Future<bool> savePurchasing(Purchasing p) => run(() => _repo.savePurchasing(_uid, p));

  /// Rapport PDF ou Excel partagé via la feuille de partage (US-083).
  Future<bool> export(SupplyReport r, ReportLabels labels, {required bool pdf}) => run(() async {
    final now = ref.read(clockProvider)();
    final bytes = pdf
        ? await buildSupplyPdf(
            r,
            labels,
            font: await rootBundle.load('assets/fonts/BricolageGrotesque.ttf'),
          )
        : buildSupplyXlsx(r, labels);
    final dir = await ref.read(exportDirectoryProvider)();
    final file = File('${dir.path}/${reportFileName(pdf ? 'pdf' : 'xlsx', now)}');
    await file.writeAsBytes(bytes);
    await ref.read(fileSharerProvider)(file.path);
  });
}

final recyclerControllerProvider =
    NotifierProvider.autoDispose<RecyclerController, AsyncValue<void>>(RecyclerController.new);
