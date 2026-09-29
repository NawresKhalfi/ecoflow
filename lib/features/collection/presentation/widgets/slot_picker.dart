import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../domain/time_slot.dart';
import 'collection_labels.dart';

/// Choix d'un créneau sur 7 jours ; les créneaux complets sont grisés (US-032).
class SlotPicker extends StatefulWidget {
  const SlotPicker({
    super.key,
    required this.slots,
    required this.counts,
    required this.capacity,
    required this.selected,
    required this.onSelect,
  });

  final List<TimeSlot> slots;
  final Map<String, int> counts;
  final int capacity;
  final TimeSlot? selected;
  final ValueChanged<TimeSlot> onSelect;

  @override
  State<SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends State<SlotPicker> {
  DateTime? _day;

  @override
  Widget build(BuildContext context) {
    final days = <DateTime>[];
    for (final s in widget.slots) {
      if (days.isEmpty || days.last != s.date) days.add(s.date);
    }
    if (days.isEmpty) return const SizedBox.shrink();
    final day = _day ?? widget.selected?.date ?? days.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => Center(
              child: EcoChip(
                label: dayLabel(context, days[i]),
                tone: ChipTone.sky,
                selected: days[i] == day,
                onTap: () => setState(() => _day = days[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in widget.slots.where((s) => s.date == day))
              if (isSlotFull(widget.counts, s, widget.capacity))
                Opacity(
                  opacity: .45,
                  child: EcoChip(
                    label: '${s.startHour}h–${s.endHour}h · ${context.l10n.reqSlotFull}',
                    tone: ChipTone.coral,
                  ),
                )
              else
                EcoChip(
                  label: '${s.startHour}h–${s.endHour}h',
                  selected: widget.selected == s,
                  onTap: () => widget.onSelect(s),
                ),
          ],
        ),
      ],
    );
  }
}
