import 'package:ecoflow/features/collection/domain/collection_request.dart';
import 'package:ecoflow/features/collection/domain/geo.dart';
import 'package:ecoflow/features/collection/domain/matching.dart';
import 'package:ecoflow/features/collection/domain/time_slot.dart';
import 'package:ecoflow/features/missions/domain/deposit.dart';
import 'package:ecoflow/features/missions/domain/earnings.dart';
import 'package:ecoflow/features/missions/domain/mission_rules.dart';
import 'package:ecoflow/features/missions/domain/scale_protocol.dart';
import 'package:ecoflow/features/missions/domain/vehicle.dart';
import 'package:ecoflow/features/missions/domain/work_zone.dart';
import 'package:flutter_test/flutter_test.dart';

const sousse = GeoPoint(35.8256, 10.6084);

CollectionRequest req(
  String id, {
  CollectionStatus status = CollectionStatus.searching,
  String? proposedTo,
  DateTime? proposedAt,
  GeoPoint point = sousse,
  double kg = 3,
  double dt = 5,
  List<String> categories = const ['can'],
  List<String> refusedBy = const [],
}) => CollectionRequest(
  id: id,
  citizenUid: 'citizen',
  estimateCode: 'CODE',
  place: CollectionPlace(point: point, address: id, zoneId: 'sousse'),
  slot: TimeSlot(DateTime(2026, 10, 1), 10, 12),
  estimatedKg: kg,
  estimatedDt: dt,
  status: status,
  proposedCollectorUid: proposedTo,
  proposedAt: proposedAt,
  categories: categories,
  refusedBy: refusedBy,
);

