import '../../profile/domain/company_profile.dart';

/// Recyclabilité d'une matière.
enum Recyclability {
  low,
  medium,
  high;

  /// Poids utilisé pour la recyclabilité globale d'un scan.
  double get score => switch (this) {
    Recyclability.low => 0,
    Recyclability.medium => .5,
    Recyclability.high => 1,
  };

  static Recyclability fromName(String? n) =>
      values.firstWhere((v) => v.name == n, orElse: () => Recyclability.medium);
}

/// Classe de déchet du catalogue (US-022), stockée dans `wasteCategories/{id}`.
///
/// [modelLabels] relie les classes brutes du modèle YOLO à cette catégorie ;
/// [material] relie la catégorie au barème de prix (epic 3).
class WasteCategory {
  const WasteCategory({
    required this.id,
    required this.names,
    required this.emoji,
    required this.recyclability,
    this.modelLabels = const [],
    this.material,
    this.active = true,
    this.order = 0,
  });

  final String id;

  /// Nom par code langue (`fr`, `en`, `ar`).
  final Map<String, String> names;
  final String emoji;
  final Recyclability recyclability;
  final List<String> modelLabels;
  final RecyclableMaterial? material;
  final bool active;
  final int order;

  String name(String languageCode) => names[languageCode] ?? names['fr'] ?? id;

  WasteCategory copyWith({
    Map<String, String>? names,
    String? emoji,
    Recyclability? recyclability,
    List<String>? modelLabels,
    RecyclableMaterial? material,
    bool? active,
    int? order,
  }) => WasteCategory(
    id: id,
    names: names ?? this.names,
    emoji: emoji ?? this.emoji,
    recyclability: recyclability ?? this.recyclability,
    modelLabels: modelLabels ?? this.modelLabels,
    material: material ?? this.material,
    active: active ?? this.active,
    order: order ?? this.order,
  );

  Map<String, dynamic> toMap() => {
    'names': names,
    'emoji': emoji,
    'recyclability': recyclability.name,
    'modelLabels': modelLabels,
    'material': material?.name,
    'active': active,
    'order': order,
  };

  static WasteCategory fromMap(String id, Map<String, dynamic> m) => WasteCategory(
    id: id,
    names: (m['names'] as Map? ?? const {}).cast<String, String>(),
    emoji: m['emoji'] as String? ?? '♻️',
    recyclability: Recyclability.fromName(m['recyclability'] as String?),
    modelLabels: (m['modelLabels'] as List? ?? const []).cast<String>(),
    material: RecyclableMaterial.values.where((v) => v.name == m['material']).firstOrNull,
    active: m['active'] as bool? ?? true,
    order: (m['order'] as num?)?.toInt() ?? 0,
  );
}

/// Catégorie de repli pour une classe du modèle non cataloguée.
const otherCategoryId = 'other';

/// Catalogue initial, aligné sur les 8 classes du modèle embarqué
/// (cardboard, e-waste, glass, medical, metal, organic, paper, plastic).
const defaultCatalog = [
  WasteCategory(
    id: 'pet_bottle',
    names: {'fr': 'Bouteilles PET', 'en': 'PET bottles', 'ar': 'قوارير PET'},
    emoji: '🧴',
    recyclability: Recyclability.high,
    modelLabels: ['plastic'],
    material: RecyclableMaterial.pet,
    order: 1,
  ),
  WasteCategory(
    id: 'can',
    names: {'fr': 'Canettes', 'en': 'Cans', 'ar': 'علب معدنية'},
    emoji: '🥫',
    recyclability: Recyclability.high,
    modelLabels: ['metal'],
    material: RecyclableMaterial.aluminium,
    order: 2,
  ),
  WasteCategory(
    id: 'cardboard',
    names: {'fr': 'Carton', 'en': 'Cardboard', 'ar': 'كرتون'},
    emoji: '📦',
    recyclability: Recyclability.high,
    modelLabels: ['cardboard'],
    material: RecyclableMaterial.cardboard,
    order: 3,
  ),
  WasteCategory(
    id: 'paper',
    names: {'fr': 'Papier', 'en': 'Paper', 'ar': 'ورق'},
    emoji: '📄',
    recyclability: Recyclability.high,
    modelLabels: ['paper'],
    material: RecyclableMaterial.cardboard,
    order: 4,
  ),
  WasteCategory(
    id: 'glass',
    names: {'fr': 'Verre', 'en': 'Glass', 'ar': 'زجاج'},
    emoji: '🍾',
    recyclability: Recyclability.high,
    modelLabels: ['glass'],
    material: RecyclableMaterial.glass,
    order: 5,
  ),
  WasteCategory(
    id: 'e_waste',
    names: {'fr': 'Déchets électroniques', 'en': 'E-waste', 'ar': 'نفايات إلكترونية'},
    emoji: '🔌',
    recyclability: Recyclability.medium,
    modelLabels: ['e-waste'],
    order: 6,
  ),
  WasteCategory(
    id: 'organic',
    names: {'fr': 'Organique', 'en': 'Organic', 'ar': 'عضوية'},
    emoji: '🍂',
    recyclability: Recyclability.low,
    modelLabels: ['organic'],
    order: 7,
  ),
  WasteCategory(
    id: 'medical',
    names: {'fr': 'Déchets médicaux', 'en': 'Medical waste', 'ar': 'نفايات طبية'},
    emoji: '💉',
    recyclability: Recyclability.low,
    modelLabels: ['medical'],
    order: 8,
  ),
  WasteCategory(
    id: otherCategoryId,
    names: {'fr': 'Autres', 'en': 'Other', 'ar': 'أخرى'},
    emoji: '♻️',
    recyclability: Recyclability.low,
    material: RecyclableMaterial.other,
    order: 99,
  ),
];

/// Classe du catalogue correspondant à une étiquette brute du modèle.
String categoryForLabel(List<WasteCategory> catalog, String rawLabel) {
  final label = rawLabel.trim().toLowerCase();
  for (final c in catalog.where((c) => c.active)) {
    if (c.modelLabels.any((l) => l.toLowerCase() == label)) return c.id;
  }
  return otherCategoryId;
}
