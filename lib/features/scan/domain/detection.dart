/// Cadre normalisé (0..1) dans l'image.
class BoundingBox {
  const BoundingBox(this.left, this.top, this.right, this.bottom);

  final double left, top, right, bottom;

  double get width => (right - left).clamp(0, 1);
  double get height => (bottom - top).clamp(0, 1);
  double get area => width * height;

  /// Format YOLO : centre x, centre y, largeur, hauteur.
  List<double> get yolo => [left + width / 2, top + height / 2, width, height];

  Map<String, double> toMap() => {'l': left, 't': top, 'r': right, 'b': bottom};

  static BoundingBox fromMap(Map m) => BoundingBox(
    (m['l'] as num).toDouble(),
    (m['t'] as num).toDouble(),
    (m['r'] as num).toDouble(),
    (m['b'] as num).toDouble(),
  );
}

/// Sortie brute du détecteur.
class RawDetection {
  const RawDetection({required this.label, required this.confidence, required this.box});

  final String label;
  final double confidence;
  final BoundingBox box;
}

enum DetectionSource { model, manual }

/// Objet reconnu (ou ajouté à la main) sur une photo d'un scan.
class Detection {
  const Detection({
    required this.id,
    required this.photoIndex,
    required this.categoryId,
    required this.confidence,
    this.box,
    this.rawLabel,
    this.source = DetectionSource.model,
    this.originalCategoryId,
  });

  final String id;
  final int photoIndex;
  final String categoryId;
  final double confidence;

  /// Absent pour un ajout manuel (pas de cadre dessiné).
  final BoundingBox? box;
  final String? rawLabel;
  final DetectionSource source;

  /// Catégorie proposée par l'IA avant correction de l'utilisateur.
  final String? originalCategoryId;

  bool get isRelabelled => originalCategoryId != null && originalCategoryId != categoryId;

  Detection relabel(String newCategoryId) => Detection(
    id: id,
    photoIndex: photoIndex,
    categoryId: newCategoryId,
    confidence: confidence,
    box: box,
    rawLabel: rawLabel,
    source: source,
    originalCategoryId: originalCategoryId ?? categoryId,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'photo': photoIndex,
    'category': categoryId,
    'confidence': confidence,
    'box': box?.toMap(),
    'rawLabel': rawLabel,
    'source': source.name,
    'originalCategory': originalCategoryId,
  };

  static Detection fromMap(Map m) => Detection(
    id: m['id'] as String,
    photoIndex: (m['photo'] as num?)?.toInt() ?? 0,
    categoryId: m['category'] as String,
    confidence: (m['confidence'] as num?)?.toDouble() ?? 1,
    box: m['box'] == null ? null : BoundingBox.fromMap(m['box'] as Map),
    rawLabel: m['rawLabel'] as String?,
    source: m['source'] == 'manual' ? DetectionSource.manual : DetectionSource.model,
    originalCategoryId: m['originalCategory'] as String?,
  );
}
