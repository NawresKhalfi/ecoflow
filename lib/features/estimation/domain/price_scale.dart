import '../../profile/domain/company_profile.dart';

/// Barème des prix d'achat par matière, en DT/kg (US-027), `priceScales/{id}`.
/// Un barème n'est jamais modifié : on en publie un nouveau (historique).
class PriceScale {
  const PriceScale({
    required this.id,
    required this.effectiveFrom,
    required this.pricesDtPerKg,
    this.note = '',
    this.createdAt,
  });

  final String id;
  final DateTime effectiveFrom;
  final Map<RecyclableMaterial, double> pricesDtPerKg;
  final String note;
  final DateTime? createdAt;

  double priceOf(RecyclableMaterial? m) => m == null ? 0 : (pricesDtPerKg[m] ?? 0);

  Map<String, dynamic> toMap() => {
    'prices': {for (final e in pricesDtPerKg.entries) e.key.name: e.value},
    'note': note,
  };

  static PriceScale fromMap(
    String id,
    Map<String, dynamic> m, {
    required DateTime effectiveFrom,
    DateTime? createdAt,
  }) => PriceScale(
    id: id,
    effectiveFrom: effectiveFrom,
    pricesDtPerKg: {
      for (final e in (m['prices'] as Map? ?? const {}).entries)
        if (RecyclableMaterial.values.where((v) => v.name == e.key).firstOrNull case final mat?)
          mat: (e.value as num).toDouble(),
    },
    note: m['note'] as String? ?? '',
    createdAt: createdAt,
  );
}

/// Barème initial indicatif, à valider par l'administrateur.
final defaultPriceScale = PriceScale(
  id: 'default',
  effectiveFrom: DateTime(2026),
  pricesDtPerKg: const {
    RecyclableMaterial.pet: 1.2,
    RecyclableMaterial.hdpe: 1.0,
    RecyclableMaterial.pp: .8,
    RecyclableMaterial.cardboard: .3,
    RecyclableMaterial.aluminium: 3.5,
    RecyclableMaterial.glass: .15,
    RecyclableMaterial.other: 0,
  },
  note: 'Barème indicatif par défaut',
);

/// Barème en vigueur à la date [at] : le plus récent dont la date d'effet
/// est passée (à égalité, le dernier publié). Repli : barème par défaut.
PriceScale activeScaleAt(List<PriceScale> scales, DateTime at) {
  PriceScale? best;
  for (final s in scales) {
    if (s.effectiveFrom.isAfter(at)) continue;
    final newer =
        best == null ||
        s.effectiveFrom.isAfter(best.effectiveFrom) ||
        (s.effectiveFrom == best.effectiveFrom &&
            (s.createdAt ?? DateTime(0)).isAfter(best.createdAt ?? DateTime(0)));
    if (newer) best = s;
  }
  return best ?? defaultPriceScale;
}
