import '../../profile/domain/company_profile.dart';
import '../../recycler/domain/stock.dart';

enum ListingType { buy, sell }

enum ListingStatus { open, closed, suspended, removed }

/// Annonce de la marketplace : `listings/{id}` (US-094, US-095).
class Listing {
  const Listing({
    required this.id,
    required this.type,
    required this.ownerUid,
    required this.ownerName,
    required this.material,
    required this.quantityKg,
    required this.city,
    required this.deadline,
    this.form = MaterialForm.raw,
    this.grade,
    this.priceDtPerKg,
    this.description = '',
    this.status = ListingStatus.open,
    this.lotIds = const [],
    this.createdAt,
  });

  final String id;
  final ListingType type;
  final String ownerUid;
  final String ownerName;
  final RecyclableMaterial material;
  final MaterialForm form;
  final QualityGrade? grade;
  final double quantityKg;

  /// Vente : prix demandé ; achat : prix maximal (facultatif).
  final double? priceDtPerKg;
  final String city;

  /// Achat : « besoin avant le » ; vente : disponible jusqu'au.
  final DateTime deadline;
  final String description;
  final ListingStatus status;

  /// Vente publiée depuis le stock : lots d'origine (traçabilité, sortie
  /// de stock à l'expédition).
  final List<String> lotIds;
  final DateTime? createdAt;

  bool isActive(DateTime now) => status == ListingStatus.open && !deadline.isBefore(now);

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'ownerUid': ownerUid,
    'ownerName': ownerName,
    'material': material.name,
    'form': form.name,
    'grade': grade?.name,
    'quantityKg': quantityKg,
    'priceDtPerKg': priceDtPerKg,
    'city': city,
    'deadline': deadline,
    'description': description,
    'status': status.name,
    'lotIds': lotIds,
  };

  static Listing fromMap(String id, Map<String, dynamic> m, DateTime? Function(Object?) date) =>
      Listing(
        id: id,
        type: m['type'] == 'buy' ? ListingType.buy : ListingType.sell,
        ownerUid: m['ownerUid'] as String? ?? '',
        ownerName: m['ownerName'] as String? ?? '',
        material: materialFromName(m['material'] as String?),
        form: MaterialForm.values.where((f) => f.name == m['form']).firstOrNull ?? MaterialForm.raw,
        grade: QualityGrade.values.where((g) => g.name == m['grade']).firstOrNull,
        quantityKg: (m['quantityKg'] as num?)?.toDouble() ?? 0,
        priceDtPerKg: (m['priceDtPerKg'] as num?)?.toDouble(),
        city: m['city'] as String? ?? '',
        deadline: date(m['deadline']) ?? DateTime(2000),
        description: m['description'] as String? ?? '',
        status:
            ListingStatus.values.where((s) => s.name == m['status']).firstOrNull ??
            ListingStatus.open,
        lotIds: (m['lotIds'] as List? ?? const []).cast<String>(),
        createdAt: date(m['createdAt']),
      );
}

enum ListingIssue { quantity, price, deadline, city }

ListingIssue? validateListing(Listing l, DateTime now) {
  if (l.quantityKg <= 0) return ListingIssue.quantity;
  if (l.priceDtPerKg != null && l.priceDtPerKg! <= 0) return ListingIssue.price;
  if (l.type == ListingType.sell && l.priceDtPerKg == null) return ListingIssue.price;
  if (!l.deadline.isAfter(now)) return ListingIssue.deadline;
  if (l.city.trim().isEmpty) return ListingIssue.city;
  return null;
}

/// Recherche et filtres (US-096).
class ListingFilter {
  const ListingFilter({
    this.type,
    this.material,
    this.city = '',
    this.minKg,
    this.before,
    this.query = '',
  });

  final ListingType? type;
  final RecyclableMaterial? material;
  final String city;
  final double? minKg;

  /// Échéance au plus tard le…
  final DateTime? before;
  final String query;

