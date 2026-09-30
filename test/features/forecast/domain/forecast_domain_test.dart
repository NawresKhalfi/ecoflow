import 'dart:math';

import 'package:ecoflow/features/collection/domain/geo.dart';
import 'package:ecoflow/features/collection/domain/service_zone.dart';
import 'package:ecoflow/features/forecast/domain/forecast_model.dart';
import 'package:ecoflow/features/forecast/domain/zone_forecast.dart';
import 'package:ecoflow/features/profile/domain/company_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Série hebdomadaire : pic le samedi, creux le dimanche, légère tendance.
const weekly = [30.0, 32, 35, 33, 40, 60, 10];
double truth(int t) => weekly[t % 7] + .3 * t;

void main() {
  group('model (US-093)', () {
    test('daily series fills missing days with zeros', () {
      final y = dailySeries(
        {DateTime(2026, 9, 1): 3, DateTime(2026, 9, 3): 5},
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 4, 18),
      );
      expect(y, [3, 0, 5, 0]);
    });

    test('Holt-Winters learns weekly seasonality and trend', () {
      final y = [for (var t = 0; t < 84; t++) truth(t)];
      final m = fitModel(y);
      expect(m.method, ForecastMethod.holtWinters);
      expect(m.params, isNotNull);
      final f = m.forecast(14);
      for (var i = 0; i < 14; i++) {
        expect(f[i], closeTo(truth(84 + i), 4), reason: 'day +${i + 1}');
      }
      // Le samedi reste le pic de la semaine prévue.
      final week = f.sublist(0, 7);
      expect(week.indexOf(week.reduce(max)), (5 - 84 % 7) % 7);
    });

    test('noisy data: accurate backtest and wider interval with horizon', () {
      final r = Random(7);
      final y = [for (var t = 0; t < 90; t++) max(0.0, truth(t) + (r.nextDouble() - .5) * 8)];
      final bt = backtest(y);
      expect(bt.days, 7);
      expect(bt.mape!, lessThan(.12));
      expect(bt.wape!, lessThan(.12));
      final m = fitModel(y);
      final i7 = m.interval(7);
      final i30 = m.interval(30);
      expect(i7.high - i7.low, lessThan(i30.high - i30.low));
      expect(i7.low, lessThan(m.forecast(7).reduce((a, b) => a + b)));
    });

    test('short history falls back to a moving average; empty history to none', () {
      final m = fitModel([10, 12, 8, 10, 10]);
      expect(m.method, ForecastMethod.movingAverage);
      expect(m.forecast(7).reduce((a, b) => a + b), closeTo(70, 1e-9));
      expect(fitModel([0, 0, 0]).method, ForecastMethod.none);
      expect(fitModel(const []).forecast(3), [0, 0, 0]);
      expect(backtest([1, 2, 3]).mape, isNull);
    });

    test('forecast is never negative', () {
      final y = [for (var t = 0; t < 42; t++) max(0.0, 60 - 1.5 * t)];
      expect(fitModel(y).forecast(30).every((v) => v >= 0), isTrue);
    });
  });

  group('zones (US-088)', () {
    final now = DateTime(2026, 10, 1, 9);
    const sousse = GeoPoint(35.8256, 10.6084);
    List<VolumeRecord> history(String zone, double scale) => [
      for (var d = 1; d <= 84; d++)
        VolumeRecord(
          zoneId: zone,
          day: DateTime(2026, 10, 1).subtract(Duration(days: d)),
          point: sousse,
          kgByGroup: {
            MaterialGroup.plastic: scale * weekly[(84 - d) % 7],
            if (d.isEven) MaterialGroup.glass: 5,
          },
        ),
    ];

    test('per zone and per group, with accuracy', () {
      final f = computeForecasts(
        [...history('sousse', 1), ...history('monastir', .5)],
        defaultZones,
        now,
      );
      expect(f.keys, unorderedEquals(['sousse', 'monastir']), reason: 'zones without data skipped');
      final s = f['sousse']!;
      expect(s.method, ForecastMethod.holtWinters);
      expect(s.samples, 84);
      expect(s.plastic!.next7, closeTo(weekly.reduce((a, b) => a + b), 15));
      expect(s.plastic!.next30, greaterThan(s.plastic!.next7 * 3.5));
      expect(s.plastic!.last7, closeTo(weekly.reduce((a, b) => a + b), 1e-6));
      expect(s.groups[MaterialGroup.glass]!.next7, closeTo(17.5, 6));
      expect(s.mape, isNotNull);
      expect(
        f['monastir']!.next(7, MaterialGroup.plastic),
        lessThan(s.next(7, MaterialGroup.plastic)),
      );
      final back = ZoneForecast.fromMap('sousse', s.toMap());
      expect(back.plastic!.daily, hasLength(14));
      expect(back.next(30), closeTo(s.next(30), 1e-9));
    });

    test('plastic groups PET, HDPE and PP', () {
      expect(groupFor(RecyclableMaterial.hdpe), MaterialGroup.plastic);
      expect(groupFor(RecyclableMaterial.aluminium), MaterialGroup.metal);
    });
  });

  group('alerts (US-091)', () {
    ZoneForecast z(String id, double next7) => ZoneForecast(
      zoneId: id,
      zoneName: id,
      method: ForecastMethod.holtWinters,
      samples: 60,
      groups: {
        MaterialGroup.plastic: GroupForecast(
          next7: next7,
          next30: next7 * 4,
          low7: 0,
          high7: 0,
          last7: next7,
          last30: 0,
          daily: const [],
        ),
      },
    );

    test('overload, under-collection, balanced', () {
      final alerts = computeAlerts(
        {'a': z('a', 950), 'b': z('b', 100), 'c': z('c', 300), 'd': z('d', 50)},
        {
          'a': (capacity7Kg: 1000.0, requests: 10, unmatched: 0),
          'b': (capacity7Kg: 1000.0, requests: 10, unmatched: 4),
          'c': (capacity7Kg: 1000.0, requests: 10, unmatched: 1),
        },
      );
      expect(
        [for (final a in alerts) (a.zoneId, a.kind)],
        [
          ('a', AlertKind.overload),
          ('b', AlertKind.underCollection),
          ('d', AlertKind.underCollection),
        ],
      );
      expect(alerts.last.capacityKg, 0, reason: 'volume expected, no collector');
    });
  });

  test('heatmap cells aggregate nearby pickups (US-090)', () {
    VolumeRecord at(double lat, double lng, double kg) => VolumeRecord(
      zoneId: 'sousse',
      day: DateTime(2026, 9, 1),
      point: GeoPoint(lat, lng),
      kgByGroup: {MaterialGroup.plastic: kg},
    );
    final cells = heatCells([at(35.8256, 10.6084, 5), at(35.8258, 10.6086, 3), at(35.9, 10.7, 1)]);
    expect(cells, hasLength(2));
    expect(cells.first.kg, 8);
    expect(cells.first.center.lat, closeTo(35.8257, 1e-6));
  });
}
