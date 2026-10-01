import 'package:ecoflow/features/estimation/domain/estimate.dart';
import 'package:ecoflow/features/estimation/domain/estimate_record.dart';
import 'package:ecoflow/features/impact/domain/challenge.dart';
import 'package:ecoflow/features/impact/domain/impact.dart';
import 'package:ecoflow/features/impact/domain/sorting_tips.dart';
import 'package:ecoflow/features/scan/domain/waste_category.dart';
import 'package:ecoflow/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 15);

EstimateRecord weighed(String code, DateTime at, Map<String, double> kg, {double price = .5}) =>
    EstimateRecord(
      code: code,
      citizenUid: 'leila',
      lines: [
        for (final e in kg.entries)
          EstimateLine(
            categoryId: e.key,
            count: 0,
            kg: e.value,
            priceDtPerKg: price,
            method: EstimationMethod.manual,
          ),
      ],
      confidence: .9,
      priceScaleId: 's1',
      status: EstimateStatus.weighed,
      actualKg: kg,
      weighedAt: at,
    );

void main() {
  test('monthly dashboard, trend vs previous month and value (US-118)', () {
    final impact = personalImpact(
      estimates: [
        weighed('A', DateTime(2026, 10, 3), {'pet_bottle': 6, 'can': 2}),
        weighed('B', DateTime(2026, 9, 20), {'cardboard': 4}),
        weighed('C', DateTime(2025, 1, 2), {'glass': 10}),
        EstimateRecord(
          code: 'D',
          citizenUid: 'leila',
          lines: const [],
          confidence: 1,
          priceScaleId: 's1',
          createdAt: DateTime(2026, 10, 1),
        ),
      ],
      entries: [
        LedgerEntry(
          id: 'c_1',
          uid: 'leila',
          type: EntryType.earn,
          points: 90,
          at: DateTime(2026, 10, 3),
        ),
        LedgerEntry(
          id: 'r_1',
          uid: 'leila',
          type: EntryType.redeem,
          points: -50,
          at: DateTime(2026, 10, 4),
        ),
        LedgerEntry(
          id: 'c_2',
          uid: 'leila',
          type: EntryType.earn,
          points: 40,
          status: EntryStatus.held,
          at: DateTime(2026, 10, 5),
        ),
      ],
      catalog: defaultCatalog,
      now: now,
    );
    expect(impact.months.length, 6);
    expect(impact.months.first.month, DateTime(2026, 5));
    expect(impact.current.month, DateTime(2026, 10));
    expect((impact.current.kg, impact.current.collections), (8, 1));
    expect(impact.previous.kg, 4);
    expect(impact.kgTrend, 1, reason: '8 kg vs 4 kg = +100 %');
    expect((impact.totalKg, impact.collections), (22, 3), reason: 'unweighed estimate ignored');
    expect(impact.valueDt, closeTo(22 * .5, 1e-9));
    expect(impact.current.points, 90, reason: 'only credited gains');
    expect(impact.points, 90);
  });

  test('CO₂ per material and telling equivalents (US-119)', () {
    final impact = personalImpact(
      estimates: [
        weighed('A', DateTime(2026, 10, 3), {'pet_bottle': 10, 'can': 1, 'medical': 3}),
      ],
      entries: const [],
      catalog: defaultCatalog,
      now: now,
    );
    expect(impact.co2Kg, closeTo(10 * 1.5 + 1 * 9, 1e-9), reason: 'medical waste excluded');
    expect(impact.co2ByCategory['medical'], 0);
    expect(impact.carKm, closeTo(24 / .193, 1e-6));
    expect(impact.treeYears, closeTo(24 / 25, 1e-9));
    expect(impact.phoneCharges.round(), (24 / .0082).round());
    expect(impact.kgTrend, isNull, reason: 'no previous month');
  });

  test('sorting sheets start with what the citizen recycles most (US-120)', () {
    final order = sheetsFor({'glass': 12, 'can': 3});
    expect(order.take(3), [TipSheet.glass, TipSheet.metal, TipSheet.plastic]);
    expect(order.length, TipSheet.values.length);
    expect(tipItems(' a | b ||c '), ['a', 'b', 'c']);
  });

  group('community challenges (US-121)', () {
    final c = Challenge(
      id: 'ch1',
      title: 'Octobre propre',
      goalKg: 100,
      rewardPoints: 50,
      startAt: DateTime(2026, 10, 1),
      endAt: DateTime(2026, 10, 31),
      totalKg: 40,
      zoneId: 'sousse',
    );

    test('status, progress, deadline and visibility', () {
      expect(c.status(now), ChallengeStatus.active);
      expect(c.status(DateTime(2026, 9, 30)), ChallengeStatus.upcoming);
      expect(c.status(DateTime(2026, 11, 1)), ChallengeStatus.ended);
      expect(c.progress, .4);
      expect(c.daysLeft(now), 16);
      expect(
        [
          c.visibleFor({'sousse'}),
          c.visibleFor({'tunis'}),
        ],
        [true, false],
      );
    });

    test('leaderboards, public names and synced kilos', () {
      final people = [
        Participant(
          uid: 'a',
          name: 'Leila T.',
          zoneId: 'sahloul',
          kg: 12,
          joinedAt: DateTime(2026, 10, 2),
        ),
        Participant(uid: 'b', name: 'Karim B.', zoneId: 'medina', kg: 20),
        Participant(
          uid: 'c',
          name: 'Sami K.',
          zoneId: 'sahloul',
          kg: 12,
          joinedAt: DateTime(2026, 10, 1),
        ),
      ];
      expect([for (final p in leaderboard(people)) p.uid], ['b', 'c', 'a']);
      final zones = zoneRanking(people);
      expect((zones.first.zoneId, zones.first.kg, zones.first.members), ('sahloul', 24, 2));
      expect(publicName('  Leila   ben Trabelsi '), 'Leila T.');
      expect(publicName('Karim'), 'Karim');
      expect(syncedKg(50, 42), 8);
      expect(syncedKg(40, 42), 0);
      expect(challengeEntryId('ch1', 'u1'), 'ch_ch1_u1');
    });

    test('reward only after a successful challenge', () {
      final done = Challenge(
        id: 'ch1',
        title: 'x',
        goalKg: 100,
        rewardPoints: 50,
        startAt: DateTime(2026, 9, 1),
        endAt: DateTime(2026, 9, 30),
        totalKg: 120,
      );
      const me = Participant(uid: 'a', name: 'A', kg: 5);
      expect(canClaim(done, me, now, claimed: false), isTrue);
      expect(canClaim(done, me, now, claimed: true), isFalse);
      expect(canClaim(done, const Participant(uid: 'a', name: 'A'), now, claimed: false), isFalse);
      expect(canClaim(c, me, now, claimed: false), isFalse, reason: 'still running');
      expect(canJoin(c, now, joined: false), isTrue);
      expect(canJoin(done, now, joined: false), isFalse);
    });

    test('admin draft validation', () {
      ChallengeDraftError? v({String t = 'Défi', double? g = 100, int? r = 50, int days = 30}) =>
          validateChallenge(
            title: t,
            goalKg: g,
            rewardPoints: r,
            startAt: now,
            endAt: now.add(Duration(days: days)),
          );
      expect(v(), isNull);
      expect(v(t: ' '), ChallengeDraftError.title);
      expect(v(g: 0), ChallengeDraftError.goal);
      expect(v(r: 5000), ChallengeDraftError.reward);
      expect(v(days: 120), ChallengeDraftError.dates);
    });
  });
}
