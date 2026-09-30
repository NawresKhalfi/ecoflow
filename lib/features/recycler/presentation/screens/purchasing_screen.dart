import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../profile/domain/company_profile.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../application/recycler_providers.dart';
import '../../domain/purchasing.dart';
import '../widgets/recycler_labels.dart';

/// Capacités et prix d'achat par matière, vus par les collecteurs (US-085).
class PurchasingScreen extends ConsumerStatefulWidget {
  const PurchasingScreen({super.key});

  @override
  ConsumerState<PurchasingScreen> createState() => _PurchasingScreenState();
}

class _PurchasingScreenState extends ConsumerState<PurchasingScreen> {
  Purchasing? _draft;
  final _price = <RecyclableMaterial, TextEditingController>{};
  final _cap = <RecyclableMaterial, TextEditingController>{};

  @override
  void dispose() {
    for (final c in [..._price.values, ..._cap.values]) {
      c.dispose();
    }
    super.dispose();
  }

  double _parse(String s) => double.tryParse(s.replaceAll(',', '.').trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final saved = ref.watch(myPurchasingProvider).value;
    final state = ref.watch(recyclerControllerProvider);
    if (saved != null && _draft == null) {
      _draft = {
        for (final m in RecyclableMaterial.values)
          m: saved[m] ?? const MaterialOffer(accepting: false),
      };
      for (final m in RecyclableMaterial.values) {
        final o = _draft![m]!;
        _price[m] = TextEditingController(text: o.priceDtPerKg == 0 ? '' : '${o.priceDtPerKg}');
        _cap[m] = TextEditingController(
          text: o.capacityKgMonth == 0 ? '' : o.capacityKgMonth.round().toString(),
        );
      }
    }
    final draft = _draft;
    return LayeredPage(
      header: HeroHeader(
        title: l.purchasingTitle,
        subtitle: l.purchasingSubtitle,
        emoji: '💱',
        gradient: EcoGradients.sun,
      ),
      children: [
        if (draft == null) const Center(child: CircularProgressIndicator()),
        if (draft != null)
          for (final m in RecyclableMaterial.values)
            EcoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: draft[m]!.accepting,
                    title: Text('${materialEmoji(m)} ${materialLabel(l, m)}'),
                    subtitle: Text(
                      draft[m]!.accepting ? l.purchasingAccepting : l.purchasingRefusing,
                    ),
                    onChanged: (v) => setState(() => draft[m] = draft[m]!.copyWith(accepting: v)),
                  ),
                  if (draft[m]!.accepting)
                    Row(
                      children: [
                        Expanded(
                          child: EcoTextField(
                            label: l.purchasingPrice,
                            controller: _price[m],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: EcoTextField(
                            label: l.purchasingCapacity,
                            controller: _cap[m],
                            keyboardType: TextInputType.number,
                            helper: l.purchasingCapacityHelp,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        if (draft != null)
          EcoButton(
            label: l.commonSave,
            style: EcoButtonStyle.green,
            loading: state.isLoading,
            onPressed: () async {
              final p = {
                for (final m in RecyclableMaterial.values)
                  m: draft[m]!.copyWith(
                    priceDtPerKg: _parse(_price[m]!.text),
                    capacityKgMonth: _parse(_cap[m]!.text),
                  ),
              };
              final ok = await ref.read(recyclerControllerProvider.notifier).savePurchasing(p);
              if (context.mounted) showEcoToast(context, ok ? l.purchasingSaved : l.errSaveFailed);
            },
          ),
      ],
    );
  }
}
