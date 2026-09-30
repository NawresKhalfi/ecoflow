import 'dart:math';

import '../../collection/domain/geo.dart';
import '../../collection/domain/service_zone.dart';
import '../../profile/domain/company_profile.dart';
import 'forecast_model.dart';

/// Familles prévues (US-088) : le plastique regroupe PET, PEHD et PP.
enum MaterialGroup { plastic, cardboard, metal, glass, other }

MaterialGroup groupFor(RecyclableMaterial m) => switch (m) {
  RecyclableMaterial.pet ||
  RecyclableMaterial.hdpe ||
  RecyclableMaterial.pp => MaterialGroup.plastic,
  RecyclableMaterial.cardboard => MaterialGroup.cardboard,
  RecyclableMaterial.aluminium => MaterialGroup.metal,
  RecyclableMaterial.glass => MaterialGroup.glass,
  RecyclableMaterial.other => MaterialGroup.other,
};

/// Collecte pesée, ramenée à ce dont la prévision a besoin.
class VolumeRecord {
  const VolumeRecord({
    required this.zoneId,
    required this.day,
    required this.point,
    required this.kgByGroup,
  });

  final String zoneId;
  final DateTime day;
  final GeoPoint point;
  final Map<MaterialGroup, double> kgByGroup;

  double get totalKg => kgByGroup.values.fold(0, (a, b) => a + b);
}

/// Prévision d'une famille dans une zone.
class GroupForecast {
  const GroupForecast({
    required this.next7,
    required this.next30,
    required this.low7,
    required this.high7,
    required this.last7,
    required this.last30,
    required this.daily,
  });

  final double next7;
  final double next30;
  final double low7;
  final double high7;

  /// Réel observé sur les 7 et 30 derniers jours (comparaison).
  final double last7;
  final double last30;

  /// Prévision jour par jour sur 14 jours (graphique).
  final List<double> daily;

  /// Évolution prévue sur 7 jours par rapport aux 7 derniers jours.
  double? get trend7 => last7 == 0 ? null : (next7 - last7) / last7;

  Map<String, dynamic> toMap() => {
    'next7': next7,
    'next30': next30,
    'low7': low7,
    'high7': high7,
    'last7': last7,
    'last30': last30,
    'daily': daily,
  };

  static GroupForecast fromMap(Map m) {
    double d(String k) => (m[k] as num?)?.toDouble() ?? 0;
    return GroupForecast(
      next7: d('next7'),
      next30: d('next30'),
      low7: d('low7'),
      high7: d('high7'),
      last7: d('last7'),
      last30: d('last30'),
      daily: [for (final v in (m['daily'] as List? ?? const [])) (v as num).toDouble()],
    );
  }
}

/// Prévision publiée pour une zone : `forecasts/{zoneId}`.
class ZoneForecast {
  const ZoneForecast({
    required this.zoneId,
    required this.zoneName,
    required this.groups,
    required this.method,
    required this.samples,
    this.mape,
    this.wape,
    this.trainedAt,
  });

  final String zoneId;
  final String zoneName;
  final Map<MaterialGroup, GroupForecast> groups;
  final ForecastMethod method;

  /// Jours d'historique utilisés.
  final int samples;

  /// Précision au dernier entraînement (tous matériaux confondus, US-092).
  final double? mape;
  final double? wape;
  final DateTime? trainedAt;

  GroupForecast? get plastic => groups[MaterialGroup.plastic];

  double next(int days, [MaterialGroup? g]) => g == null
      ? groups.values.fold(0.0, (s, f) => s + (days == 7 ? f.next7 : f.next30))
      : (days == 7 ? groups[g]?.next7 : groups[g]?.next30) ?? 0;

  Map<String, dynamic> toMap() => {
    'zoneName': zoneName,
    'groups': {for (final e in groups.entries) e.key.name: e.value.toMap()},
    'method': method.name,
    'samples': samples,
    'mape': mape,
    'wape': wape,
  };

  static ZoneForecast fromMap(String id, Map<String, dynamic> m, {DateTime? trainedAt}) =>
      ZoneForecast(
        zoneId: id,
        zoneName: m['zoneName'] as String? ?? id,
        groups: {
          for (final e in (m['groups'] as Map? ?? const {}).entries)
            for (final g in MaterialGroup.values.where((g) => g.name == e.key))
              g: GroupForecast.fromMap(e.value as Map),
        },
        method:
            ForecastMethod.values.where((x) => x.name == m['method']).firstOrNull ??
            ForecastMethod.none,
        samples: (m['samples'] as num?)?.toInt() ?? 0,
        mape: (m['mape'] as num?)?.toDouble(),
        wape: (m['wape'] as num?)?.toDouble(),
        trainedAt: trainedAt,
      );
}

/// Historique retenu pour l'entraînement.
const forecastHistoryDays = 180;

double _sum(List<double> v, int lastDays) =>
    v.sublist(max(0, v.length - lastDays)).fold(0.0, (a, b) => a + b);

