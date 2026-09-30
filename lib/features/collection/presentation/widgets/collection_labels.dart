import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/widgets/eco_chip.dart';
import '../../domain/collection_request.dart';
import '../../domain/feedback.dart';
import '../../domain/time_slot.dart';

String statusLabel(AppLocalizations l, CollectionStatus s) => switch (s) {
  CollectionStatus.searching => l.stSearching,
  CollectionStatus.noCollector => l.stNoCollector,
  CollectionStatus.proposed => l.stProposed,
  CollectionStatus.accepted => l.stAccepted,
  CollectionStatus.onTheWay => l.stOnTheWay,
  CollectionStatus.arrived => l.stArrived,
  CollectionStatus.inProgress => l.stInProgress,
  CollectionStatus.handedOver => l.stHandedOver,
  CollectionStatus.completed => l.stCompleted,
  CollectionStatus.cancelled => l.stCancelled,
};

ChipTone statusTone(CollectionStatus s) => switch (s) {
  CollectionStatus.completed => ChipTone.green,
  CollectionStatus.cancelled || CollectionStatus.noCollector => ChipTone.coral,
  CollectionStatus.handedOver => ChipTone.violet,
  CollectionStatus.searching => ChipTone.sun,
  _ => ChipTone.sky,
};

String recurrenceLabel(AppLocalizations l, Recurrence r) => switch (r) {
  Recurrence.none => l.recNone,
  Recurrence.weekly => l.recWeekly,
  Recurrence.monthly => l.recMonthly,
};

String reasonLabel(AppLocalizations l, ProblemReason r) => switch (r) {
  ProblemReason.collectorAbsent => l.reasonAbsent,
  ProblemReason.weightDisputed => l.reasonWeight,
  ProblemReason.behaviour => l.reasonBehaviour,
  ProblemReason.other => l.reasonOther,
};

String dayLabel(BuildContext c, DateTime d) =>
    DateFormat.MMMEd(Localizations.localeOf(c).languageCode).format(d);

String slotLabel(BuildContext c, TimeSlot s) =>
    c.l10n.slotLabel(dayLabel(c, s.date), s.startHour, s.endHour);
