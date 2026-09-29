/// Plage horaire de collecte (US-032).
class TimeSlot {
  const TimeSlot(this.date, this.startHour, this.endHour);

  /// Jour (heure ignorée).
  final DateTime date;
  final int startHour;
  final int endHour;

  DateTime get start => DateTime(date.year, date.month, date.day, startHour);
  DateTime get end => DateTime(date.year, date.month, date.day, endHour);

  /// Identifiant stable : `2026-09-30_08`.
  String get id => '${date.year}-${_pad(date.month)}-${_pad(date.day)}_${_pad(startHour)}';

  static String _pad(int v) => v.toString().padLeft(2, '0');

  static TimeSlot? fromId(String id) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})_(\d{2})$').firstMatch(id);
    if (m == null) return null;
    final start = int.parse(m[4]!);
    final hours = slotHours.where((h) => h.$1 == start).firstOrNull;
    if (hours == null) return null;
    return TimeSlot(
      DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)),
      hours.$1,
      hours.$2,
    );
  }

  @override
  bool operator ==(Object other) => other is TimeSlot && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Créneaux standard de la journée.
const slotHours = [(8, 10), (10, 12), (14, 16), (16, 18)];

/// Délai minimal entre la demande (ou sa modification) et le créneau.
const bookingLead = Duration(hours: 1);

/// Créneaux proposés sur les [days] prochains jours (aujourd'hui inclus),
/// seulement ceux qui commencent dans plus de [bookingLead].
List<TimeSlot> upcomingSlots(DateTime now, {int days = 7}) => [
  for (var d = 0; d < days; d++)
    for (final (s, e) in slotHours)
      if (TimeSlot(
        DateTime(now.year, now.month, now.day + d),
        s,
        e,
      ).start.isAfter(now.add(bookingLead)))
        TimeSlot(DateTime(now.year, now.month, now.day + d), s, e),
];

/// Un créneau est complet quand sa capacité (par zone) est atteinte.
bool isSlotFull(Map<String, int> counts, TimeSlot slot, int capacity) =>
    (counts[slot.id] ?? 0) >= capacity;

/// Alternatives : les prochains créneaux libres après [after] (US-036).
List<TimeSlot> freeSlotsAfter(
  List<TimeSlot> slots,
  Map<String, int> counts,
  int capacity,
  TimeSlot after, {
  int limit = 3,
}) => slots
    .where((s) => s.start.isAfter(after.start) && !isSlotFull(counts, s, capacity))
    .take(limit)
    .toList();
