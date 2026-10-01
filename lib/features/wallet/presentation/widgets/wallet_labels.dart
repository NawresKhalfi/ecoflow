import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/l10n.dart';
import '../../domain/gamification.dart';
import '../../domain/points_rules.dart';
import '../../domain/rewards.dart';
import '../../domain/wallet.dart';

String fmtPoints(BuildContext c, int v) =>
    NumberFormat.decimalPattern(Localizations.localeOf(c).languageCode).format(v);

String levelLabel(AppLocalizations l, EcoLevel v) => switch (v) {
  EcoLevel.seed => l.levelSeed,
  EcoLevel.sprout => l.levelSprout,
  EcoLevel.shrub => l.levelShrub,
  EcoLevel.tree => l.levelTree,
  EcoLevel.forest => l.levelForest,
};

String badgeLabel(AppLocalizations l, EcoBadge b) => switch (b) {
  EcoBadge.firstCollection => l.badgeFirstCollection,
  EcoBadge.fiveCollections => l.badgeFiveCollections,
  EcoBadge.twentyCollections => l.badgeTwentyCollections,
  EcoBadge.kg50 => l.badgeKg50,
  EcoBadge.kg200 => l.badgeKg200,
  EcoBadge.glassHero => l.badgeGlassHero,
  EcoBadge.canHero => l.badgeCanHero,
  EcoBadge.eWasteHero => l.badgeEWasteHero,
  EcoBadge.ambassador => l.badgeAmbassador,
  EcoBadge.firstReward => l.badgeFirstReward,
};

String entryTitle(AppLocalizations l, LedgerEntry e) => switch (e.type) {
  EntryType.earn => l.entryEarn,
  EntryType.referral => l.entryReferral,
  EntryType.redeem => e.label ?? l.entryRedeem,
  EntryType.expire => l.entryExpire,
  EntryType.adjust => l.entryAdjust,
  EntryType.challenge => l.entryChallenge(e.label ?? ''),
};

String entryEmoji(LedgerEntry e) => switch (e.type) {
  EntryType.earn => '♻️',
  EntryType.referral => '🤝',
  EntryType.redeem => '🎁',
  EntryType.expire => '⌛',
  EntryType.adjust => '🛠️',
  EntryType.challenge => '🏆',
};

String flagLabel(AppLocalizations l, FraudFlag f) => switch (f) {
  FraudFlag.overweight => l.flagOverweight,
  FraudFlag.estimateGap => l.flagEstimateGap,
  FraudFlag.dailyLimit => l.flagDailyLimit,
};

String rewardKindLabel(AppLocalizations l, RewardKind k) => switch (k) {
  RewardKind.discount => l.rewardKindDiscount,
  RewardKind.product => l.rewardKindProduct,
  RewardKind.donation => l.rewardKindDonation,
};

String refusalLabel(AppLocalizations l, RedeemRefusal r) => switch (r) {
  RedeemRefusal.frozen => l.walletFrozenShort,
  RedeemRefusal.insufficient => l.rewardInsufficient,
  RedeemRefusal.unavailable => l.rewardUnavailable,
};

String couponStatusLabel(AppLocalizations l, RedemptionStatus s) => switch (s) {
  RedemptionStatus.active => l.couponActive,
  RedemptionStatus.used => l.couponUsed,
  RedemptionStatus.cancelled => l.couponCancelled,
};
