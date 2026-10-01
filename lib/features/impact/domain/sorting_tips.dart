/// Fiches de tri par matière (US-120). Le contenu est embarqué dans
/// l'application (traductions), donc disponible hors ligne.
enum TipSheet {
  plastic('🧴', ['pet_bottle']),
  metal('🥫', ['can']),
  cardboard('📦', ['cardboard']),
  paper('📄', ['paper']),
  glass('🍾', ['glass']),
  eWaste('🔌', ['e_waste']),
  organic('🍂', ['organic']),
  hazardous('💊', ['medical']);

  const TipSheet(this.emoji, this.categoryIds);
  final String emoji;

  /// Catégories du catalogue concernées par la fiche.
  final List<String> categoryIds;
}

/// Fiches triées pour le citoyen : d'abord les matières qu'il recycle le
/// plus, puis l'ordre éditorial.
List<TipSheet> sheetsFor(Map<String, double> kgByCategory) {
  double kg(TipSheet s) => s.categoryIds.fold(0.0, (t, id) => t + (kgByCategory[id] ?? 0));
  final order = TipSheet.values.toList();
  return order..sort((a, b) {
    final byKg = kg(b).compareTo(kg(a));
    return byKg != 0 ? byKg : a.index.compareTo(b.index);
  });
}

/// Une ligne de contenu par élément (séparateur « | » dans les traductions).
List<String> tipItems(String raw) =>
    raw.split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