void main() {
  final t0 = DateTime(2026, 9, 30, 10);

  group('proposal & acceptance (US-044)', () {
    test('60 s response window', () {
      final r = req('a', status: CollectionStatus.proposed, proposedTo: 'k', proposedAt: t0);
      expect(proposalRemaining(r, t0.add(const Duration(seconds: 15))).inSeconds, 45);
      expect(proposalExpired(r, t0.add(const Duration(seconds: 59))), isFalse);
      expect(proposalExpired(r, t0.add(const Duration(seconds: 60))), isTrue);
    });

    test('who can accept what', () {
      expect(canAccept(req('open'), 'k', t0), isTrue);
      expect(canAccept(req('refused', refusedBy: ['k']), 'k', t0), isFalse);
      final p = req('p', status: CollectionStatus.proposed, proposedTo: 'k', proposedAt: t0);
      expect(canAccept(p, 'k', t0), isTrue);
      expect(canAccept(p, 'other', t0), isFalse);
      expect(canAccept(p, 'k', t0.add(const Duration(minutes: 2))), isFalse, reason: 'expired');
      expect(canAccept(req('taken', status: CollectionStatus.accepted), 'k', t0), isFalse);
      expect(canAccept(req('own'), 'citizen', t0), isFalse);
    });
  });

  test('on-site flow and closing conditions (US-047/048/053)', () {
    expect(nextStep(CollectionStatus.accepted), CollectionStatus.onTheWay);
    expect(nextStep(CollectionStatus.onTheWay), CollectionStatus.arrived);
    expect(nextStep(CollectionStatus.arrived), CollectionStatus.inProgress);
    expect(nextStep(CollectionStatus.inProgress), isNull);
    final inProgress = req('x', status: CollectionStatus.inProgress);
    expect(canClose(inProgress, hasProof: false), isFalse);
    expect(canClose(inProgress, hasProof: true), isTrue);
    expect(canReportNoShow(req('y', status: CollectionStatus.onTheWay)), isFalse);
    expect(canReportNoShow(req('z', status: CollectionStatus.arrived)), isTrue);
  });

  group('mission list (US-043)', () {
    final list = [
      req('near-cheap', point: const GeoPoint(35.83, 10.61), dt: 2, kg: 1),
      req(
        'far-rich',
        point: const GeoPoint(35.90, 10.60),
        dt: 9,
        kg: 12,
        categories: ['pet_bottle'],
      ),
      req('outside', point: const GeoPoint(36.5, 10.7), dt: 20),
    ];
    const zone = WorkZone(center: sousse, radiusKm: 15);

    test('work zone, distance sort and value sort', () {
      final byDistance = selectMissions(
        list,
        filter: const MissionFilter(),
        from: sousse,
        zone: zone,
      );
      expect(byDistance.map((e) => e.$1.id), ['near-cheap', 'far-rich']);
      expect(byDistance.first.$2, lessThan(1));
      final byValue = selectMissions(
        list,
        filter: const MissionFilter(sort: MissionSort.value),
        from: sousse,
        zone: zone,
      );
      expect(byValue.first.$1.id, 'far-rich');
    });

    test('material and quantity filters', () {
      expect(
        selectMissions(
          list,
          filter: const MissionFilter(categories: {'pet_bottle'}),
        ).map((e) => e.$1.id),
        ['far-rich'],
      );
      expect(
        selectMissions(list, filter: const MissionFilter(minKg: 5)).map((e) => e.$1.id),
        containsAll(['far-rich']),
      );
      expect(selectMissions(list, filter: const MissionFilter(maxKg: 2)).map((e) => e.$1.id), [
        'near-cheap',
      ]);
    });

    test('matching ignores collectors whose work zone excludes the pickup (US-042)', () {
      final r = matchCollector(
        pickup: sousse,
        neededKg: 1,
        candidates: const [
          CollectorCandidate(
            uid: 'elsewhere',
            point: GeoPoint(35.83, 10.61),
            capacityKg: 100,
            zoneCenter: GeoPoint(36.8, 10.18),
            zoneRadiusKm: 10,
          ),
          CollectorCandidate(
            uid: 'local',
            point: GeoPoint(35.84, 10.61),
            capacityKg: 100,
            zoneCenter: sousse,
            zoneRadiusKm: 5,
          ),
        ],
      );
      expect(r.candidate!.uid, 'local');
    });
  });

  group('earnings & payouts (US-051/052)', () {
    final e = [
      Earning(missionId: 'a', amountDt: 10, kg: 3, at: DateTime(2026, 9, 30, 9)),
      Earning(missionId: 'b', amountDt: 5, kg: 2, at: DateTime(2026, 9, 29, 9)),
      Earning(missionId: 'c', amountDt: 20, kg: 8, at: DateTime(2026, 9, 2)),
    ];

    test('period totals (week starts Monday)', () {
      expect(periodStart(EarningsPeriod.week, t0), DateTime(2026, 9, 28));
      expect(periodTotals(e, EarningsPeriod.day, t0).dt, 10);
      expect(periodTotals(e, EarningsPeriod.week, t0).missions, 2);
      expect(periodTotals(e, EarningsPeriod.month, t0).kg, 13);
      expect(lastSevenDays(e, t0), [0, 0, 0, 0, 0, 5, 10]);
    });

    test('balance and withdrawal limits', () {
      const payouts = [
        Payout(id: '1', amountDt: 20, method: PayoutMethod.cash, status: PayoutStatus.paid),
        Payout(id: '2', amountDt: 10, method: PayoutMethod.cash, status: PayoutStatus.rejected),
      ];
      final balance = availableBalance(e, payouts);
      expect(balance, 15);
      expect(canWithdraw(balance, 10), isFalse, reason: 'below 20 DT minimum');
      expect(canWithdraw(35, 36), isFalse);
      expect(canWithdraw(35, 20), isTrue);
    });
  });

  test('deposit aggregates real weights by material (US-055)', () {
    expect(
      aggregateByCategory([
        {'can': 1.5, 'pet_bottle': 2},
        {'can': .5},
      ]),
      {'can': 2, 'pet_bottle': 2},
    );
  });

  test('vehicle defaults (US-054)', () {
    expect(Vehicle.defaultFor(VehicleType.van).capacityKg, 600);
    final v = Vehicle.fromMap(
      const Vehicle(type: VehicleType.cargoBike, capacityKg: 70, volumeM3: .4).toMap(),
    )!;
    expect(v.type, VehicleType.cargoBike);
    expect(v.capacityKg, 70);
  });

  test('Bluetooth weight measurement decoding (US-049)', () {
    // 72,5 kg SI : 72,5 / 0,005 = 14500 = 0x38A4 (little-endian A4 38).
    expect(parseWeightMeasurement([0x00, 0xA4, 0x38]), closeTo(72.5, 1e-9));
    // 160 lb impérial : 16000 × 0,01 lb = 72,57 kg.
    expect(parseWeightMeasurement([0x01, 0x80, 0x3E]), closeTo(72.57, .01));
    expect(parseWeightMeasurement([0x00, 0xFF, 0xFF]), isNull, reason: 'measurement unsuccessful');
    expect(parseWeightMeasurement([0x00]), isNull);
  });
}
