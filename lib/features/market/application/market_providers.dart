import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/action_controller.dart';
import '../../auth/application/auth_providers.dart';
import '../../recycler/application/recycler_providers.dart';
import '../../recycler/domain/stock.dart';
import '../../tracking/application/tracking_providers.dart';
import '../../tracking/domain/app_notification.dart';
import '../../vision_admin/application/vision_admin_controllers.dart';
import '../data/market_documents.dart';
import '../data/market_repository.dart';
import '../domain/market.dart';

final marketRepositoryProvider = Provider<MarketRepository>(
  (ref) => MarketRepository(ref.watch(firestoreProvider)),
);

final openListingsProvider = StreamProvider<List<Listing>>(
  (ref) => ref.watch(marketRepositoryProvider).watchOpen(),
);

final myListingsProvider = StreamProvider<List<Listing>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(marketRepositoryProvider).watchMine(uid);
});

final listingProvider = StreamProvider.family<Listing?, String>(
  (ref, id) => ref.watch(marketRepositoryProvider).watchListing(id),
);

final myDealsProvider = StreamProvider<List<Deal>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(marketRepositoryProvider).watchDeals(uid);
});

final dealProvider = StreamProvider.family<Deal?, String>(
  (ref, id) => ref.watch(marketRepositoryProvider).watchDeal(id),
);

final dealMessagesProvider = StreamProvider.family<List<MarketMessage>, String>(
  (ref, id) => ref.watch(marketRepositoryProvider).watchMessages(id),
);

final myOrdersProvider = StreamProvider<List<MarketOrder>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(marketRepositoryProvider).watchOrders(uid);
});

final orderProvider = StreamProvider.family<MarketOrder?, String>(
  (ref, id) => ref.watch(marketRepositoryProvider).watchOrder(id),
);

final companyRatingProvider = StreamProvider.family<CompanyRating?, String>(
  (ref, uid) => ref.watch(marketRepositoryProvider).watchRating(uid),
);

final reportsProvider = StreamProvider<List<ListingReport>>(
  (ref) => ref.watch(marketRepositoryProvider).watchReports(),
);

final allListingsProvider = StreamProvider<List<Listing>>(
  (ref) => ref.watch(marketRepositoryProvider).watchAll(),
);

class ListingFilterNotifier extends Notifier<ListingFilter> {
  @override
  ListingFilter build() => const ListingFilter();

  void set(ListingFilter f) => state = f;
}

final listingFilterProvider = NotifierProvider<ListingFilterNotifier, ListingFilter>(
  ListingFilterNotifier.new,
);

/// Suggestions (US-102) : demandes d'achat que mon stock peut servir,
/// offres de vente des matières que je recherche ou que j'achète.
final suggestionsProvider = Provider<List<Suggestion>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const [];
  final mine = ref.watch(myListingsProvider).value ?? const <Listing>[];
  final purchasing = ref.watch(myPurchasingProvider).value ?? const {};
  return suggest(
    ref.watch(openListingsProvider).value ?? const [],
    uid,
    stockKg: stockByMaterial(ref.watch(myLotsProvider).value ?? const []),
    wanted: {
      for (final l in mine)
        if (l.type == ListingType.buy && l.status == ListingStatus.open) l.material,
      for (final e in purchasing.entries)
        if (e.value.accepting) e.key,
    },
    now: ref.watch(clockProvider)(),
  );
});

/// Actions de la marketplace (US-094 à US-105).
class MarketController extends ActionController {
  String? lastId;

  @override
  AsyncValue<void> build() {
    ref.watch(currentUidProvider);
    return super.build();
  }

  String get _uid => ref.read(currentUidProvider)!;
  MarketRepository get _repo => ref.read(marketRepositoryProvider);

  Future<void> _notify(String to, NotificationType type, String id, String preview) async {
    if (to == _uid) return;
    try {
      await ref
          .read(notificationRepositoryProvider)
          .send(toUid: to, fromUid: _uid, type: type, collectionId: id, preview: preview);
    } catch (_) {
      // Best-effort : l'information reste visible dans la marketplace.
    }
  }

  Future<bool> saveListing(Listing l) => run(() async {
    if (validateListing(l, ref.read(clockProvider)()) != null) throw ArgumentError('listing');
    lastId = await _repo.saveListing(l);
  });

  Future<bool> setListingStatus(String id, ListingStatus s) =>
      run(() => _repo.setListingStatus(id, s));

  Future<bool> openDeal(Listing l, String myName, String title) => run(() async {
    lastId = await _repo.openDeal(l, _uid, myName, title);
  });

  Future<bool> sendText(Deal d, String text) => run(() async {
    final t = text.trim();
    if (t.isEmpty || t.length > maxMarketMessage) throw ArgumentError('text');
    await _repo.send(d.id, _uid, text: t);
    await _notify(d.otherUid(_uid), NotificationType.marketMessage, d.id, t);
  });

  Future<bool> propose(
    Deal d, {
    required double price,
    required double quantity,
    required int days,
    String note = '',
  }) => run(() async {
    if (price <= 0 || quantity <= 0 || days < 0) throw ArgumentError('proposal');
    await _repo.send(d.id, _uid, text: note, price: price, quantity: quantity, days: days);
    await _notify(
      d.otherUid(_uid),
      NotificationType.marketProposal,
      d.id,
      '$price DT/kg × $quantity kg',
    );
  });

