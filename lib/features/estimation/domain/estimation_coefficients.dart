/// Contenants standard proposés au citoyen (US-026).
enum WasteContainer {
  bag30(30),
  bag50(50),
  bag100(100),
  cardboardBox(40),
  crate(60);

  const WasteContainer(this.liters);
  final double liters;

  /// Taux de remplissage moyen supposé.
  static const fillRate = .8;
  double get usefulLiters => liters * fillRate;
}

/// Coefficients de l'estimation de poids, recalibrés à partir des pesées
/// (US-030) : `config/estimation`.
class EstimationCoefficients {
  const EstimationCoefficients({
    required this.unitWeightKg,
    required this.densityKgPerL,
    this.version = 1,
  });

  /// Poids moyen d'un objet détecté, par catégorie du catalogue.
  final Map<String, double> unitWeightKg;

  /// Densité en vrac (kg par litre de contenant), par catégorie.
  final Map<String, double> densityKgPerL;
  final int version;

  double unitWeight(String categoryId) => unitWeightKg[categoryId] ?? unitWeightKg['other'] ?? .1;
  double density(String categoryId) => densityKgPerL[categoryId] ?? densityKgPerL['other'] ?? .05;

  Map<String, dynamic> toMap() => {
    'unitWeightKg': unitWeightKg,
    'densityKgPerL': densityKgPerL,
    'version': version,
  };

  static EstimationCoefficients fromMap(Map<String, dynamic>? m) {
    if (m == null) return defaultCoefficients;
    Map<String, double> read(String k, Map<String, double> fallback) => {
      ...fallback,
      for (final e in (m[k] as Map? ?? const {}).entries) '${e.key}': (e.value as num).toDouble(),
    };
    return EstimationCoefficients(
      unitWeightKg: read('unitWeightKg', defaultCoefficients.unitWeightKg),
      densityKgPerL: read('densityKgPerL', defaultCoefficients.densityKgPerL),
      version: (m['version'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Valeurs initiales (ordres de grandeur usuels), affinées par recalibrage.
const defaultCoefficients = EstimationCoefficients(
  unitWeightKg: {
    'pet_bottle': .03,
    'can': .015,
    'cardboard': .25,
    'paper': .05,
    'glass': .35,
    'e_waste': .5,
    'organic': .2,
    'medical': .05,
    'other': .1,
  },
  densityKgPerL: {
    'pet_bottle': .02,
    'can': .035,
    'cardboard': .06,
    'paper': .12,
    'glass': .3,
    'e_waste': .2,
    'organic': .4,
    'medical': .05,
    'other': .05,
  },
);
