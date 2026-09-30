import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../profile/domain/company_profile.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../application/recycler_providers.dart';
import '../../domain/analytics.dart';
import '../../domain/stock.dart';
import 'recycler_labels.dart';

Future<bool?> _sheet(BuildContext context, Widget child) => showModalBottomSheet<bool>(
  useRootNavigator: true,
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (c) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
    child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), child: child),
  ),
);

double _parse(String s) => double.tryParse(s.replaceAll(',', '.').trim()) ?? 0;

/// Sortie de stock d'un lot : vente, perte, ajustement (US-081).
Future<bool?> showMoveOutSheet(BuildContext context, StockLot lot) =>
    _sheet(context, _MoveOutForm(lot: lot));

class _MoveOutForm extends ConsumerStatefulWidget {
  const _MoveOutForm({required this.lot});
  final StockLot lot;

  @override
  ConsumerState<_MoveOutForm> createState() => _MoveOutFormState();
}

class _MoveOutFormState extends ConsumerState<_MoveOutForm> {
  final _kg = TextEditingController();
  final _note = TextEditingController();
  MoveReason _reason = MoveReason.sale;

  @override
  void dispose() {
    _kg.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(recyclerControllerProvider);
    final kg = _parse(_kg.text);
    final valid = kg > 0 && kg <= widget.lot.kg + 1e-9;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.moveOutTitle, style: Theme.of(context).textTheme.titleLarge),
        Text(
          '${widget.lot.reference} · ${l.stockAvailable(l.kg(fmtKg(context, widget.lot.kg)))}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final r in [MoveReason.sale, MoveReason.loss, MoveReason.adjust])
              EcoChip(
                label: moveLabel(l, r),
                selected: _reason == r,
                onTap: () => setState(() => _reason = r),
              ),
          ],
        ),
        const SizedBox(height: 12),
        EcoTextField(
          label: l.moveOutKg,
          controller: _kg,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          helper: kg > widget.lot.kg + 1e-9 ? l.stockInsufficient : null,
        ),
        const SizedBox(height: 10),
        EcoTextField(label: l.receiveNote, controller: _note, maxLength: 200),
        const SizedBox(height: 8),
        EcoButton(
          label: l.moveOutConfirm,
          style: EcoButtonStyle.green,
          loading: state.isLoading,
          onPressed: !valid
              ? null
              : () async {
                  final ok = await ref
                      .read(recyclerControllerProvider.notifier)
                      .moveOut(widget.lot, kg, _reason, _note.text.trim());
                  if (context.mounted) Navigator.pop(context, ok);
                },
        ),
      ],
    );
  }
}

/// Déclaration de production de matière recyclée (US-087).
Future<bool?> showProductionSheet(BuildContext context, List<StockLot> lots) =>
    _sheet(context, _ProductionForm(lots: lots));

class _ProductionForm extends ConsumerStatefulWidget {
  const _ProductionForm({required this.lots});
  final List<StockLot> lots;

  @override
  ConsumerState<_ProductionForm> createState() => _ProductionFormState();
}

class _ProductionFormState extends ConsumerState<_ProductionForm> {
  final _input = TextEditingController();
  final _output = TextEditingController();
  late RecyclableMaterial? _material = stockSummary(
    widget.lots.where((l) => l.form == MaterialForm.raw),
  ).keys.firstOrNull;
  MaterialForm _form = MaterialForm.flakes;
  QualityGrade _grade = QualityGrade.a;
  bool _marketplace = true;

  @override
  void dispose() {
    _input.dispose();
    _output.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(recyclerControllerProvider);
    final raw = widget.lots.where((x) => x.form == MaterialForm.raw).toList();
    final summary = stockSummary(raw);
    final available = _material == null ? 0.0 : totalKg(summary[_material] ?? const {});
    final p = _material == null
        ? null
        : ProductionInput(
            material: _material!,
            inputKg: _parse(_input.text),
            form: _form,
            outputKg: _parse(_output.text),
            grade: _grade,
            marketplace: _marketplace,
          );
    final issue = p == null ? ProductionIssue.noInput : validateProduction(p);
    final tooMuch = p != null && p.inputKg > available + 1e-9;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.productionTitle, style: Theme.of(context).textTheme.titleLarge),
        Text(l.productionBody, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        if (summary.isEmpty) Text(l.stockEmpty),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in summary.keys)
              EcoChip(
                label: '${materialEmoji(m)} ${materialLabel(l, m)}',
                selected: _material == m,
                onTap: () => setState(() => _material = m),
              ),
          ],
        ),
        const SizedBox(height: 12),
        EcoTextField(
          label: l.productionInput,
          controller: _input,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          helper: tooMuch ? l.stockInsufficient : l.stockAvailable(l.kg(fmtKg(context, available))),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final f in [MaterialForm.flakes, MaterialForm.granules, MaterialForm.bales])
              EcoChip(
                label: formLabel(l, f),
                selected: _form == f,
                onTap: () => setState(() => _form = f),
              ),
          ],
        ),
        const SizedBox(height: 10),
        EcoTextField(
          label: l.productionOutput,
          controller: _output,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          helper: issue == ProductionIssue.overYield
              ? l.productionOverYield
              : p != null && p.inputKg > 0 && p.outputKg > 0
              ? l.productionYield((p.yieldRatio * 100).round())
              : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _marketplace,
          title: Text(l.lotMarketplace),
          onChanged: (v) => setState(() => _marketplace = v),
        ),
        EcoButton(
          label: l.productionConfirm,
          leading: '🏭',
          style: EcoButtonStyle.green,
          loading: state.isLoading,
          onPressed: issue != null || tooMuch
              ? null
              : () async {
                  final ok = await ref
                      .read(recyclerControllerProvider.notifier)
                      .produce(widget.lots, p!);
                  if (context.mounted) Navigator.pop(context, ok);
                },
        ),
      ],
    );
  }
}
