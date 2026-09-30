/// Changement de tournée à signaler au collecteur (US-059).
enum TourChange { none, added, removed, reordered }

TourChange diffOrder(List<String> before, List<String> after) {
  final b = before.toSet(), a = after.toSet();
  if (a.difference(b).isNotEmpty) return TourChange.added;
  if (b.difference(a).isNotEmpty) return TourChange.removed;
  for (var i = 0; i < before.length; i++) {
    if (before[i] != after[i]) return TourChange.reordered;
  }
  return TourChange.none;
}
