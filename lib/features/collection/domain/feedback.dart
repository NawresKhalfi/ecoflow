/// Motifs de signalement (US-041).
enum ProblemReason { collectorAbsent, weightDisputed, behaviour, other }

const maxCommentLength = 500;
const maxReportPhotos = 3;

/// Note de 1 à 5 (US-040).
bool isValidRating(int stars) => stars >= 1 && stars <= 5;

/// Nouvelle moyenne après une note.
({double avg, int count}) addRating(double avg, int count, int stars) =>
    (avg: (avg * count + stars) / (count + 1), count: count + 1);
