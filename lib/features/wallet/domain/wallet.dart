import 'points_rules.dart';

/// Recycle Wallet : `wallets/{uid}` (US-070). Les compteurs ne bougent
/// qu'avec une écriture `pointEntries/{id}` du même batch, vérifiée par
/// les règles Firestore.
class Wallet {
  const Wallet({
    this.earned = 0,
    this.spent = 0,
    this.expired = 0,
    this.held = 0,
    this.collections = 0,
    this.kg = 0,
    this.dayCount = 0,
    this.lastEarnAt,
    this.lastEntryId,
    this.lastRedemptionId,
    this.referredBy,
    this.referralCode,
    this.frozen = false,
    this.frozenReason,
  });

  final int earned;
  final int spent;
  final int expired;

  /// Points en attente de contrôle anti-fraude.
  final int held;
  final int collections;
  final double kg;
  final int dayCount;
  final DateTime? lastEarnAt;
  final String? lastEntryId;
  final String? lastRedemptionId;
  final String? referredBy;
  final String? referralCode;

  /// Gel par l'administration (suspicion de fraude) : échanges bloqués.
  final bool frozen;
  final String? frozenReason;

  int get balance => earned - spent - expired;

  /// Champs écrits tels quels par le client ; les règles vérifient chaque
  /// variation.
  Map<String, dynamic> toMap() => {
    'earned': earned,
    'spent': spent,
    'expired': expired,
    'held': held,
    'collections': collections,
    'kg': kg,
    'dayCount': dayCount,
    'lastEntryId': lastEntryId,
    'lastRedemptionId': lastRedemptionId,
    'referredBy': referredBy,
    'referralCode': referralCode,
    'frozen': frozen,
    'frozenReason': frozenReason,
  };

  static Wallet fromMap(Map<String, dynamic>? m, {DateTime? lastEarnAt}) {
    if (m == null) return const Wallet();
    int i(String k) => (m[k] as num?)?.toInt() ?? 0;
    return Wallet(
      earned: i('earned'),
      spent: i('spent'),
      expired: i('expired'),
      held: i('held'),
      collections: i('collections'),
      kg: (m['kg'] as num?)?.toDouble() ?? 0,
      dayCount: i('dayCount'),
      lastEarnAt: lastEarnAt,
      lastEntryId: m['lastEntryId'] as String?,
      lastRedemptionId: m['lastRedemptionId'] as String?,
      referredBy: m['referredBy'] as String?,
      referralCode: m['referralCode'] as String?,
      frozen: m['frozen'] as bool? ?? false,
      frozenReason: m['frozenReason'] as String?,
    );
  }

  Wallet copyWith({
    int? earned,
    int? spent,
    int? expired,
    int? held,
    int? collections,
    double? kg,
    int? dayCount,
    String? lastEntryId,
    String? lastRedemptionId,
    String? referredBy,
    String? referralCode,
  }) => Wallet(
    earned: earned ?? this.earned,
    spent: spent ?? this.spent,
    expired: expired ?? this.expired,
    held: held ?? this.held,
    collections: collections ?? this.collections,
    kg: kg ?? this.kg,
    dayCount: dayCount ?? this.dayCount,
    lastEarnAt: lastEarnAt,
    lastEntryId: lastEntryId ?? this.lastEntryId,
    lastRedemptionId: lastRedemptionId ?? this.lastRedemptionId,
    referredBy: referredBy ?? this.referredBy,
    referralCode: referralCode ?? this.referralCode,
    frozen: frozen,
    frozenReason: frozenReason,
  );
}

enum EntryType { earn, redeem, referral, expire, adjust }

enum EntryStatus { credited, held, rejected }

/// Mouvement de points : `pointEntries/{id}`.
/// Identifiants : `c_{collecte}`, `r_{échange}`, `ref_{filleul}`, `x_…`.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.uid,
    required this.type,
    required this.points,
    this.status = EntryStatus.credited,
    this.collectionId,
    this.redemptionId,
    this.kg = 0,
    this.byCategory = const {},
    this.flags = const [],
    this.label,
    this.at,
  });

  final String id;
  final String uid;
  final EntryType type;

  /// Signé : positif pour un gain, négatif pour une dépense ou une expiration.
  final int points;
  final EntryStatus status;
  final String? collectionId;
  final String? redemptionId;
  final double kg;
  final Map<String, double> byCategory;
  final List<FraudFlag> flags;
  final String? label;
  final DateTime? at;

  bool get isCredit => points > 0 && status == EntryStatus.credited;

  static String earnId(String collectionId) => 'c_$collectionId';
  static String redeemId(String redemptionId) => 'r_$redemptionId';
  static String referralId(String refereeUid) => 'ref_$refereeUid';

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'type': type.name,
    'points': points,
    'status': status.name,
    'collectionId': collectionId,
    'redemptionId': redemptionId,
    'kg': kg,
    'byCategory': byCategory,
    'flags': [for (final f in flags) f.name],
    'label': label,
  };

  static LedgerEntry fromMap(String id, Map<String, dynamic> m, {DateTime? at}) => LedgerEntry(
    id: id,
    uid: m['uid'] as String? ?? '',
    type: EntryType.values.where((t) => t.name == m['type']).firstOrNull ?? EntryType.adjust,
    points: (m['points'] as num?)?.toInt() ?? 0,
    status:
        EntryStatus.values.where((s) => s.name == m['status']).firstOrNull ?? EntryStatus.credited,
    collectionId: m['collectionId'] as String?,
    redemptionId: m['redemptionId'] as String?,
    kg: (m['kg'] as num?)?.toDouble() ?? 0,
    byCategory: {
      for (final e in (m['byCategory'] as Map? ?? const {}).entries)
        '${e.key}': (e.value as num).toDouble(),
    },
    flags: [
      for (final f in (m['flags'] as List? ?? const []))
        ...FraudFlag.values.where((x) => x.name == f),
    ],
    label: m['label'] as String?,
    at: at,
  );
}

DateTime addMonths(DateTime d, int months) =>
    DateTime(d.year, d.month + months, d.day, d.hour, d.minute);

/// Points arrivés à échéance et pas encore déduits (US-078) : les gains
/// plus anciens que [expiryMonths] sont consommés en premier (FIFO) par les
/// dépenses et expirations déjà enregistrées.
int duePointsToExpire(List<LedgerEntry> entries, Wallet w, int expiryMonths, DateTime now) {
  final old = entries
      .where((e) => e.isCredit && e.at != null && !addMonths(e.at!, expiryMonths).isAfter(now))
      .fold(0, (s, e) => s + e.points);
  final due = old - w.spent - w.expired;
  return due.clamp(0, w.balance);
}

/// Points qui expireront dans les [withinDays] prochains jours.
int pointsExpiringSoon(
  List<LedgerEntry> entries,
  Wallet w,
  int expiryMonths,
  DateTime now, {
  int withinDays = 30,
}) {
  final horizon = now.add(Duration(days: withinDays));
  return duePointsToExpire(entries, w, expiryMonths, horizon) -
      duePointsToExpire(entries, w, expiryMonths, now);
}

/// Prochaine échéance d'expiration, s'il reste des points concernés.
DateTime? nextExpiry(List<LedgerEntry> entries, Wallet w, int expiryMonths) {
  final credits = entries.where((e) => e.isCredit && e.at != null).toList()
    ..sort((a, b) => a.at!.compareTo(b.at!));
  var consumed = w.spent + w.expired;
  for (final e in credits) {
    if (consumed >= e.points) {
      consumed -= e.points;
      continue;
    }
    return addMonths(e.at!, expiryMonths);
  }
  return null;
}