  Future<bool> answer(Deal d, Listing l, MarketMessage p, {required bool accept}) => run(() async {
    lastId = await _repo.answer(d, l, p, accept: accept, now: ref.read(clockProvider)());
    await _notify(
      p.fromUid,
      accept ? NotificationType.orderUpdate : NotificationType.marketProposal,
      lastId ?? d.id,
      accept ? 'confirmed' : 'declined',
    );
  });

  Future<bool> withdraw(Deal d, MarketMessage p) => run(() => _repo.withdraw(d.id, p.id));

  /// Étape suivante de la commande. À l'expédition, les lots liés sortent
  /// du stock (vente) et l'origine est figée pour le certificat.
  Future<bool> advance(MarketOrder o) => run(() async {
    final next = nextStep(o, _uid);
    if (next == null) throw StateError('step');
    Map<String, Object>? origin;
    if (next == OrderStatus.shipped && o.lotIds.isNotEmpty) {
      final lots = [
        for (final l in await ref.read(recyclerRepositoryProvider).watchLots(_uid).first)
          if (o.lotIds.contains(l.id)) l,
      ];
      final avail = lots.fold(0.0, (s, l) => s + l.kg);
      final take = o.quantityKg < avail ? o.quantityKg : avail;
      if (take > 0) {
        for (final (lot, kg) in consumeFifo(lots, o.material, take)) {
          await ref
              .read(recyclerRepositoryProvider)
              .moveOut(_uid, lot, kg, MoveReason.sale, o.number);
        }
      }
      origin = {
        'zones': {for (final l in lots) ...l.zoneIds}.toList(),
        'pickups': {for (final l in lots) ...l.missions.map((m) => m.id)}.length,
      };
    }
    await _repo.setStatus(o, next, origin: origin);
    await _notify(
      o.isSeller(_uid) ? o.buyerUid : o.sellerUid,
      NotificationType.orderUpdate,
      o.id,
      next.name,
    );
  });

  Future<bool> cancel(MarketOrder o) => run(() async {
    if (!canCancel(o)) throw StateError('cancel');
    await _repo.setStatus(o, OrderStatus.cancelled);
    await _notify(
      o.isSeller(_uid) ? o.buyerUid : o.sellerUid,
      NotificationType.orderUpdate,
      o.id,
      'cancelled',
    );
  });

  /// Paiement hors plateforme (virement) : l'acheteur le déclare, le
  /// vendeur confirme la réception (US-104).
  Future<bool> payment(MarketOrder o) => run(() async {
    final next = o.isSeller(_uid) ? PaymentStatus.received : PaymentStatus.declared;
    await _repo.setPayment(o, next);
    await _notify(
      o.isSeller(_uid) ? o.buyerUid : o.sellerUid,
      NotificationType.orderUpdate,
      o.id,
      next.name,
    );
  });

  Future<bool> rate(MarketOrder o, int stars) => run(() => _repo.rate(o, _uid, stars));

  Future<bool> report(Listing l, ReportReason reason, String text) =>
      run(() => _repo.report(l.id, _uid, reason, text));

  Future<bool> resolveReport(String id) => run(() => _repo.resolveReport(id));

  Future<void> _share(Uint8List bytes, String name) async {
    final dir = await ref.read(exportDirectoryProvider)();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    await ref.read(fileSharerProvider)(file.path);
  }

  Future<ByteData> _font() => rootBundle.load('assets/fonts/BricolageGrotesque.ttf');

  Future<bool> exportInvoice(
    MarketOrder o,
    Map<String, String> t, {
    required String material,
    required String date,
  }) => run(() async {
    await _share(
      await buildInvoicePdf(o, t, material: material, date: date, font: await _font()),
      'facture_${o.number}.pdf',
    );
  });

  /// Certificat d'une commande (acheteur) ou de lots du stock (vendeur).
  Future<bool> exportCertificate(
    List<StockLot> lots,
    Map<String, String> t, {
    required String company,
    required String number,
    required String date,
    required String Function(StockLot) materialOf,
    String? beneficiary,
    int? pickups,
    String Function(StockLot)? referenceOf,
    String Function(double)? fmt,
  }) => run(() async {
    await _share(
      await buildCertificatePdf(
        lots,
        t,
        company: company,
        number: number,
        date: date,
        materialOf: materialOf,
        beneficiary: beneficiary,
        pickups: pickups,
        referenceOf: referenceOf,
        fmt: fmt,
        font: await _font(),
      ),
      'certificat_$number.pdf',
    );
  });
}

final marketControllerProvider = NotifierProvider.autoDispose<MarketController, AsyncValue<void>>(
  MarketController.new,
);

/// Lot virtuel représentant la matière d'une commande (certificat acheteur).
StockLot orderAsLot(MarketOrder o) => StockLot(
  id: o.number,
  recyclerUid: o.sellerUid,
  material: o.material,
  grade: o.grade ?? QualityGrade.b,
  form: o.form,
  initialKg: o.quantityKg,
  kg: o.quantityKg,
  zoneIds: o.originZones,
);