/// Entraîne un modèle par zone et par famille et produit les prévisions à
/// 7 et 30 jours (US-088, US-093).
Map<String, ZoneForecast> computeForecasts(
  List<VolumeRecord> records,
  List<ServiceZone> zones,
  DateTime now,
) {
  final to = dayOf(now).subtract(const Duration(days: 1));
  final from = to.subtract(const Duration(days: forecastHistoryDays - 1));
  final out = <String, ZoneForecast>{};
  for (final z in zones) {
    final mine = records.where(
      (r) => r.zoneId == z.id && !r.day.isBefore(from) && !r.day.isAfter(to),
    );
    // Début de série au premier jour d'activité de la zone.
    final firstDay = mine
        .map((r) => r.day)
        .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    if (firstDay == null) continue;
    final groups = <MaterialGroup, GroupForecast>{};
    final totalByDay = <DateTime, double>{};
    for (final g in MaterialGroup.values) {
      final byDay = <DateTime, double>{};
      for (final r in mine) {
        final kg = r.kgByGroup[g] ?? 0;
        if (kg <= 0) continue;
        byDay[dayOf(r.day)] = (byDay[dayOf(r.day)] ?? 0) + kg;
        totalByDay[dayOf(r.day)] = (totalByDay[dayOf(r.day)] ?? 0) + kg;
      }
      if (byDay.isEmpty) continue;
      final y = dailySeries(byDay, firstDay, to);
      final m = fitModel(y);
      final i7 = m.interval(7);
      groups[g] = GroupForecast(
        next7: m.forecast(7).fold(0.0, (a, b) => a + b),
        next30: m.forecast(30).fold(0.0, (a, b) => a + b),
        low7: i7.low,
        high7: i7.high,
        last7: _sum(y, 7),
        last30: _sum(y, 30),
        daily: m.forecast(14),
      );
    }
    final total = dailySeries(totalByDay, firstDay, to);
    final fit = fitModel(total);
    final bt = backtest(total);
    out[z.id] = ZoneForecast(
      zoneId: z.id,
      zoneName: z.name,
      groups: groups,
      method: fit.method,
      samples: total.length,
      mape: bt.mape,
      wape: bt.wape,
    );
  }
  return out;
}

enum AlertKind { overload, underCollection }

/// Alerte de déséquilibre prévu (US-091).
class ForecastAlert {
  const ForecastAlert({
    required this.zoneId,
    required this.zoneName,
    required this.kind,
    required this.forecastKg,
    required this.capacityKg,
    required this.unmatchedRatio,
  });

  final String zoneId;
  final String zoneName;
  final AlertKind kind;
  final double forecastKg;
  final double capacityKg;
  final double unmatchedRatio;
}

/// Offre de collecte d'une zone sur 7 jours et demandes restées sans
/// collecteur récemment.
typedef ZoneSupply = ({double capacity7Kg, int requests, int unmatched});

/// Surcharge : le volume prévu à 7 jours dépasse 90 % de la capacité des
/// collecteurs actifs de la zone. Sous-collecte : plus de 20 % des demandes
/// récentes sont restées sans collecteur, ou aucune capacité alors que du
/// volume est attendu.
List<ForecastAlert> computeAlerts(
  Map<String, ZoneForecast> forecasts,
  Map<String, ZoneSupply> supply,
) {
  final out = <ForecastAlert>[];
  for (final f in forecasts.values) {
    final s = supply[f.zoneId] ?? (capacity7Kg: 0.0, requests: 0, unmatched: 0);
    final next7 = f.next(7);
    final ratio = s.requests == 0 ? 0.0 : s.unmatched / s.requests;
    ForecastAlert alert(AlertKind k) => ForecastAlert(
      zoneId: f.zoneId,
      zoneName: f.zoneName,
      kind: k,
      forecastKg: next7,
      capacityKg: s.capacity7Kg,
      unmatchedRatio: ratio,
    );
    if (s.capacity7Kg > 0 && next7 > .9 * s.capacity7Kg) {
      out.add(alert(AlertKind.overload));
    } else if ((s.requests >= 5 && ratio > .2) || (s.capacity7Kg == 0 && next7 > 0)) {
      out.add(alert(AlertKind.underCollection));
    }
  }
  out.sort((a, b) => b.forecastKg.compareTo(a.forecastKg));
  return out;
}

/// Cellule de la carte de chaleur (US-090).
typedef HeatCell = ({GeoPoint center, double kg});

/// Agrège les collectes sur une grille d'environ [cellKm] km.
List<HeatCell> heatCells(List<VolumeRecord> records, {double cellKm = 1}) {
  final dLat = cellKm / 111.0;
  final cells = <(int, int), ({double lat, double lng, double kg, int n})>{};
  for (final r in records) {
    final dLng = cellKm / (111.0 * cos(r.point.lat * pi / 180));
    final key = ((r.point.lat / dLat).floor(), (r.point.lng / dLng).floor());
    final c = cells[key];
    cells[key] = (
      lat: (c?.lat ?? 0) + r.point.lat,
      lng: (c?.lng ?? 0) + r.point.lng,
      kg: (c?.kg ?? 0) + r.totalKg,
      n: (c?.n ?? 0) + 1,
    );
  }
  return [for (final c in cells.values) (center: GeoPoint(c.lat / c.n, c.lng / c.n), kg: c.kg)]
    ..sort((a, b) => b.kg.compareTo(a.kg));
}
