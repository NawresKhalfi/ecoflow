/// Défis communautaires (US-121) : `challenges/{id}` et leurs participants
/// `challenges/{id}/participants/{uid}`.
///
/// Sans serveur, la progression d'un participant est la variation de son
/// compteur `wallets/{uid}.kg` (déjà vérifié par les règles) depuis son
/// inscription : `kg = wallet.kg - baseKg`. Le total du défi évolue dans la
/// même écriture, de la même quantité.
library;

const maxChallengeTitle = 80;
const maxChallengeBody = 300;
const maxChallengeReward = 1000;
const maxChallengeDays = 92;

enum ChallengeStatus { upcoming, active, ended }

class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.goalKg,
    required this.startAt,
    required this.endAt,
    this.description = '',
    this.zoneId,
    this.rewardPoints = 0,
    this.totalKg = 0,
    this.participants = 0,
  });

  final String id;
  final String title;
  final String description;

  /// Ville ou quartier ciblé ; `null` pour un défi national.
  final String? zoneId;
  final double goalKg;
  final int rewardPoints;
  final DateTime startAt;
  final DateTime endAt;
  final double totalKg;
  final int participants;

  ChallengeStatus status(DateTime now) => now.isBefore(startAt)
      ? ChallengeStatus.upcoming
      : now.isAfter(endAt)
      ? ChallengeStatus.ended
      : ChallengeStatus.active;

  double get progress => goalKg <= 0 ? 0 : (totalKg / goalKg).clamp(0, 1).toDouble();
  bool get achieved => totalKg >= goalKg;
  int daysLeft(DateTime now) =>
      endAt.difference(now).inHours <= 0 ? 0 : (endAt.difference(now).inHours / 24).ceil();

  /// Visible si national ou dans une zone où le citoyen fait collecter.
  bool visibleFor(Set<String> myZones) => zoneId == null || myZones.contains(zoneId);

  Map<String, dynamic> toCreateMap() => {
    'title': title,
    'description': description,
    'zoneId': zoneId,
    'goalKg': goalKg,
    'rewardPoints': rewardPoints,
    'startAt': startAt,
    'endAt': endAt,
    'totalKg': 0.0,
    'participants': 0,
    'lastParticipant': null,
  };

  static Challenge fromMap(
    String id,
    Map<String, dynamic> m, {
    required DateTime startAt,
    required DateTime endAt,
  }) => Challenge(
    id: id,
    title: m['title'] as String? ?? '',
    description: m['description'] as String? ?? '',
    zoneId: m['zoneId'] as String?,
    goalKg: (m['goalKg'] as num?)?.toDouble() ?? 0,
    rewardPoints: (m['rewardPoints'] as num?)?.toInt() ?? 0,
    startAt: startAt,
    endAt: endAt,
    totalKg: (m['totalKg'] as num?)?.toDouble() ?? 0,
    participants: (m['participants'] as num?)?.toInt() ?? 0,
  );
}

class Participant {
  const Participant({
    required this.uid,
    required this.name,
    this.zoneId,
    this.baseKg = 0,
    this.kg = 0,
    this.joinedAt,
  });

  final String uid;

  /// Nom public : prénom et initiale (« Leila T. »).
  final String name;
  final String? zoneId;
  final double baseKg;
  final double kg;
  final DateTime? joinedAt;

  static Participant fromMap(String uid, Map<String, dynamic> m, {DateTime? joinedAt}) =>
      Participant(
        uid: uid,
        name: m['name'] as String? ?? '',
        zoneId: m['zoneId'] as String?,
        baseKg: (m['baseKg'] as num?)?.toDouble() ?? 0,
        kg: (m['kg'] as num?)?.toDouble() ?? 0,
        joinedAt: joinedAt,
      );
}

/// Prénom et initiale du nom, pour ne pas exposer l'identité complète.
String publicName(String displayName) {
  final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first;
  return '${parts.first} ${parts.last[0].toUpperCase()}.';
}

/// Kilos à enregistrer pour un participant (jamais négatif).
double syncedKg(double walletKg, double baseKg) => walletKg > baseKg ? walletKg - baseKg : 0;

/// Classement individuel : kilos décroissants, puis ancienneté d'inscription.
List<Participant> leaderboard(Iterable<Participant> all) => [...all]
  ..sort((a, b) {
    final byKg = b.kg.compareTo(a.kg);
    if (byKg != 0) return byKg;
    return (a.joinedAt ?? DateTime(9999)).compareTo(b.joinedAt ?? DateTime(9999));
  });

typedef ZoneScore = ({String? zoneId, double kg, int members});

/// Classement des quartiers / villes d'un défi national.
List<ZoneScore> zoneRanking(Iterable<Participant> all) {
  final by = <String?, ({double kg, int members})>{};
  for (final p in all) {
    final s = by[p.zoneId] ?? (kg: 0.0, members: 0);
    by[p.zoneId] = (kg: s.kg + p.kg, members: s.members + 1);
  }
  return [
    for (final MapEntry(key: z, value: s) in by.entries) (zoneId: z, kg: s.kg, members: s.members),
  ]..sort((a, b) => b.kg.compareTo(a.kg));
}

/// Identifiant du gain de récompense : un seul par défi et par citoyen.
String challengeEntryId(String challengeId, String uid) => 'ch_${challengeId}_$uid';

bool canJoin(Challenge c, DateTime now, {required bool joined}) =>
    !joined && c.status(now) == ChallengeStatus.active;

/// Récompense : défi terminé, objectif collectif atteint, contribution > 0.
bool canClaim(Challenge c, Participant? me, DateTime now, {required bool claimed}) =>
    !claimed &&
    me != null &&
    me.kg > 0 &&
    c.rewardPoints > 0 &&
    c.status(now) == ChallengeStatus.ended &&
    c.achieved;

enum ChallengeDraftError { title, goal, reward, dates }

/// Validation du formulaire administrateur.
ChallengeDraftError? validateChallenge({
  required String title,
  required double? goalKg,
  required int? rewardPoints,
  required DateTime startAt,
  required DateTime endAt,
}) {
  final t = title.trim();
  if (t.isEmpty || t.length > maxChallengeTitle) return ChallengeDraftError.title;
  if (goalKg == null || goalKg <= 0 || goalKg > 1000000) return ChallengeDraftError.goal;
  if (rewardPoints == null || rewardPoints < 0 || rewardPoints > maxChallengeReward) {
    return ChallengeDraftError.reward;
  }
  if (!endAt.isAfter(startAt) || endAt.difference(startAt).inDays > maxChallengeDays) {
    return ChallengeDraftError.dates;
  }
  return null;
}
