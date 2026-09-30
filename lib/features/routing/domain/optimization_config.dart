import '../../missions/domain/vehicle.dart';

/// Paramètres de l'optimisation (US-062), `config/optimization` ; chaque
/// publication est historisée dans `config/optimization/history`.
class OptimizationConfig {
  const OptimizationConfig({
    this.roadFactor = 1.3,
    this.speedKmh = 25,
    this.serviceMinutes = 10,
    this.maxDetourKm = 3,
    this.clusterRadiusKm = 2,
    this.distanceWeight = 1,
    this.waitWeight = .2,
    this.fuelPriceDt = 2.525,
    this.co2KgPerLiter = 2.31,
  });

  /// Distance routière ≈ distance à vol d'oiseau × facteur (réseau urbain).
  final double roadFactor;

  /// Vitesse moyenne en ville.
  final double speedKmh;

  /// Durée d'une collecte sur place.
  final double serviceMinutes;

  /// Détour maximal accepté pour suggérer une mission (US-061).
  final double maxDetourKm;

  /// Rayon de regroupement des collectes proches (US-056).
  final double clusterRadiusKm;

  /// Poids des critères : kilomètres et minutes d'attente (US-062).
  final double distanceWeight;
  final double waitWeight;

  /// Prix du carburant (DT/L) et émissions (kg CO₂ par litre d'essence).
  final double fuelPriceDt;
  final double co2KgPerLiter;

  OptimizationConfig copyWith({
    double? roadFactor,
    double? speedKmh,
    double? serviceMinutes,
    double? maxDetourKm,
    double? clusterRadiusKm,
    double? distanceWeight,
    double? waitWeight,
    double? fuelPriceDt,
  }) => OptimizationConfig(
    roadFactor: roadFactor ?? this.roadFactor,
    speedKmh: speedKmh ?? this.speedKmh,
    serviceMinutes: serviceMinutes ?? this.serviceMinutes,
    maxDetourKm: maxDetourKm ?? this.maxDetourKm,
    clusterRadiusKm: clusterRadiusKm ?? this.clusterRadiusKm,
    distanceWeight: distanceWeight ?? this.distanceWeight,
    waitWeight: waitWeight ?? this.waitWeight,
    fuelPriceDt: fuelPriceDt ?? this.fuelPriceDt,
    co2KgPerLiter: co2KgPerLiter,
  );

  Map<String, dynamic> toMap() => {
    'roadFactor': roadFactor,
    'speedKmh': speedKmh,
    'serviceMinutes': serviceMinutes,
    'maxDetourKm': maxDetourKm,
    'clusterRadiusKm': clusterRadiusKm,
    'distanceWeight': distanceWeight,
    'waitWeight': waitWeight,
    'fuelPriceDt': fuelPriceDt,
    'co2KgPerLiter': co2KgPerLiter,
  };

  static OptimizationConfig fromMap(Map<String, dynamic>? m) {
    if (m == null) return const OptimizationConfig();
    double d(String k, double v) => (m[k] as num?)?.toDouble() ?? v;
    const x = OptimizationConfig();
    return OptimizationConfig(
      roadFactor: d('roadFactor', x.roadFactor),
      speedKmh: d('speedKmh', x.speedKmh),
      serviceMinutes: d('serviceMinutes', x.serviceMinutes),
      maxDetourKm: d('maxDetourKm', x.maxDetourKm),
      clusterRadiusKm: d('clusterRadiusKm', x.clusterRadiusKm),
      distanceWeight: d('distanceWeight', x.distanceWeight),
      waitWeight: d('waitWeight', x.waitWeight),
      fuelPriceDt: d('fuelPriceDt', x.fuelPriceDt),
      co2KgPerLiter: d('co2KgPerLiter', x.co2KgPerLiter),
    );
  }
}

/// Consommation moyenne (L/100 km) par type de véhicule ; 0 pour le vélo.
double fuelLitersPer100Km(VehicleType t) => switch (t) {
  VehicleType.bike || VehicleType.cargoBike => 0,
  VehicleType.motorbike => 3,
  VehicleType.car => 7,
  VehicleType.van => 10,
  VehicleType.truck => 25,
};
