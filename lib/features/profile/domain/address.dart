/// Adresse de collecte enregistrée par un citoyen (US-005).
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.street,
    required this.city,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String street;
  final String city;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  bool get hasPosition => latitude != null && longitude != null;

  SavedAddress copyWith({
    String? id,
    String? label,
    String? street,
    String? city,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) => SavedAddress(
    id: id ?? this.id,
    label: label ?? this.label,
    street: street ?? this.street,
    city: city ?? this.city,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    isDefault: isDefault ?? this.isDefault,
  );

  Map<String, dynamic> toMap() => {
    'label': label,
    'street': street,
    'city': city,
    'latitude': latitude,
    'longitude': longitude,
    'isDefault': isDefault,
  };

  static SavedAddress fromMap(String id, Map<String, dynamic> m) => SavedAddress(
    id: id,
    label: m['label'] as String? ?? '',
    street: m['street'] as String? ?? '',
    city: m['city'] as String? ?? '',
    latitude: (m['latitude'] as num?)?.toDouble(),
    longitude: (m['longitude'] as num?)?.toDouble(),
    isDefault: m['isDefault'] as bool? ?? false,
  );
}

/// Trie les adresses (défaut en premier) et garantit une seule adresse par
/// défaut : la première de la liste si aucune n'est marquée.
List<SavedAddress> normalizeAddresses(List<SavedAddress> list) {
  if (list.isEmpty) return list;
  final defaultId = list.firstWhere((a) => a.isDefault, orElse: () => list.first).id;
  final result = [for (final a in list) a.copyWith(isDefault: a.id == defaultId)];
  result.sort((a, b) => a.isDefault == b.isDefault ? 0 : (a.isDefault ? -1 : 1));
  return result;
}
