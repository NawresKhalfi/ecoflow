import '../../profile/domain/company_profile.dart';

/// Conditions d'achat d'une matière (US-085).
class MaterialOffer {
  const MaterialOffer({this.accepting = true, this.priceDtPerKg = 0, this.capacityKgMonth = 0});

  final bool accepting;
  final double priceDtPerKg;

  /// 0 = sans limite annoncée.
  final double capacityKgMonth;

  Map<String, dynamic> toMap() => {
    'accepting': accepting,
    'priceDtPerKg': priceDtPerKg,
    'capacityKgMonth': capacityKgMonth,
  };

  static MaterialOffer fromMap(Map? m) => MaterialOffer(
    accepting: m?['accepting'] as bool? ?? true,
    priceDtPerKg: (m?['priceDtPerKg'] as num?)?.toDouble() ?? 0,
    capacityKgMonth: (m?['capacityKgMonth'] as num?)?.toDouble() ?? 0,
  );

  MaterialOffer copyWith({bool? accepting, double? priceDtPerKg, double? capacityKgMonth}) =>
      MaterialOffer(
        accepting: accepting ?? this.accepting,
        priceDtPerKg: priceDtPerKg ?? this.priceDtPerKg,
        capacityKgMonth: capacityKgMonth ?? this.capacityKgMonth,
      );
}

/// Champ `purchasing` de `companies/{uid}` : matière → conditions.
typedef Purchasing = Map<RecyclableMaterial, MaterialOffer>;

Purchasing purchasingFromMap(Map? m) => {
  for (final e in (m ?? const {}).entries)
    for (final v in RecyclableMaterial.values.where((v) => v.name == e.key))
      v: MaterialOffer.fromMap(e.value as Map?),
};

Map<String, dynamic> purchasingToMap(Purchasing p) => {
  for (final e in p.entries) e.key.name: e.value.toMap(),
};

/// Recycleur vu par le collecteur au moment du dépôt.
typedef RecyclerOffer = ({String uid, String name, String city, Purchasing purchasing});

/// Valeur d'achat annoncée pour un dépôt, `null` si une matière du dépôt
/// n'est pas acceptée.
double? offerValue(Purchasing p, Map<RecyclableMaterial, double> kgByMaterial) {
  var total = 0.0;
  for (final e in kgByMaterial.entries) {
    if (e.value <= 0) continue;
    final o = p[e.key];
    if (o != null && !o.accepting) return null;
    total += e.value * (o?.priceDtPerKg ?? 0);
  }
  return total;
}

/// Oriente les livraisons (US-085) : recycleurs qui acceptent toutes les
/// matières du dépôt, meilleure offre d'abord ; les autres à la fin.
List<(RecyclerOffer, double?)> rankRecyclers(
  List<RecyclerOffer> recyclers,
  Map<RecyclableMaterial, double> kgByMaterial,
) {
  final scored = [for (final r in recyclers) (r, offerValue(r.purchasing, kgByMaterial))];
  scored.sort((a, b) {
    if (a.$2 == null || b.$2 == null) return a.$2 == null ? (b.$2 == null ? 0 : 1) : -1;
    return b.$2!.compareTo(a.$2!);
  });
  return scored;
}
