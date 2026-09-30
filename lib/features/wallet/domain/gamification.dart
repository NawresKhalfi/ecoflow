import 'wallet.dart';

/// Niveaux du citoyen selon les points gagnés au total (US-076).
enum EcoLevel {
  seed(0, '🌱'),
  sprout(200, '🌿'),
  shrub(600, '🪴'),
  tree(1500, '🌳'),
  forest(4000, '🏞️');

  const EcoLevel(this.minPoints, this.emoji);
  final int minPoints;
  final String emoji;
}

EcoLevel levelFor(int earned) => EcoLevel.values.lastWhere((l) => earned >= l.minPoints);

/// Progression vers le niveau suivant : (niveau suivant, fraction 0–1).
({EcoLevel? next, double progress}) levelProgress(int earned) {
  final current = levelFor(earned);
  final i = EcoLevel.values.indexOf(current);
  if (i == EcoLevel.values.length - 1) return (next: null, progress: 1);
  final next = EcoLevel.values[i + 1];
  final span = next.minPoints - current.minPoints;
  return (next: next, progress: (earned - current.minPoints) / span);
}

enum EcoBadge {
  firstCollection('🎉'),
  fiveCollections('🖐️'),
  twentyCollections('🏆'),
  kg50('💪'),
  kg200('🦾'),
  glassHero('🍾'),
  canHero('🥫'),
  eWasteHero('🔌'),
  ambassador('🤝'),
  firstReward('🎁');

  const EcoBadge(this.emoji);
  final String emoji;
}

/// Badges obtenus, calculés à partir du portefeuille et de l'historique.
Set<EcoBadge> earnedBadges(Wallet w, List<LedgerEntry> entries) {
  double kgOf(String id) => entries
      .where((e) => e.type == EntryType.earn && e.status != EntryStatus.rejected)
      .fold(0.0, (s, e) => s + (e.byCategory[id] ?? 0));
  return {
    if (w.collections >= 1) EcoBadge.firstCollection,
    if (w.collections >= 5) EcoBadge.fiveCollections,
    if (w.collections >= 20) EcoBadge.twentyCollections,
    if (w.kg >= 50) EcoBadge.kg50,
    if (w.kg >= 200) EcoBadge.kg200,
    if (kgOf('glass') >= 20) EcoBadge.glassHero,
    if (kgOf('can') >= 10) EcoBadge.canHero,
    if (kgOf('e_waste') >= 5) EcoBadge.eWasteHero,
    if (entries.any((e) => e.type == EntryType.referral && e.isCredit)) EcoBadge.ambassador,
    if (entries.any((e) => e.type == EntryType.redeem)) EcoBadge.firstReward,
  };
}
