import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/domain/verification_status.dart';
import '../../../auth/presentation/widgets/error_banner.dart';
import '../../../scan/application/scan_providers.dart';
import '../../../scan/domain/waste_category.dart';
import '../../../scan/presentation/widgets/scan_labels.dart';
import '../../application/weighing_controller.dart';
import '../../domain/handover_code.dart';
import '../widgets/comparison_table.dart';
import '../widgets/estimation_format.dart';

String weighingErrorText(AppLocalizations l, WeighingError e) => switch (e) {
  WeighingError.invalidCode => l.weighErrInvalidCode,
  WeighingError.notFound => l.weighErrNotFound,
  WeighingError.alreadyWeighed => l.weighErrAlready,
  WeighingError.incomplete => l.weighErrIncomplete,
  WeighingError.notAllowed => l.weighLocked,
  WeighingError.failed => l.weighErrFailed,
};

/// Saisie du poids réel après pesée par le collecteur (US-028).
class WeighingScreen extends ConsumerStatefulWidget {
  const WeighingScreen({super.key});

  @override
  ConsumerState<WeighingScreen> createState() => _WeighingScreenState();
}

class _WeighingScreenState extends ConsumerState<WeighingScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(weighingControllerProvider);
    final ctrl = ref.read(weighingControllerProvider.notifier);
    final catalog = ref.watch(catalogProvider).value ?? defaultCatalog;
    final approved =
        ref.watch(currentProfileProvider).value?.verificationStatus == VerificationStatus.approved;
    final record = s.record;
    return LayeredPage(
      header: HeroHeader(
        title: l.weighTitle,
        subtitle: l.weighSubtitle,
        emoji: '⚖️',
        gradient: EcoGradients.coral,
      ),
      children: [
        if (!approved)
          EcoCard(
            gradient: EcoGradients.sun,
            child: Text(
              '🔒 ${l.weighLocked}',
              style: AppTheme.weighted(15, 600, color: EcoColors.onSun),
            ),
          )
        else if (s.done)
          EcoCard(
            gradient: EcoGradients.green,
            decorated: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.weighDone, style: AppTheme.weighted(17, 700, color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  l.dt(fmtDt(context, s.result!.finalDt)),
                  style: AppTheme.weighted(32, 800, color: Colors.white),
                ),
                const SizedBox(height: 12),
                EcoButton(
                  label: l.weighAnother,
                  style: EcoButtonStyle.ghost,
                  onPressed: () {
                    _code.clear();
                    ctrl.reset();
                  },
                ),
              ],
            ),
          )
        else ...[
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EcoTextField(
                  label: l.weighCodeLabel,
                  emoji: '🔑',
                  controller: _code,
                  enabled: record == null,
                  textInputAction: TextInputAction.search,
                  onSubmitted: ctrl.lookup,
                ),
                const SizedBox(height: 12),
                if (record == null)
                  EcoButton(
                    label: l.weighLookup,
                    leading: '🔍',
                    loading: s.busy,
                    onPressed: () => ctrl.lookup(_code.text),
                  )
                else
                  Center(
                    child: EcoChip(
                      label: '🔑 ${formatHandoverCode(record.code)}',
                      tone: ChipTone.violet,
                    ),
                  ),
              ],
            ),
          ),
          if (s.error != null) ErrorBanner(weighingErrorText(l, s.error!)),
          if (record != null) ...[
            EcoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final line in record.lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          EcoAvatar(text: categoryById(catalog, line.categoryId).emoji, size: 42),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  categoryById(catalog, line.categoryId).name(languageOf(context)),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  '${l.estEstimated} ${l.approxKg(fmtKg(context, line.kg))}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: TextFormField(
                              key: ValueKey('real-${line.categoryId}'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: l.weighRealLabel,
                                isDense: true,
                              ),
                              onChanged: (v) => ctrl.setActual(line.categoryId, parseKg(v)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (s.complete)
              EcoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('📊 ${l.estCompareTitle}', style: Theme.of(context).textTheme.titleMedium),
                    ComparisonTable(result: s.result!, catalog: catalog),
                  ],
                ),
              ),
            EcoButton(
              label: l.weighSubmit,
              leading: '✅',
              style: EcoButtonStyle.green,
              loading: s.busy,
              onPressed: ctrl.submit,
            ),
          ],
        ],
      ],
    );
  }
}
