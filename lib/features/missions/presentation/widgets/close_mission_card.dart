import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/presentation/widgets/auth_messages.dart';
import '../../../auth/presentation/widgets/error_banner.dart';
import '../../../collection/domain/collection_request.dart';
import '../../../estimation/application/estimation_providers.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../scan/application/scan_providers.dart';
import '../../../scan/domain/waste_category.dart';
import '../../../scan/presentation/widgets/scan_labels.dart';
import '../../application/collector_controllers.dart';
import '../../application/mission_actions_controller.dart';
import '../../application/missions_providers.dart';

String closeErrorText(BuildContext context, Object e) {
  final l = context.l10n;
  return switch (e) {
    WrongHandoverCode() => l.missionErrCode,
    ProofRequired() => l.missionErrProof,
    WeightsIncomplete() => l.missionErrWeights,
    _ => failureText(context, e),
  };
}

/// Clôture : code du citoyen (sa validation) + poids réels (US-028, US-050),
/// avec lecture possible d'une balance Bluetooth (US-049).
class CloseMissionCard extends ConsumerStatefulWidget {
  const CloseMissionCard({super.key, required this.request});
  final CollectionRequest request;

  @override
  ConsumerState<CloseMissionCard> createState() => _CloseMissionCardState();
}

class _CloseMissionCardState extends ConsumerState<CloseMissionCard> {
  final _code = TextEditingController();
  final _weights = <String, TextEditingController>{};

  TextEditingController _field(String id) => _weights.putIfAbsent(id, TextEditingController.new);

  @override
  void dispose() {
    _code.dispose();
    for (final c in _weights.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final estimate = ref.watch(estimateByCodeProvider(widget.request.estimateCode)).value;
    final catalog = ref.watch(catalogProvider).value ?? defaultCatalog;
    final hasProof = ref.watch(hasProofProvider(widget.request.id)).value ?? false;
    final state = ref.watch(missionActionsControllerProvider);
    final scale = ref.watch(scaleControllerProvider);
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('✅ ${l.missionCloseTitle}', style: Theme.of(context).textTheme.titleMedium),
          Text(l.missionCloseHelp, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          EcoTextField(label: l.missionCodeLabel, emoji: '🔑', controller: _code),
          const SizedBox(height: 10),
          for (final line in estimate?.lines ?? const [])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  EcoAvatar(text: categoryById(catalog, line.categoryId).emoji, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${categoryById(catalog, line.categoryId).name(languageOf(context))}\n'
                      '${l.estEstimated} ${l.approxKg(fmtKg(context, line.kg))}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _field(line.categoryId),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l.weighRealLabel, isDense: true),
                    ),
                  ),
                  if (scale.kg != null)
                    IconButton(
                      tooltip: l.scaleUse,
                      icon: const Icon(Icons.download_rounded),
                      onPressed: () => _field(line.categoryId).text = scale.kg!.toStringAsFixed(2),
                    ),
                ],
              ),
            ),
          _ScaleRow(state: scale),
          if (state.error != null) ...[
            const SizedBox(height: 8),
            ErrorBanner(closeErrorText(context, state.error!)),
          ],
          const SizedBox(height: 12),
          EcoButton(
            label: l.missionClose,
            leading: '✅',
            style: EcoButtonStyle.green,
            loading: state.isLoading,
            onPressed: () => ref
                .read(missionActionsControllerProvider.notifier)
                .close(
                  widget.request,
                  code: _code.text,
                  actualKg: {for (final e in _weights.entries) e.key: parseKg(e.value.text)},
                  hasProof: hasProof,
                ),
          ),
        ],
      ),
    );
  }
}

class _ScaleRow extends ConsumerWidget {
  const _ScaleRow({required this.state});
  final ScaleState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ctrl = ref.read(scaleControllerProvider.notifier);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        EcoChip(label: '⚖️ ${l.scaleConnect}', tone: ChipTone.sky, onTap: ctrl.scan),
        if (state.scanning && state.devices.isEmpty)
          Text(l.scaleScanning, style: Theme.of(context).textTheme.bodySmall),
        if (!state.scanning &&
            state.devices.isEmpty &&
            state.connectedId == null &&
            state.error != null)
          Text(l.scaleNone, style: Theme.of(context).textTheme.bodySmall),
        for (final d in state.devices)
          EcoChip(
            label: '🔗 ${d.name}',
            selected: d.id == state.connectedId,
            onTap: () => ctrl.connect(d.id),
          ),
        if (state.kg != null) EcoChip(label: l.kg(fmtKg(context, state.kg!)), tone: ChipTone.green),
      ],
    );
  }
}
