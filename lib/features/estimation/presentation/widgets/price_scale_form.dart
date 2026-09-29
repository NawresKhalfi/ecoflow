import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../profile/domain/company_profile.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../application/estimation_admin_controllers.dart';
import '../../domain/price_scale.dart';
import 'estimation_format.dart';

/// Publication d'un nouveau barème, prérempli avec le barème en vigueur.
Future<void> showPriceScaleForm(BuildContext context, PriceScale current) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _PriceScaleForm(current: current),
      ),
    );

class _PriceScaleForm extends ConsumerStatefulWidget {
  const _PriceScaleForm({required this.current});
  final PriceScale current;

  @override
  ConsumerState<_PriceScaleForm> createState() => _PriceScaleFormState();
}

class _PriceScaleFormState extends ConsumerState<_PriceScaleForm> {
  final _form = GlobalKey<FormState>();
  late final _prices = {
    for (final m in RecyclableMaterial.values)
      m: TextEditingController(text: widget.current.priceOf(m).toString()),
  };
  final _note = TextEditingController();
  DateTime _effective = DateUtils.dateOnly(DateTime.now());

  @override
  void dispose() {
    for (final c in [..._prices.values, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(priceScaleControllerProvider);
    String? price(String? v) => parseKg(v ?? '') == null ? l.errInvalidNumber : null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.pricingNew, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              EcoButton(
                label: '${l.pricingEffective} : ${fmtDate(context, _effective)}',
                leading: '📅',
                style: EcoButtonStyle.ghost,
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _effective,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _effective = d);
                },
              ),
              const SizedBox(height: 12),
              for (final m in RecyclableMaterial.values) ...[
                EcoTextField(
                  label: '${materialLabel(l, m)} (DT/kg)',
                  controller: _prices[m],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: price,
                ),
                const SizedBox(height: 10),
              ],
              EcoTextField(
                label: l.pricingNote,
                controller: _note,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 14),
              EcoButton(
                label: l.pricingNew,
                leading: '📢',
                style: EcoButtonStyle.green,
                loading: state.isLoading,
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  final ok = await ref
                      .read(priceScaleControllerProvider.notifier)
                      .publish(
                        PriceScale(
                          id: '',
                          effectiveFrom: _effective,
                          pricesDtPerKg: {
                            for (final e in _prices.entries) e.key: parseKg(e.value.text)!,
                          },
                          note: _note.text.trim(),
                        ),
                      );
                  if (ok && context.mounted) {
                    showEcoToast(context, l.pricingPublished);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
