import 'collection_request.dart';
import 'time_slot.dart';

/// Prochaine occurrence d'une collecte récurrente (US-037) : même créneau,
/// une semaine ou un mois plus tard (fin de mois ramenée au dernier jour).
TimeSlot? nextOccurrence(TimeSlot slot, Recurrence r) {
  final d = slot.date;
  final next = switch (r) {
    Recurrence.none => null,
    Recurrence.weekly => DateTime(d.year, d.month, d.day + 7),
    Recurrence.monthly => () {
      final lastDay = DateTime(d.year, d.month + 2, 0).day;
      return DateTime(d.year, d.month + 1, d.day > lastDay ? lastDay : d.day);
    }(),
  };
  return next == null ? null : TimeSlot(next, slot.startHour, slot.endHour);
}
