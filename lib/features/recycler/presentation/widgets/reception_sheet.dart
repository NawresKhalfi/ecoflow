import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../missions/domain/deposit.dart';
import '../../../profile/domain/company_profile.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../../scan/domain/waste_category.dart';
import '../../application/recycler_providers.dart';
import '../../domain/reception.dart';
import '../../domain/stock.dart';
import 'recycler_labels.dart';

/// Réception d'un dépôt avec contrôle qualité (US-080) : poids pesés par
/// matière (pré-remplis avec les poids déclarés), qualité, indésirables.
Future<bool?> showReceptionSheet(BuildContext context, Deposit d, List<WasteCategory> catalog) =>
    showModalBottomSheet<bool>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: _ReceptionForm(deposit: d, declared: declaredByMaterial(d.byCategoryKg, catalog)),
        ),
      ),
    );

class _ReceptionForm extends ConsumerStatefulWidget {
  const _ReceptionForm({required this.deposit, required this.declared});
  final Deposit deposit;
  final Map<RecyclableMaterial, double> declared;

  @override
  ConsumerState<_ReceptionForm> createState() => _ReceptionFormState();
}

class _ReceptionFormState extends ConsumerState<_ReceptionForm> {
  late final _kg = {
    for (final m in RecyclableMaterial.values)
      m: TextEditingController(
        text: (widget.declared[m] ?? 0) > 0 ? widget.declared[m]!.toStringAsFixed(1) : '',
      ),
  };
  final _note = TextEditingController();
  QualityGrade _grade = QualityGrade.a;
  double _contamination = 0;
  bool _showAll = false;

  @override
  void dispose() {
    for (final c in [..._kg.values, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  double _parse(String s) => double.tryParse(s.replaceAll(',', '.').trim()) ?? 0;

  ReceptionInput get _input => ReceptionInput(
    kgByMaterial: {for (final e in _kg.entries) e.key: _parse(e.value.text)},
    grade: _grade,
    contaminationPct: _contamination,
    note: _note.text,
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(recyclerControllerProvider);
    final declaredKg = widget.declared.values.fold(0.0, (a, b) => a + b);
    final input = _input;
    final gap = receptionGap(declaredKg, input.totalKg);
    final shown = _showAll
        ? RecyclableMaterial.values
        : RecyclableMaterial.values.where(
            (m) => (widget.declared[m] ?? 0) > 0 || _parse(_kg[m]!.text) > 0,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.receiveTitle, style: Theme.of(context).textTheme.titleLarge),
        Text(
          l.receiveDeclared(widget.deposit.collectorName ?? '—', l.kg(fmtKg(context, declaredKg))),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final m in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: EcoTextField(
              label: '${materialEmoji(m)} ${materialLabel(l, m)} (kg)',
              controller: _kg[m],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              helper: (widget.declared[m] ?? 0) > 0
                  ? l.receiveDeclaredKg(fmtKg(context, widget.declared[m]!))
                  : null,
              onChanged: (_) => setState(() {}),
            ),
          ),
        if (!_showAll)
          EcoLink(label: '＋ ${l.receiveSort}', onPressed: () => setState(() => _showAll = true)),
        const SizedBox(height: 8),
        Text(l.receiveGrade, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final g in QualityGrade.values)
              EcoChip(
                label: gradeLabel(l, g),
                selected: _grade == g,
                onTap: () => setState(() => _grade = g),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          l.receiveContamination(_contamination.round()),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Slider(
          value: _contamination,
          max: 50,
          divisions: 50,
          label: '${_contamination.round()} %',
          onChanged: (v) => setState(() => _contamination = v),
        ),
        EcoTextField(label: l.receiveNote, controller: _note, maxLength: 300),
        const SizedBox(height: 8),
        EcoCard(
          child: Text(
            gap.abs() > receptionGapWarning
                ? '⚠️ ${l.receiveGap(l.kg(fmtKg(context, input.totalKg)), (gap * 100).round())}'
                : '✅ ${l.receiveTotal(l.kg(fmtKg(context, input.totalKg)))}',
          ),
        ),
        const SizedBox(height: 8),
        EcoButton(
          label: l.receiveConfirm,
          leading: '📥',
          style: EcoButtonStyle.green,
          loading: state.isLoading,
          onPressed: validateReception(input) != null
              ? null
              : () async {
                  final ok = await ref
                      .read(recyclerControllerProvider.notifier)
                      .receive(widget.deposit, input);
                  if (context.mounted) Navigator.pop(context, ok);
                },
        ),
      ],
    );
  }
}
