import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;

import '../../collection/domain/service_zone.dart';
import '../../scan/domain/waste_category.dart';
import '../domain/training_data.dart';
import '../domain/zone_forecast.dart';

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

/// Entraînement historisé : `forecastRuns/{id}` (US-092, US-093).
class ForecastRun {
  const ForecastRun({
    required this.id,
    required this.records,
    required this.zones,
    required this.alerts,
    this.at,
    this.trigger = 'manual',
  });

  final String id;
  final int records;

  /// zone → (MAPE, WAPE, jours d'historique)
  final Map<String, ({double? mape, double? wape, int samples})> zones;
  final List<ForecastAlert> alerts;
  final DateTime? at;
  final String trigger;

  /// MAPE moyen des zones évaluables.
  double? get mape {
    final v = [for (final z in zones.values) ?z.mape];
    return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  }
}

/// Collecte des données d'entraînement (administrateur) et publication
/// des prévisions : `forecasts/{zoneId}`, `forecastRuns/{id}`.
class ForecastRepository {
  ForecastRepository(this._db);
  final FirebaseFirestore _db;

  /// Collectes terminées et leurs pesées, par zone (lecture admin).
  Future<List<VolumeRecord>> volumeRecords(List<WasteCategory> catalog) async {
    final done = await _db.collection('collections').where('status', isEqualTo: 'completed').get();
    final codes = [
      for (final d in done.docs)
        if (d.data()['estimateCode'] case final String c) c,
    ];
    final estimates = <String, Map<String, dynamic>>{};
    for (var i = 0; i < codes.length; i += 30) {
      final q = await _db
          .collection('estimates')
          .where(
            FieldPath.documentId,
            whereIn: codes.sublist(i, i + 30 > codes.length ? codes.length : i + 30),
          )
          .get();
      for (final d in q.docs) {
        estimates[d.id] = d.data();
      }
    }
    return volumeRecordsFrom([for (final d in done.docs) d.data()], estimates, catalog, _date);
  }

  /// Offre de collecte par zone (US-091) : capacité hebdomadaire des
  /// collecteurs actifs dans la zone sur 30 jours (capacité du véhicule ×
  /// 5 tournées), et demandes des 14 derniers jours restées sans collecteur.
  Future<Map<String, ZoneSupply>> supply(List<ServiceZone> zones, DateTime now) async {
    final since = now.subtract(const Duration(days: 30));
    final recent = await _db
        .collection('collections')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();
    final rows = [for (final d in recent.docs) d.data()];
    final capacity = <String, double>{};
    for (final uid in {for (final c in activeCollectors(rows).values) ...c}) {
      final p = (await _db.collection('collectorPresence').doc(uid).get()).data();
      capacity[uid] = (p?['capacityKg'] as num?)?.toDouble() ?? 200;
    }
    return supplyFrom(rows, capacity, zones, now, _date);
  }

  /// Publie les prévisions et l'entraînement en un seul batch.
  Future<void> publish({
    required Map<String, ZoneForecast> forecasts,
    required List<ForecastAlert> alerts,
    required int records,
    required String adminUid,
    required String trigger,
  }) async {
    final batch = _db.batch();
    for (final f in forecasts.values) {
      batch.set(_db.collection('forecasts').doc(f.zoneId), {
        ...f.toMap(),
        'trainedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(_db.collection('forecastRuns').doc(), {
      'at': FieldValue.serverTimestamp(),
      ...runDocument(
        forecasts: forecasts,
        alerts: alerts,
        records: records,
        adminUid: adminUid,
        trigger: trigger,
      ),
    });
    await batch.commit();
  }

  Stream<List<ZoneForecast>> watchForecasts() => _db
      .collection('forecasts')
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            ZoneForecast.fromMap(d.id, d.data(), trainedAt: _date(d.data()['trainedAt'])),
        ]..sort((a, b) => b.next(30).compareTo(a.next(30))),
      );

  Stream<List<ForecastRun>> watchRuns() => _db
      .collection('forecastRuns')
      .orderBy('at', descending: true)
      .limit(30)
      .snapshots()
      .map((s) => [for (final d in s.docs) _run(d.id, d.data())]);

  ForecastRun _run(String id, Map<String, dynamic> m) => ForecastRun(
    id: id,
    records: (m['records'] as num?)?.toInt() ?? 0,
    at: _date(m['at']),
    trigger: m['trigger'] as String? ?? 'manual',
    zones: {
      for (final e in (m['zones'] as Map? ?? const {}).entries)
        '${e.key}': (
          mape: ((e.value as Map)['mape'] as num?)?.toDouble(),
          wape: ((e.value as Map)['wape'] as num?)?.toDouble(),
          samples: ((e.value as Map)['samples'] as num?)?.toInt() ?? 0,
        ),
    },
    alerts: [
      for (final a in (m['alerts'] as List? ?? const []))
        ForecastAlert(
          zoneId: (a as Map)['zoneId'] as String? ?? '',
          zoneName: a['zoneName'] as String? ?? '',
          kind:
              AlertKind.values.where((k) => k.name == a['kind']).firstOrNull ?? AlertKind.overload,
          forecastKg: (a['forecastKg'] as num?)?.toDouble() ?? 0,
          capacityKg: (a['capacityKg'] as num?)?.toDouble() ?? 0,
          unmatchedRatio: (a['unmatchedRatio'] as num?)?.toDouble() ?? 0,
        ),
    ],
  );
}