  ListingFilter copyWith({
    ListingType? Function()? type,
    RecyclableMaterial? Function()? material,
    String? city,
    double? Function()? minKg,
    DateTime? Function()? before,
    String? query,
  }) => ListingFilter(
    type: type == null ? this.type : type(),
    material: material == null ? this.material : material(),
    city: city ?? this.city,
    minKg: minKg == null ? this.minKg : minKg(),
    before: before == null ? this.before : before(),
    query: query ?? this.query,
  );

  bool matches(Listing l, DateTime now) {
    if (!l.isActive(now)) return false;
    if (type != null && l.type != type) return false;
    if (material != null && l.material != material) return false;
    if (city.trim().isNotEmpty && !_norm(l.city).contains(_norm(city))) return false;
    if (minKg != null && l.quantityKg < minKg!) return false;
    if (before != null && l.deadline.isAfter(before!)) return false;
    if (query.trim().isNotEmpty &&
        !_norm('${l.description} ${l.ownerName} ${l.city}').contains(_norm(query))) {
      return false;
    }
    return true;
  }
}

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c')
    .trim();

/// Suggestion (US-102) : annonce et raison.
typedef Suggestion = ({Listing listing, double score, double matchKg});

/// Annonces d'autres entreprises qui correspondent à mon stock (je peux
/// vendre) ou à mes besoins (mes annonces d'achat, matières que j'achète).
List<Suggestion> suggest(
  List<Listing> all,
  String me, {
  required Map<RecyclableMaterial, double> stockKg,
  required Set<RecyclableMaterial> wanted,
  required DateTime now,
}) {
  final out = <Suggestion>[];
  for (final l in all.where((l) => l.ownerUid != me && l.isActive(now))) {
    final double match;
    if (l.type == ListingType.buy) {
      final have = stockKg[l.material] ?? 0;
      if (have <= 0) continue;
      match = have < l.quantityKg ? have : l.quantityKg;
    } else {
      if (!wanted.contains(l.material)) continue;
      match = l.quantityKg;
    }
    // Couverture de la quantité, bonus d'urgence (échéance sous 7 jours).
    final cover = match / l.quantityKg;
    final urgent = l.deadline.difference(now).inDays <= 7 ? .2 : 0;
    out.add((listing: l, score: cover + urgent, matchKg: match));
  }
  out.sort((a, b) => b.score.compareTo(a.score));
  return out;
}

/// Fil de négociation entre l'auteur d'une annonce et une entreprise :
/// `deals/{listingId_uid}` (US-097, US-098).
class Deal {
  const Deal({
    required this.id,
    required this.listingId,
    required this.ownerUid,
    required this.counterpartUid,
    required this.ownerName,
    required this.counterpartName,
    required this.listingTitle,
    this.lastMessage = '',
    this.updatedAt,
  });

  final String id;
  final String listingId;
  final String ownerUid;
  final String counterpartUid;
  final String ownerName;
  final String counterpartName;
  final String listingTitle;
  final String lastMessage;
  final DateTime? updatedAt;

  static String idFor(String listingId, String counterpartUid) => '${listingId}_$counterpartUid';

  String otherName(String me) => me == ownerUid ? counterpartName : ownerName;
  String otherUid(String me) => me == ownerUid ? counterpartUid : ownerUid;
}

enum MessageKind { text, proposal }

enum ProposalStatus { pending, accepted, declined, withdrawn }

/// Message ou proposition chiffrée dans un fil : `deals/{id}/messages/{m}`.
class MarketMessage {
  const MarketMessage({
    required this.id,
    required this.fromUid,
    required this.kind,
    this.text = '',
    this.priceDtPerKg,
    this.quantityKg,
    this.deliveryDays,
    this.status = ProposalStatus.pending,
    this.at,
  });

  final String id;
  final String fromUid;
  final MessageKind kind;
  final String text;
  final double? priceDtPerKg;
  final double? quantityKg;
  final int? deliveryDays;
  final ProposalStatus status;
  final DateTime? at;

  double get totalDt => (priceDtPerKg ?? 0) * (quantityKg ?? 0);

