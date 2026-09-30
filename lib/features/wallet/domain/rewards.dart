import 'dart:math';

/// Partenaire du catalogue de récompenses : `partners/{id}` (US-074).
class Partner {
  const Partner({
    required this.id,
    required this.name,
    this.city = '',
    this.emoji = '🏪',
    this.active = true,
  });

  final String id;
  final String name;
  final String city;
  final String emoji;
  final bool active;

  Map<String, dynamic> toMap() => {'name': name, 'city': city, 'emoji': emoji, 'active': active};

  static Partner fromMap(String id, Map<String, dynamic> m) => Partner(
    id: id,
    name: m['name'] as String? ?? '',
    city: m['city'] as String? ?? '',
    emoji: m['emoji'] as String? ?? '🏪',
    active: m['active'] as bool? ?? true,
  );
}

enum RewardKind { discount, product, donation }

/// Offre échangeable contre des points : `rewards/{id}` (US-072, US-074).
class Reward {
  const Reward({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.title,
    required this.cost,
    this.description = '',
    this.kind = RewardKind.discount,
    this.emoji = '🎁',
    this.stock,
    this.active = true,
  });

  final String id;
  final String partnerId;
  final String partnerName;
  final String title;
  final String description;
  final RewardKind kind;
  final String emoji;

  /// Coût en EcoPoints.
  final int cost;

  /// `null` : illimité.
  final int? stock;
  final bool active;

  bool get available => active && (stock == null || stock! > 0);

  Map<String, dynamic> toMap() => {
    'partnerId': partnerId,
    'partnerName': partnerName,
    'title': title,
    'description': description,
    'kind': kind.name,
    'emoji': emoji,
    'cost': cost,
    'stock': stock,
    'active': active,
  };

  static Reward fromMap(String id, Map<String, dynamic> m) => Reward(
    id: id,
    partnerId: m['partnerId'] as String? ?? '',
    partnerName: m['partnerName'] as String? ?? '',
    title: m['title'] as String? ?? '',
    description: m['description'] as String? ?? '',
    kind: RewardKind.values.where((k) => k.name == m['kind']).firstOrNull ?? RewardKind.discount,
    emoji: m['emoji'] as String? ?? '🎁',
    cost: (m['cost'] as num?)?.toInt() ?? 0,
    stock: (m['stock'] as num?)?.toInt(),
    active: m['active'] as bool? ?? true,
  );
}

enum RedemptionStatus { active, used, cancelled }

/// Coupon obtenu contre des points : `redemptions/{id}` (US-073).
class Redemption {
  const Redemption({
    required this.id,
    required this.uid,
    required this.rewardId,
    required this.rewardTitle,
    required this.partnerName,
    required this.cost,
    required this.code,
    this.status = RedemptionStatus.active,
    this.createdAt,
    this.usedAt,
  });

  final String id;
  final String uid;
  final String rewardId;
  final String rewardTitle;
  final String partnerName;
  final int cost;
  final String code;
  final RedemptionStatus status;
  final DateTime? createdAt;
  final DateTime? usedAt;

  /// Contenu du QR présenté chez le partenaire.
  String get qrPayload => 'ECOFLOW-COUPON:$id:$code';

  static Redemption fromMap(
    String id,
    Map<String, dynamic> m, {
    DateTime? createdAt,
    DateTime? usedAt,
  }) => Redemption(
    id: id,
    uid: m['uid'] as String? ?? '',
    rewardId: m['rewardId'] as String? ?? '',
    rewardTitle: m['rewardTitle'] as String? ?? '',
    partnerName: m['partnerName'] as String? ?? '',
    cost: (m['cost'] as num?)?.toInt() ?? 0,
    code: m['code'] as String? ?? '',
    status:
        RedemptionStatus.values.where((s) => s.name == m['status']).firstOrNull ??
        RedemptionStatus.active,
    createdAt: createdAt,
    usedAt: usedAt,
  );
}

/// Alphabet sans caractères ambigus (0/O, 1/I/L).
const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Code lisible (coupon, parrainage), en groupes de 4 si [length] = 8.
String randomCode({int length = 8, Random? random}) {
  final r = random ?? Random.secure();
  final raw = List.generate(length, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
  return length == 8 ? '${raw.substring(0, 4)}-${raw.substring(4)}' : raw;
}

/// Normalise une saisie de code (casse, espaces, tiret).
String normalizeCode(String input) => input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

enum RedeemRefusal { frozen, insufficient, unavailable }

/// Pourquoi un échange est impossible, ou `null` s'il est permis.
RedeemRefusal? redeemRefusal(Reward r, int balance, {required bool frozen}) {
  if (frozen) return RedeemRefusal.frozen;
  if (!r.available) return RedeemRefusal.unavailable;
  if (balance < r.cost) return RedeemRefusal.insufficient;
  return null;
}
