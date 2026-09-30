/// Véhicule du collecteur (US-054), utilisé par la recherche (capacité).
enum VehicleType {
  bike(15, .1),
  cargoBike(80, .5),
  motorbike(40, .3),
  car(150, 1),
  van(600, 6),
  truck(2000, 20);

  const VehicleType(this.defaultCapacityKg, this.defaultVolumeM3);
  final double defaultCapacityKg;
  final double defaultVolumeM3;

  static VehicleType fromName(String? n) =>
      values.firstWhere((v) => v.name == n, orElse: () => VehicleType.car);
}

class Vehicle {
  const Vehicle({
    required this.type,
    required this.capacityKg,
    required this.volumeM3,
    this.plate = '',
  });

  factory Vehicle.defaultFor(VehicleType t) =>
      Vehicle(type: t, capacityKg: t.defaultCapacityKg, volumeM3: t.defaultVolumeM3);

  final VehicleType type;
  final double capacityKg;
  final double volumeM3;
  final String plate;

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'capacityKg': capacityKg,
    'volumeM3': volumeM3,
    'plate': plate.trim(),
  };

  static Vehicle? fromMap(Object? m) => m is Map
      ? Vehicle(
          type: VehicleType.fromName(m['type'] as String?),
          capacityKg: (m['capacityKg'] as num?)?.toDouble() ?? 0,
          volumeM3: (m['volumeM3'] as num?)?.toDouble() ?? 0,
          plate: m['plate'] as String? ?? '',
        )
      : null;
}
