import 'package:ecoflow/features/collection/domain/collection_request.dart';
import 'package:ecoflow/features/collection/domain/feedback.dart';
import 'package:ecoflow/features/collection/domain/geo.dart';
import 'package:ecoflow/features/collection/domain/matching.dart';
import 'package:ecoflow/features/collection/domain/recurrence_rules.dart';
import 'package:ecoflow/features/collection/domain/service_zone.dart';
import 'package:ecoflow/features/collection/domain/time_slot.dart';
import 'package:ecoflow/features/collection/presentation/screens/collections_screen.dart';
import 'package:flutter_test/flutter_test.dart';

const sousse = GeoPoint(35.8256, 10.6084);

CollectionRequest req({
  CollectionStatus status = CollectionStatus.searching,
  TimeSlot? slot,
  Recurrence recurrence = Recurrence.none,
}) => CollectionRequest(
  id: 'r',
  citizenUid: 'u',
  estimateCode: 'CODE',
  place: const CollectionPlace(point: sousse, address: 'Rue 1', zoneId: 'sousse'),
  slot: slot ?? TimeSlot(DateTime(2026, 10, 1), 10, 12),
  estimatedKg: 3,
  estimatedDt: 5,
  status: status,
  recurrence: recurrence,
);

void main() {
  group('geo & zones (US-031)', () {
    test('haversine distance and rounding', () {
      expect(distanceKm(sousse, const GeoPoint(35.7643, 10.8113)), closeTo(19.4, .5));
      expect(sousse.rounded(), const GeoPoint(35.83, 10.61));
    });

    test('served zone check', () {
      expect(zoneFor(const GeoPoint(35.83, 10.63), defaultZones)!.id, 'sousse');
      expect(zoneFor(const GeoPoint(33.5, 9.0), defaultZones), isNull, reason: 'desert');
      const inactive = [
        ServiceZone(id: 'x', name: 'X', center: sousse, radiusKm: 5, active: false),
      ];
      expect(zoneFor(sousse, inactive), isNull);
    });
  });

  group('time slots (US-032)', () {
    final now = DateTime(2026, 9, 29, 9, 30);

    test('7 days of slots, starting more than 1 h from now', () {
      final slots = upcomingSlots(now);
      expect(slots.first.id, '2026-09-29_14', reason: '10h slot is only 30 min away');
      expect(slots.last.date, DateTime(2026, 10, 5));
      expect(slots.length, 2 + 6 * 4);
      expect(TimeSlot.fromId(slots.first.id), slots.first);
    });

    test('full slots and alternatives', () {
      final slots = upcomingSlots(now);
      final counts = {slots[1].id: 10, slots[2].id: 3};
      expect(isSlotFull(counts, slots[1], 10), isTrue);
      expect(isSlotFull(counts, slots[2], 10), isFalse);
      expect(freeSlotsAfter(slots, counts, 10, slots[0]).map((s) => s.id), [
        slots[2].id,
        slots[3].id,
        slots[4].id,
      ]);
    });
  });

  group('request lifecycle (US-035)', () {
    final slot = TimeSlot(DateTime(2026, 10, 1), 10, 12);

    test('modifiable until 1 h before, before arrival', () {
      expect(req(slot: slot).canModify(DateTime(2026, 10, 1, 8, 59)), isTrue);
      expect(req(slot: slot).canModify(DateTime(2026, 10, 1, 9, 1)), isFalse);
      expect(
        req(slot: slot, status: CollectionStatus.onTheWay).canModify(DateTime(2026, 9, 30)),
        isFalse,
      );
      expect(
        req(slot: slot, status: CollectionStatus.noCollector).canModify(DateTime(2026, 9, 30)),
        isTrue,
      );
    });

    test('cancellation penalty only after a collector accepted', () {
      expect(req(status: CollectionStatus.proposed).cancellationPenalty, isFalse);
      expect(req(status: CollectionStatus.accepted).cancellationPenalty, isTrue);
      expect(req(status: CollectionStatus.handedOver).canCancel, isFalse);
      expect(req(status: CollectionStatus.completed).canRate, isTrue);
    });
  });

  group('matching (US-034)', () {
    CollectorCandidate c(
      String id,
      double dLat, {
      double cap = 200,
      double rating = 0,
      int n = 0,
      bool online = true,
    }) => CollectorCandidate(
      uid: id,
      point: GeoPoint(sousse.lat + dLat, sousse.lng),
      capacityKg: cap,
      rating: rating,
      ratingCount: n,
      online: online,
    );

    test('5 km first, then widened', () {
      final near = matchCollector(
        pickup: sousse,
        neededKg: 3,
        candidates: [c('far', .12), c('near', .02)],
      );
      expect(near.candidate!.uid, 'near');
      expect(near.radiusKm, 5);
      final widened = matchCollector(pickup: sousse, neededKg: 3, candidates: [c('far', .12)]);
      expect(widened.candidate!.uid, 'far');
      expect(widened.radiusKm, 20);
      expect(matchCollector(pickup: sousse, neededKg: 3, candidates: [c('x', .5)]).found, isFalse);
    });

    test('capacity, availability and exclusions are respected', () {
      final r = matchCollector(
        pickup: sousse,
        neededKg: 50,
        candidates: [
          c('small', .01, cap: 20),
          c('off', .01, online: false),
          c('refused', .01),
          c('ok', .03),
        ],
        excluded: {'refused'},
      );
      expect(r.candidate!.uid, 'ok');
    });

    test('rating breaks near ties', () {
      final r = matchCollector(
        pickup: sousse,
        neededKg: 3,
        candidates: [c('bad', .010, rating: 1, n: 10), c('good', .011, rating: 5, n: 10)],
      );
      expect(r.candidate!.uid, 'good');
    });
  });

  test('recurrence: weekly and monthly, end of month clamped (US-037)', () {
    final s = TimeSlot(DateTime(2026, 1, 31), 8, 10);
    expect(nextOccurrence(s, Recurrence.weekly)!.id, '2026-02-07_08');
    expect(nextOccurrence(s, Recurrence.monthly)!.id, '2026-02-28_08');
    expect(nextOccurrence(s, Recurrence.none), isNull);
  });

  test('rating average (US-040)', () {
    expect(isValidRating(0), isFalse);
    expect(isValidRating(5), isTrue);
    final r = addRating(4, 3, 5);
    expect(r.avg, closeTo(4.25, 1e-9));
    expect(r.count, 4);
  });

  test('history filters by status and date (US-038)', () {
    final now = DateTime(2026, 10, 10);
    final list = [
      req(status: CollectionStatus.completed, slot: TimeSlot(DateTime(2026, 10, 1), 8, 10)),
      req(status: CollectionStatus.cancelled, slot: TimeSlot(DateTime(2026, 8, 1), 8, 10)),
      req(status: CollectionStatus.proposed, slot: TimeSlot(DateTime(2026, 10, 12), 8, 10)),
    ];
    expect(filterCollections(list, StatusFilter.open, last30Days: false, now: now), hasLength(1));
    expect(filterCollections(list, StatusFilter.done, last30Days: false, now: now), hasLength(1));
    expect(filterCollections(list, StatusFilter.all, last30Days: true, now: now), hasLength(2));
  });
}
