import 'estimate.dart';
import 'estimation_coefficients.dart';
import 'weighing.dart';

enum EstimateStatus { estimated, weighed }

/// Estimation enregistrée, identifiée par son code de pesée : `estimates/{code}`.
class EstimateRecord {
  const EstimateRecord({
    required this.code,
    required this.citizenUid,
    required this.lines,
    required this.confidence,
    required this.priceScaleId,
    this.scanId,
    this.container,
    this.status = EstimateStatus.estimated,
    this.actualKg = const {},
    this.collectorUid,
    this.createdAt,
    this.weighedAt,
  });

  final String code;
  final String citizenUid;
  final String? scanId;
  final List<EstimateLine> lines;
  final double confidence;
  final String priceScaleId;
  final WasteContainer? container;
  final EstimateStatus status;
  final Map<String, double> actualKg;
  final String? collectorUid;
  final DateTime? createdAt;
  final DateTime? weighedAt;

  Estimate get estimate =>
      Estimate(lines: lines, confidence: confidence, priceScaleId: priceScaleId);
  bool get isWeighed => status == EstimateStatus.weighed;
  WeighingResult? get weighing => isWeighed ? compareWeighing(lines, actualKg) : null;

  /// Vue « avant pesée » : le réel est provisoirement égal à l'estimé.
  WeighingResult get estimateAsPending =>
      compareWeighing(lines, {for (final l in lines) l.categoryId: l.kg});

  Map<String, dynamic> toCreateMap() => {
    'citizenUid': citizenUid,
    'scanId': scanId,
    'lines': [for (final l in lines) l.toMap()],
    'totalKg': estimate.totalKg,
    'totalDt': estimate.totalDt,
    'confidence': confidence,
    'priceScaleId': priceScaleId,
    'container': container?.name,
    'status': EstimateStatus.estimated.name,
  };

  static EstimateRecord fromMap(
    String code,
    Map<String, dynamic> m, {
    DateTime? createdAt,
    DateTime? weighedAt,
  }) => EstimateRecord(
    code: code,
    citizenUid: m['citizenUid'] as String? ?? '',
    scanId: m['scanId'] as String?,
    lines: [for (final l in (m['lines'] as List? ?? const [])) EstimateLine.fromMap(l as Map)],
    confidence: (m['confidence'] as num?)?.toDouble() ?? 0,
    priceScaleId: m['priceScaleId'] as String? ?? '',
    container: WasteContainer.values.where((c) => c.name == m['container']).firstOrNull,
    status: m['status'] == 'weighed' ? EstimateStatus.weighed : EstimateStatus.estimated,
    actualKg: {
      for (final e in (m['actualKg'] as Map? ?? const {}).entries)
        '${e.key}': (e.value as num).toDouble(),
    },
    collectorUid: m['collectorUid'] as String?,
    createdAt: createdAt,
    weighedAt: weighedAt,
  );
}
