import 'dart:math';

/// Catégories à coefficient propre. Le calcul est reproduit à l'identique
/// par les règles Firestore (`pointEntries`) : liste fixe, le reste du
/// poids prend le coefficient de « other ».
const pointsCategoryIds = [
  'pet_bottle',
  'can',
  'cardboard',
  'paper',
  'glass',
  'e_waste',
  'organic',
  'medical',
];
const pointsOtherId = 'other';

const defaultPointsMultipliers = {
  'pet_bottle': 1.5,
  'can': 2.0,
  'cardboard': 1.0,
  'paper': 1.0,
  'glass': 1.2,
  'e_waste': 3.0,
  'organic': .5,
  'medical': 0.0,
  'other': 1.0,
};

/// Règles d'attribution des EcoPoints (US-071), `config/points`, historisées
/// dans `config/points/history`.
class PointsRules {
  const PointsRules({
    this.pointsPerKg = 10,
    this.multipliers = defaultPointsMultipliers,
    this.firstCollectionBonus = 50,
    this.bigDropKg = 10,
    this.bigDropBonus = 20,
    this.referralBonus = 100,
    this.dailyLimit = 3,
    this.maxKgPerCollection = 200,
    this.anomalyRatio = 3,
    this.expiryMonths = 12,
  });

  final double pointsPerKg;

  /// Coefficient par matière (1 par défaut).
  final Map<String, double> multipliers;
  final int firstCollectionBonus;

  /// Bonus « gros dépôt » à partir de [bigDropKg] kg pesés.
  final double bigDropKg;
  final int bigDropBonus;

  /// Points du parrain à la première collecte du filleul (US-077).
  final int referralBonus;

  /// Anti-fraude (US-075) : au-delà, les points sont mis en attente de contrôle.
  final int dailyLimit;
  final double maxKgPerCollection;
  final double anomalyRatio;

  /// Durée de validité des points gagnés (US-078).
  final int expiryMonths;

  double multiplier(String categoryId) => multipliers[categoryId] ?? 1;

  PointsRules copyWith({
    double? pointsPerKg,
    Map<String, double>? multipliers,
    int? firstCollectionBonus,
    double? bigDropKg,
    int? bigDropBonus,
    int? referralBonus,
    int? dailyLimit,
    double? maxKgPerCollection,
    double? anomalyRatio,
    int? expiryMonths,
  }) => PointsRules(
    pointsPerKg: pointsPerKg ?? this.pointsPerKg,
    multipliers: multipliers ?? this.multipliers,
    firstCollectionBonus: firstCollectionBonus ?? this.firstCollectionBonus,
    bigDropKg: bigDropKg ?? this.bigDropKg,
    bigDropBonus: bigDropBonus ?? this.bigDropBonus,
    referralBonus: referralBonus ?? this.referralBonus,
    dailyLimit: dailyLimit ?? this.dailyLimit,
    maxKgPerCollection: maxKgPerCollection ?? this.maxKgPerCollection,
    anomalyRatio: anomalyRatio ?? this.anomalyRatio,
    expiryMonths: expiryMonths ?? this.expiryMonths,
  );

  Map<String, dynamic> toMap() => {
    'pointsPerKg': pointsPerKg,
    'multipliers': multipliers,
    'firstCollectionBonus': firstCollectionBonus,
    'bigDropKg': bigDropKg,
    'bigDropBonus': bigDropBonus,
    'referralBonus': referralBonus,
    'dailyLimit': dailyLimit,
    'maxKgPerCollection': maxKgPerCollection,
    'anomalyRatio': anomalyRatio,
    'expiryMonths': expiryMonths,
  };

  static PointsRules fromMap(Map<String, dynamic>? m) {
    if (m == null) return const PointsRules();
    const x = PointsRules();
    double d(String k, double v) => (m[k] as num?)?.toDouble() ?? v;
    int i(String k, int v) => (m[k] as num?)?.toInt() ?? v;
    return PointsRules(
      pointsPerKg: d('pointsPerKg', x.pointsPerKg),
      multipliers: {
        ...x.multipliers,
        for (final e in (m['multipliers'] as Map? ?? const {}).entries)
          '${e.key}': (e.value as num).toDouble(),
      },
      firstCollectionBonus: i('firstCollectionBonus', x.firstCollectionBonus),
      bigDropKg: d('bigDropKg', x.bigDropKg),
      bigDropBonus: i('bigDropBonus', x.bigDropBonus),
      referralBonus: i('referralBonus', x.referralBonus),
      dailyLimit: i('dailyLimit', x.dailyLimit),
      maxKgPerCollection: d('maxKgPerCollection', x.maxKgPerCollection),
      anomalyRatio: d('anomalyRatio', x.anomalyRatio),
      expiryMonths: i('expiryMonths', x.expiryMonths),
    );
  }
}

/// Motif de mise en attente d'un gain (US-075).
enum FraudFlag { overweight, estimateGap, dailyLimit }

/// Gain calculé pour une collecte pesée.
class PointsAward {
  const PointsAward({
    required this.base,
    required this.firstBonus,
    required this.bigDropBonus,
    required this.flags,
  });

  final int base;
  final int firstBonus;
  final int bigDropBonus;
  final List<FraudFlag> flags;

  int get total => base + firstBonus + bigDropBonus;
  bool get held => flags.isNotEmpty;
}

/// Tolérance d'arrondi : 9 × 1,2 × 10 vaut 107,999… en virgule flottante.
const _epsilon = 1e-6;

/// Calcul d'un gain (US-069) : Σ kg × coefficient × points/kg, arrondi à
/// l'entier inférieur, plus les bonus. Même ordre d'opérations que les
/// règles Firestore.
PointsAward computeAward(
  PointsRules rules, {
  required Map<String, double> actualKg,
  required double actualTotalKg,
  required double estimatedKg,
  required bool firstCollection,
  required int dayCount,
}) {
  var known = 0.0;
  var weighted = 0.0;
  for (final id in pointsCategoryIds) {
    known += actualKg[id] ?? 0;
  }
  for (final id in pointsCategoryIds) {
    weighted += (actualKg[id] ?? 0) * rules.multiplier(id);
  }
  weighted += (actualTotalKg - known) * rules.multiplier(pointsOtherId);
  return PointsAward(
    base: max(0, (weighted * rules.pointsPerKg + _epsilon).floor()),
    firstBonus: firstCollection ? rules.firstCollectionBonus : 0,
    bigDropBonus: actualTotalKg >= rules.bigDropKg ? rules.bigDropBonus : 0,
    flags: [
      if (actualTotalKg > rules.maxKgPerCollection) FraudFlag.overweight,
      if (estimatedKg > 0 && actualTotalKg > estimatedKg * rules.anomalyRatio)
        FraudFlag.estimateGap,
      if (dayCount > rules.dailyLimit) FraudFlag.dailyLimit,
    ],
  );
}

/// Rang du gain dans la journée (UTC, comme `request.time.date()`).
int nextDayCount(DateTime? lastEarnAt, int dayCount, DateTime now) {
  if (lastEarnAt == null) return 1;
  final a = lastEarnAt.toUtc();
  final b = now.toUtc();
  final sameDay = a.year == b.year && a.month == b.month && a.day == b.day;
  return sameDay ? dayCount + 1 : 1;
}
