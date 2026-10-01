import 'package:ecoflow/features/collection/domain/geo.dart';
import 'package:ecoflow/features/collection/domain/service_zone.dart';
import 'package:ecoflow/features/forecast/domain/training_data.dart';
import 'package:ecoflow/features/forecast/domain/zone_forecast.dart';
import 'package:ecoflow/features/scan/domain/waste_category.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime? read(Object? v) => v is DateTime ? v : null;

Map<String, dynamic> col(
  String code, {
  String zone = 'sousse',
  Object? completedAt,
  String? slot,
}) => {
  'estimateCode': code,
  'status': 'completed',
  'completedAt': completedAt,
  'slotId': slot,
  'place': {
    'zoneId': zone,
    'point': {'lat': 35.8, 'lng': 10.6},
  },
};

void main() {
  test('training records shared by the app and the nightly job (US-093)', () {
    final records = volumeRecordsFrom(
      [
        col('A', completedAt: DateTime(2026, 9, 3)),
        col('B', slot: '2026-09-05_10'),
        col('missing'),
      ],
      {
        'A': {
          'actualKg': {'pet_bottle': 4.0, 'can': 1.0, 'glass': 2.0},
        },
        'B': {
          'actualKg': {'cardboard': 3.0},
        },
      },
      defaultCatalog,
      read,
    );
    expect(records, hasLength(2), reason: 'collection without weighing skipped');
    expect(records.first.day, DateTime(2026, 9, 3));
    expect(records.first.kgByGroup, {
      MaterialGroup.plastic: 4.0,
      MaterialGroup.metal: 1.0,
      MaterialGroup.glass: 2.0,
    });
    expect(records.last.day, DateTime(2026, 9, 5), reason: 'falls back to the slot day');
  });

  test('collection supply per zone and run document', () {
    final now = DateTime(2026, 10, 1);
    final recent = [
      {
        'collectorUid': 'k1',
        'createdAt': now.subtract(const Duration(days: 2)),
        'status': 'completed',
        'place': {'zoneId': 'sousse'},
      },
      {
        'createdAt': now.subtract(const Duration(days: 3)),
        'status': 'noCollector',
        'place': {'zoneId': 'sousse'},
      },
      {
        'collectorUid': 'k2',
        'createdAt': now.subtract(const Duration(days: 20)),
        'place': {'zoneId': 'sousse'},
      },
    ];
    const zone = ServiceZone(
      id: 'sousse',
      name: 'Sousse',
      center: GeoPoint(35.8, 10.6),
      radiusKm: 15,
    );
    final s = supplyFrom(recent, {'k1': 300}, [zone], now, read)['sousse']!;
    expect(s.capacity7Kg, 300 * 5 + 200 * 5, reason: 'unknown vehicle counts 200 kg');
    expect((s.requests, s.unmatched), (2, 1), reason: 'only the last 14 days');
    final doc = runDocument(
      forecasts: const {},
      alerts: const [],
      records: 2,
      adminUid: 'admin',
      trigger: 'scheduled',
    );
    expect((doc['trigger'], doc['records']), ('scheduled', 2));
    expect(doc['zones'], isEmpty);
  });
}
