import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/presentation/widgets/auth_messages.dart';
import '../../../auth/presentation/widgets/error_banner.dart';
import '../../../scan/application/scan_providers.dart';
import '../../application/vision_admin_controllers.dart';
import '../../domain/model_version.dart';
import '../widgets/version_form.dart';

/// Pilotage du modèle de vision (US-019, US-020, seuil US-013).
class ModelScreen extends ConsumerStatefulWidget {
  const ModelScreen({super.key});

  @override
  ConsumerState<ModelScreen> createState() => _ModelScreenState();
}

class _ModelScreenState extends ConsumerState<ModelScreen> {
  double? _threshold;

  String _metric(AppLocalizations l, double? v) =>
      v == null ? l.modelNotMeasured : l.percent((v * 100).round());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final config = ref.watch(visionConfigProvider).value ?? const VisionConfig();
    final versions = ref.watch(modelVersionsProvider).value ?? const [bundledModel];
    final active = ref.watch(activeModelProvider);
    final admin = ref.watch(modelAdminControllerProvider);
    final export = ref.watch(datasetExportControllerProvider);
    final ctrl = ref.read(modelAdminControllerProvider.notifier);
    final threshold = _threshold ?? config.confidenceThreshold;
    final purge = ref.watch(photoPurgeControllerProvider);
    return LayeredPage(
      header: HeroHeader(
        title: l.modelTitle,
        subtitle: l.modelSubtitle,
        emoji: '🧠',
        gradient: EcoGradients.violet,
      ),
      children: [
        EcoCard(
          gradient: EcoGradients.green,
          decorated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ ${l.modelActive}', style: AppTheme.weighted(14, 700, color: Colors.white)),
              Text(active.name, style: AppTheme.weighted(24, 800, color: Colors.white)),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final (label, v) in [
                    (l.modelPrecision, active.precision),
                    (l.modelRecall, active.recall),
                    (l.modelMap, active.map50),
                  ])
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _metric(l, v),
                            style: AppTheme.weighted(20, 800, color: Colors.white),
                          ),
                          Text(
                            label,
                            style: AppTheme.weighted(
                              13,
                              500,
                              color: Colors.white.withValues(alpha: .9),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (active.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  active.notes,
                  style: AppTheme.weighted(13, 500, color: Colors.white.withValues(alpha: .92)),
                ),
              ],
            ],
          ),
        ),
        if (admin.error != null) ErrorBanner(failureText(context, admin.error!)),
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(l.scanThreshold, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  EcoChip(label: l.percent((threshold * 100).round()), tone: ChipTone.sky),
                ],
              ),
              Slider(
                value: threshold,
                min: .05,
                max: .95,
                divisions: 18,
                onChanged: (v) => setState(() => _threshold = v),
              ),
              EcoButton(
                label: l.modelSaveThreshold,
                style: EcoButtonStyle.ghost,
                loading: admin.isLoading,
                onPressed: () async {
                  if (await ctrl.setThreshold(threshold) && context.mounted) {
                    showEcoToast(context, l.modelThresholdSaved);
                  }
                },
              ),
            ],
          ),
        ),
        SectionTitle(l.modelVersions),
        EcoCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              for (final (i, v) in versions.indexed)
                EcoListTile(
                  leading: EcoAvatar(text: v.id == active.id ? '✅' : '🧠'),
                  title: v.name,
                  subtitle:
                      '${l.modelRecall} ${_metric(l, v.recall)} · ${l.modelMap} ${_metric(l, v.map50)}',
                  showDivider: i < versions.length - 1,
                  trailing: v.id == active.id
                      ? EcoChip(label: l.modelActive)
                      : EcoChip(
                          label: l.modelActivate,
                          tone: ChipTone.sky,
                          onTap: () => ctrl.activate(v.id),
                        ),
                ),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (config.previousVersionId != null)
              EcoButton(
                label: l.modelRollback,
                leading: '↩️',
                style: EcoButtonStyle.ghost,
                expand: false,
                onPressed: ctrl.rollback,
              ),
            EcoButton(
              label: l.modelAddVersion,
              leading: '➕',
              style: EcoButtonStyle.ghost,
              expand: false,
              onPressed: () => showVersionForm(context),
            ),
          ],
        ),
        EcoCard(
          gradient: EcoGradients.sky,
          decorated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '📦 ${l.modelExportTitle}',
                style: AppTheme.weighted(18, 800, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(l.modelExportBody, style: AppTheme.weighted(14, 500, color: Colors.white)),
              if (export.error != null) ...[
                const SizedBox(height: 10),
                ErrorBanner(
                  export.error is NothingToExport
                      ? l.modelNothingToExport
                      : failureText(context, export.error!),
                ),
              ],
              const SizedBox(height: 12),
              EcoButton(
                label: l.modelExport,
                style: EcoButtonStyle.ghost,
                loading: export.isLoading,
                onPressed: () async {
                  final c = ref.read(datasetExportControllerProvider.notifier);
                  if (await c.export() && context.mounted) {
                    showEcoToast(context, l.modelExported(c.lastExportCount));
                  }
                },
              ),
            ],
          ),
        ),
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('🗑️ ${l.modelPurge}', style: Theme.of(context).textTheme.titleMedium),
              Text(l.modelPurgeBody, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              EcoButton(
                label: l.modelPurge,
                style: EcoButtonStyle.ghost,
                loading: purge.isLoading,
                onPressed: () async {
                  final c = ref.read(photoPurgeControllerProvider.notifier);
                  if (await c.purge() && context.mounted) {
                    showEcoToast(context, l.modelPurged(c.lastPurged));
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
