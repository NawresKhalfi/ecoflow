/// Version du modèle de vision déployée (US-019), `modelVersions/{id}`.
///
/// [iosModel] / [androidModel] : chemin d'asset Flutter embarqué ou URL
/// https (le plugin Ultralytics télécharge et met en cache).
class ModelVersion {
  const ModelVersion({
    required this.id,
    required this.name,
    required this.iosModel,
    required this.androidModel,
    this.precision,
    this.recall,
    this.map50,
    this.notes = '',
    this.createdAt,
  });

  final String id;
  final String name;
  final String iosModel;
  final String androidModel;
  final double? precision;
  final double? recall;
  final double? map50;
  final String notes;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
    'name': name,
    'iosModel': iosModel,
    'androidModel': androidModel,
    'precision': precision,
    'recall': recall,
    'map50': map50,
    'notes': notes,
  };

  static ModelVersion fromMap(String id, Map<String, dynamic> m, {DateTime? createdAt}) =>
      ModelVersion(
        id: id,
        name: m['name'] as String? ?? id,
        iosModel: m['iosModel'] as String? ?? bundledModel.iosModel,
        androidModel: m['androidModel'] as String? ?? bundledModel.androidModel,
        precision: (m['precision'] as num?)?.toDouble(),
        recall: (m['recall'] as num?)?.toDouble(),
        map50: (m['map50'] as num?)?.toDouble(),
        notes: m['notes'] as String? ?? '',
        createdAt: createdAt,
      );
}

/// Modèle embarqué dans l'application : YOLOv8m « waste-detection »
/// (HrutikAdsare, licence MIT). Seul le rappel moyen est publié par
/// l'auteur (moyenne des rappels par classe) ; précision et mAP non mesurés.
const bundledModel = ModelVersion(
  id: 'waste-yolov8m-v1',
  name: 'Waste YOLOv8m v1 (embarqué)',
  iosModel: 'assets/models/waste_yolov8m.mlpackage.zip',
  androidModel: 'assets/models/waste_yolov8m.tflite',
  recall: .735,
  notes:
      'Rappel publié par classe : organique 96 %, papier 83 %, métal 81 %, carton 76 %, '
      'e-déchets 75 %, plastique 63 %, verre 60 %, médical 54 %.',
);

/// Configuration de la vision : `config/vision`.
class VisionConfig {
  const VisionConfig({
    this.activeVersionId = 'waste-yolov8m-v1',
    this.confidenceThreshold = .35,
    this.history = const [],
  });

  final String activeVersionId;
  final double confidenceThreshold;

  /// Versions précédemment actives, la plus récente en dernier (rollback).
  final List<String> history;

  /// Version à restaurer lors d'un retour arrière.
  String? get previousVersionId => history.isEmpty ? null : history.last;

  VisionConfig activate(String versionId) => versionId == activeVersionId
      ? this
      : VisionConfig(
          activeVersionId: versionId,
          confidenceThreshold: confidenceThreshold,
          history: [...history, activeVersionId],
        );

  VisionConfig rollback() {
    final prev = previousVersionId;
    if (prev == null) return this;
    return VisionConfig(
      activeVersionId: prev,
      confidenceThreshold: confidenceThreshold,
      history: history.sublist(0, history.length - 1),
    );
  }

  VisionConfig withThreshold(double t) => VisionConfig(
    activeVersionId: activeVersionId,
    confidenceThreshold: t.clamp(.05, .95),
    history: history,
  );

  Map<String, dynamic> toMap() => {
    'activeVersionId': activeVersionId,
    'confidenceThreshold': confidenceThreshold,
    'history': history,
  };

  static VisionConfig fromMap(Map<String, dynamic>? m) => m == null
      ? const VisionConfig()
      : VisionConfig(
          activeVersionId: m['activeVersionId'] as String? ?? bundledModel.id,
          confidenceThreshold: (m['confidenceThreshold'] as num?)?.toDouble() ?? .35,
          history: (m['history'] as List? ?? const []).cast<String>(),
        );
}
