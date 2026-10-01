import '../../collection/domain/geo.dart';
import '../../collection/domain/service_zone.dart';
import '../../recycler/domain/reception.dart';
import '../../scan/domain/waste_category.dart';
import 'zone_forecast.dart';

/// Lecture d'une date quel que soit le format source (Timestamp Firestore
/// dans l'app, chaîne ISO dans le script de nuit).
typedef DateReader = DateTime? Function(Object? value);

DateTime? _slotDay(Object? slotId) =>
    slotId is String && slotId.length >= 10 ? DateTime.tryParse(slotId.substring(0, 10)) : null;

/// Données d'entraînement (US-088) à partir des collectes terminées et de
/// leurs pesées. Partagé par l'app et le réentraînement de nuit (US-093)
/// pour que les deux produisent exactement le même modèle.
List<VolumeRecord> volumeRecordsFrom(
  Iterable<Map<String, dynamic>> completed,
  Map<String, Map<String, dynamic>> estimates,
  List<WasteCategory> catalog,
  DateReader date,
) {
  final out = <VolumeRecord>[];
  for (final m in completed) {
    final est = estimates[m['estimateCode']];
    final place = m['place'] as Map?;
    final point = GeoPoint.fromMap(place?['point']);
    final day = date(m['completedAt']) ?? date(est?['weighedAt']) ?? _slotDay(m['slotId']);
    if (est == null || point == null || day == null) continue;
    final byGroup = <MaterialGroup, double>{};
    for (final e in (est['actualKg'] as Map? ?? const {}).entries) {
      final g = groupFor(materialForCategory('${e.key}', catalog));
      byGroup[g] = (byGroup[g] ?? 0) + (e.value as num).toDouble();
    }
    out.add(
      VolumeRecord(
        zoneId: place?['zoneId'] as String? ?? '',
        day: day,
        point: point,
        kgByGroup: byGroup,
      ),
    );
  }
  return out;
}

/// Collecteurs actifs par zone sur les collectes récentes.
Map<String, Set<String>> activeCollectors(Iterable<Map<String, dynamic>> recent) {
  final out = <String, Set<String>>{};
  for (final m in recent) {
    final zone = (m['place'] as Map?)?['zoneId'] as String? ?? '';
    if (m['collectorUid'] case final String c) out.putIfAbsent(zone, () => {}).add(c);
  }
  return out;
}

/// Offre de collecte par zone (US-091) : capacité hebdomadaire des
/// collecteurs actifs sur 30 jours (capacité × 5 tournées) et demandes des
/// 14 derniers jours restées sans collecteur.
Map<String, ZoneSupply> supplyFrom(
  Iterable<Map<String, dynamic>> recent,
  Map<String, double> capacityByCollector,
  List<ServiceZone> zones,
  DateTime now,
  DateReader date,
) {
  final collectors = activeCollectors(recent);
  final requests = <String, int>{};
  final unmatched = <String, int>{};
  final two = now.subtract(const Duration(days: 14));
  for (final m in recent) {
    final zone = (m['place'] as Map?)?['zoneId'] as String? ?? '';
    if ((date(m['createdAt']) ?? now).isBefore(two)) continue;
    requests[zone] = (requests[zone] ?? 0) + 1;
    if (m['status'] == 'noCollector' || m['cancelReason'] == 'noCollector') {
      unmatched[zone] = (unmatched[zone] ?? 0) + 1;
    }
  }
  return {
    for (final z in zones)
      z.id: (
        capacity7Kg: (collectors[z.id] ?? const {}).fold(
          0.0,
          (s, c) => s + (capacityByCollector[c] ?? 200) * 5,
        ),
        requests: requests[z.id] ?? 0,
        unmatched: unmatched[z.id] ?? 0,
      ),
  };
}

/// Contenu d'un entraînement historisé (`forecastRuns`), hors horodatage.
Map<String, dynamic> runDocument({
  required Map<String, ZoneForecast> forecasts,
  required List<ForecastAlert> alerts,
  required int records,
  required String adminUid,
  required String trigger,
}) => {
  'by': adminUid,
  'trigger': trigger,
  'records': records,
  'zones': {
    for (final f in forecasts.values)
      f.zoneId: {'mape': f.mape, 'wape': f.wape, 'samples': f.samples},
  },
  'alerts': [
    for (final a in alerts)
      {
        'zoneId': a.zoneId,
        'zoneName': a.zoneName,
        'kind': a.kind.name,
        'forecastKg': a.forecastKg,
        'capacityKg': a.capacityKg,
        'unmatchedRatio': a.unmatchedRatio,
      },
  ],
};
