import 'dart:math';

import 'package:ecoflow/features/wallet/domain/gamification.dart';
import 'package:ecoflow/features/wallet/domain/points_rules.dart';
import 'package:ecoflow/features/wallet/domain/rewards.dart';
import 'package:ecoflow/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

LedgerEntry credit(int pts, DateTime at, {EntryType type = EntryType.earn}) =>
    LedgerEntry(id: '$at', uid: 'u', type: type, points: pts, at: at);

void main() {
  const rules = PointsRules();

  group('computeAward (US-069, same formula as the Firestore rules)', () {
    test('2.5 kg of cans, first pickup: 2.5 × 2 × 10 + 50', () {
      final a = computeAward(
        rules,
        actualKg: {'can': 2.5},
        actualTotalKg: 2.5,
        estimatedKg: 2,
        firstCollection: true,
        dayCount: 1,
      );
      expect((a.base, a.firstBonus, a.bigDropBonus, a.total), (50, 50, 0, 100));
      expect(a.held, isFalse);
    });

    test('unknown categories use the "other" multiplier; big drop bonus', () {
      final a = computeAward(
        rules.copyWith(multipliers: {...defaultPointsMultipliers, 'other': 2}),
        actualKg: {'textile': 6, 'paper': 4},
        actualTotalKg: 10,
        estimatedKg: 10,
        firstCollection: false,
        dayCount: 1,
      );
      // 4 × 1 + 6 × 2 = 16 kg pondérés → 160 + 20.
      expect(a.total, 180);
    });

    test('anti-fraud flags hold the points (US-075)', () {
      final gap = computeAward(
        rules,
        actualKg: {'glass': 9},
        actualTotalKg: 9,
        estimatedKg: 2,
        firstCollection: true,
        dayCount: 1,
      );
      expect(gap.total, 158);
      expect(gap.flags, [FraudFlag.estimateGap]);
      final many = computeAward(
        rules,
        actualKg: {'can': 300},
        actualTotalKg: 300,
        estimatedKg: 290,
        firstCollection: false,
        dayCount: 4,
      );
      expect(many.flags, [FraudFlag.overweight, FraudFlag.dailyLimit]);
    });

    test('medical waste earns nothing by default, never negative', () {
      final a = computeAward(
        rules,
        actualKg: {'medical': 3},
        actualTotalKg: 3,
        estimatedKg: 3,
        firstCollection: false,
        dayCount: 1,
      );
      expect(a.total, 0);
    });
  });

  test('day counter follows UTC days, like request.time.date()', () {
    final last = DateTime.utc(2026, 10, 1, 23, 30);
    expect(nextDayCount(null, 0, DateTime.utc(2026, 10, 1)), 1);
    expect(nextDayCount(last, 2, DateTime.utc(2026, 10, 1, 23, 50)), 3);
    expect(nextDayCount(last, 2, DateTime.utc(2026, 10, 2, 0, 10)), 1);
  });

  test('rules round-trip through Firestore maps', () {
    final r = rules.copyWith(pointsPerKg: 12, expiryMonths: 6, multipliers: {'can': 3});
    final back = PointsRules.fromMap(r.toMap());
    expect(back.pointsPerKg, 12);
    expect(back.expiryMonths, 6);
    expect(back.multiplier('can'), 3);
    expect(back.multiplier('glass'), 1.2, reason: 'missing keys fall back to defaults');
  });

  group('expiry (US-078)', () {
    final now = DateTime(2027, 6, 1);
    final entries = [
      credit(100, DateTime(2026, 3, 1)),
      credit(50, DateTime(2026, 5, 15)),
      credit(80, DateTime(2027, 1, 1)),
    ];

    test('old points are consumed first by spending (FIFO)', () {
      const w = Wallet(earned: 230, spent: 120);
      // 150 points de plus de 12 mois, dont 120 déjà dépensés → 30 à expirer.
      expect(duePointsToExpire(entries, w, 12, now), 30);
      expect(duePointsToExpire(entries, const Wallet(earned: 230, spent: 200), 12, now), 0);
    });

    test('expiring soon and next expiry date', () {
      const w = Wallet(earned: 230, spent: 100);
      final early = DateTime(2027, 2, 20);
      expect(pointsExpiringSoon(entries, w, 12, early), 0);
      expect(nextExpiry(entries, w, 12), DateTime(2027, 5, 15));
      expect(pointsExpiringSoon(entries, w, 12, DateTime(2027, 4, 20)), 50);
    });
  });

  group('gamification (US-076)', () {
    test('levels and progress', () {
      expect(levelFor(0), EcoLevel.seed);
      expect(levelFor(650), EcoLevel.shrub);
      final p = levelProgress(400);
      expect(p.next, EcoLevel.shrub);
      expect(p.progress, closeTo(.5, 1e-9));
      expect(levelProgress(5000).next, isNull);
    });

    test('badges from wallet and history', () {
      const w = Wallet(earned: 300, collections: 5, kg: 60);
      final entries = [
        LedgerEntry(
          id: 'c_1',
          uid: 'u',
          type: EntryType.earn,
          points: 200,
          byCategory: const {'glass': 25},
        ),
        const LedgerEntry(id: 'r_1', uid: 'u', type: EntryType.redeem, points: -80),
      ];
      expect(earnedBadges(w, entries), {
        EcoBadge.firstCollection,
        EcoBadge.fiveCollections,
        EcoBadge.kg50,
        EcoBadge.glassHero,
        EcoBadge.firstReward,
      });
    });
  });

  group('rewards (US-072, US-073)', () {
    const r = Reward(id: 'r', partnerId: 'p', partnerName: 'P', title: 'T', cost: 100, stock: 1);

    test('redeem refusals', () {
      expect(redeemRefusal(r, 150, frozen: false), isNull);
      expect(redeemRefusal(r, 50, frozen: false), RedeemRefusal.insufficient);
      expect(redeemRefusal(r, 500, frozen: true), RedeemRefusal.frozen);
      const out = Reward(id: 'r', partnerId: 'p', partnerName: 'P', title: 'T', cost: 1, stock: 0);
      expect(redeemRefusal(out, 500, frozen: false), RedeemRefusal.unavailable);
    });

    test('codes are readable and normalised', () {
      final c = randomCode(random: Random(1));
      expect(c, matches(RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}$')));
      expect(c, isNot(matches(RegExp('[01OIL]'))));
      expect(randomCode(length: 6, random: Random(2)), hasLength(6));
      expect(normalizeCode(' abcd-ef23 '), 'ABCDEF23');
    });
  });
}