  /// Seul le destinataire d'une proposition en attente peut l'accepter.
  bool canAnswer(String me) =>
      kind == MessageKind.proposal && status == ProposalStatus.pending && fromUid != me;
}

const maxMarketMessage = 1000;

enum OrderStatus { confirmed, preparing, shipped, delivered, completed, cancelled }

enum PaymentStatus { pending, declared, received }

/// Commande issue d'une proposition acceptée : `orders/{id}` (US-099, US-100).
class MarketOrder {
  const MarketOrder({
    required this.id,
    required this.listingId,
    required this.dealId,
    required this.sellerUid,
    required this.buyerUid,
    required this.sellerName,
    required this.buyerName,
    required this.material,
    required this.form,
    required this.quantityKg,
    required this.priceDtPerKg,
    required this.deliveryDays,
    required this.number,
    this.grade,
    this.status = OrderStatus.confirmed,
    this.payment = PaymentStatus.pending,
    this.lotIds = const [],
    this.sellerRating,
    this.buyerRating,
    this.createdAt,
    this.history = const {},
    this.originZones = const [],
    this.originPickups = 0,
  });

  final String id;
  final String listingId;
  final String dealId;
  final String sellerUid;
  final String buyerUid;
  final String sellerName;
  final String buyerName;
  final RecyclableMaterial material;
  final MaterialForm form;
  final QualityGrade? grade;
  final double quantityKg;
  final double priceDtPerKg;
  final int deliveryDays;

  /// Numéro lisible, aussi numéro de facture (`CMD-2026-…`).
  final String number;
  final OrderStatus status;
  final PaymentStatus payment;
  final List<String> lotIds;

  /// Note donnée au vendeur par l'acheteur, et inversement (US-101).
  final int? sellerRating;
  final int? buyerRating;
  final DateTime? createdAt;
  final Map<OrderStatus, DateTime> history;

  /// Origine de la matière, écrite par le vendeur à l'expédition (US-105).
  final List<String> originZones;
  final int originPickups;

  double get totalHt => quantityKg * priceDtPerKg;
  double get vat => totalHt * vatRate;
  double get totalTtc => totalHt + vat;

  bool isSeller(String uid) => uid == sellerUid;
  String counterpartName(String me) => me == sellerUid ? buyerName : sellerName;
}

/// TVA tunisienne appliquée sur la facture (taux normal).
const vatRate = .19;

/// Étape suivante que peut déclencher [me] (`null` si aucune).
OrderStatus? nextStep(MarketOrder o, String me) => switch (o.status) {
  OrderStatus.confirmed when o.isSeller(me) => OrderStatus.preparing,
  OrderStatus.preparing when o.isSeller(me) => OrderStatus.shipped,
  OrderStatus.shipped when o.isSeller(me) => OrderStatus.delivered,
  OrderStatus.delivered when !o.isSeller(me) => OrderStatus.completed,
  _ => null,
};

bool canCancel(MarketOrder o) =>
    o.status == OrderStatus.confirmed || o.status == OrderStatus.preparing;

/// Numéro de commande : année + 6 caractères de l'identifiant.
String orderNumber(String id, DateTime now) =>
    'CMD-${now.year}-${(id.length > 6 ? id.substring(0, 6) : id).toUpperCase()}';

/// Émissions évitées par kg recyclé (kg CO₂e), ordres de grandeur publiés
/// (ADEME / EPA WARM) ; indicatif pour le certificat (US-105).
double co2AvoidedPerKg(RecyclableMaterial m) => switch (m) {
  RecyclableMaterial.pet => 1.5,
  RecyclableMaterial.hdpe => 1.4,
  RecyclableMaterial.pp => 1.2,
  RecyclableMaterial.cardboard => .9,
  RecyclableMaterial.aluminium => 9,
  RecyclableMaterial.glass => .3,
  RecyclableMaterial.other => .5,
};

enum ReportReason { misleading, prohibited, duplicate, spam, other }
