import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/presentation/widgets/error_banner.dart';
import '../../../profile/data/document_picker.dart';
import '../../application/scan_controller.dart';
import '../../application/scan_providers.dart';
import '../../domain/scan_rules.dart';
import '../../domain/waste_category.dart';
import '../../../estimation/presentation/widgets/estimate_card.dart';
import '../widgets/correction_card.dart';
import '../widgets/photo_stage.dart';
import '../widgets/result_cards.dart';
import '../widgets/scan_labels.dart';

/// Scan des déchets par photo (epic 2).
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  int _selected = 0;

  ScanController get _ctrl => ref.read(scanControllerProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(scanControllerProvider);
    final catalog = ref.watch(catalogProvider).value ?? defaultCatalog;
    final model = ref.watch(activeModelProvider);
    final consent = ref.watch(currentProfileProvider).value?.aiTrainingConsent ?? false;
    final selected = s.photos.isEmpty ? null : _selected.clamp(0, s.photos.length - 1);
    final photo = selected == null ? null : s.photos[selected];
    final visible = s.visible;
    final onPhoto = visible.where((d) => d.photoIndex == selected).toList();
    final issues = {for (final p in s.photos) ...p.issues};
    final estimate = estimateRecyclability(visible, catalog);

    return LayeredPage(
      header: HeroHeader(title: l.scanTitle, subtitle: l.scanSubtitle, emoji: '📸'),
      children: [
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PhotoStage(
                photo: photo,
                detections: s.phase == ScanPhase.result ? onPhoto : const [],
                catalog: catalog,
                scanning: s.phase == ScanPhase.analyzing,
              ),
              if (s.photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Thumbnails(
                  state: s,
                  selected: selected!,
                  onSelect: (i) => setState(() => _selected = i),
                  onRemove: s.phase == ScanPhase.analyzing ? null : _ctrl.removePhoto,
                ),
              ],
              if (s.phase != ScanPhase.result) ...[
                const SizedBox(height: 14),
                ..._actions(context, s),
              ],
            ],
          ),
        ),
        if (s.error != null) ErrorBanner(scanErrorText(l, s.error!)),
        if (issues.isNotEmpty && s.phase != ScanPhase.analyzing)
          QualityAlert(
            messages: [for (final i in issues) issueText(l, i)],
            onRetake: () {
              if (selected != null) _ctrl.removePhoto(selected);
              _ctrl.addPhotos(PickSource.camera);
            },
          ),
        if (s.phase == ScanPhase.result) ...[
          CountsCard(detections: visible, catalog: catalog),
          const EstimateSection(),
          ResponsiveGrid(
            children: [
              if (estimate != null) RecyclabilityCard(estimate: estimate, catalog: catalog),
              ConfidenceCard(
                confidence: averageConfidence(visible),
                threshold: s.threshold,
                onThreshold: _ctrl.setThreshold,
              ),
            ],
          ),
          CorrectionCard(
            detections: visible,
            catalog: catalog,
            onRelabel: _ctrl.relabel,
            onRemove: _ctrl.remove,
            onAdd: (c) => _ctrl.addManual(c, photoIndex: selected ?? 0),
            onSave: s.scanId == null ? null : _ctrl.saveCorrections,
            saving: s.busy,
            saved: s.correctionsSaved,
            consent: consent,
            onConsent: _ctrl.setTrainingConsent,
          ),
          if (s.inferenceMs != null)
            Center(
              child: Text(
                '${s.scanId != null ? '✅ ${l.scanSaved} · ' : ''}'
                '${l.scanMeta((s.inferenceMs! / 1000).toStringAsFixed(1), model.name)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          EcoButton(
            label: l.scanNewScan,
            leading: '🔄',
            style: EcoButtonStyle.ghost,
            onPressed: () {
              setState(() => _selected = 0);
              _ctrl.reset();
            },
          ),
        ],
      ],
    );
  }

  List<Widget> _actions(BuildContext context, ScanState s) {
    final l = context.l10n;
    switch (s.phase) {
      case ScanPhase.analyzing:
        return [
          Text(l.scanAnalyzing, style: Theme.of(context).textTheme.titleMedium),
          Text(l.scanAnalyzingBody, style: Theme.of(context).textTheme.bodySmall),
        ];
      case ScanPhase.result:
        return const [];
      case ScanPhase.empty:
      case ScanPhase.preview:
        return [
          if (s.phase == ScanPhase.empty) ...[
            Text(l.scanEmptyHint, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
          ],
          if (s.phase == ScanPhase.preview) ...[
            EcoButton(
              label: l.scanAnalyze,
              leading: '🔍',
              loading: s.busy,
              onPressed: _ctrl.analyze,
            ),
            const SizedBox(height: 10),
          ],
          _PickButtons(
            camera: EcoButton(
              label: l.scanTakePhoto,
              leading: '📷',
              style: s.phase == ScanPhase.empty ? EcoButtonStyle.green : EcoButtonStyle.ghost,
              onPressed: s.canAddPhotos && !s.busy
                  ? () => _ctrl.addPhotos(PickSource.camera)
                  : null,
            ),
            gallery: EcoButton(
              label: l.scanImport,
              leading: '🖼️',
              style: EcoButtonStyle.ghost,
              onPressed: s.canAddPhotos && !s.busy
                  ? () => _ctrl.addPhotos(PickSource.gallery)
                  : null,
            ),
          ),
        ];
    }
  }
}

class _Thumbnails extends StatelessWidget {
  const _Thumbnails({
    required this.state,
    required this.selected,
    required this.onSelect,
    required this.onRemove,
  });

  final ScanState state;
  final int selected;
  final ValueChanged<int> onSelect;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final p = state.photos[i];
                return Semantics(
                  selected: i == selected,
                  button: true,
                  label: '${i + 1}/${state.photos.length}',
                  child: GestureDetector(
                    onTap: () => onSelect(i),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 76,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: i == selected ? EcoColors.primaryBright : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.memory(p.jpeg, fit: BoxFit.cover, gaplessPlayback: true),
                        ),
                        if (p.issues.isNotEmpty)
                          const Positioned(
                            left: 4,
                            bottom: 4,
                            child: Text('⚠️', style: TextStyle(fontSize: 16)),
                          ),
                        if (onRemove != null)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: IconButton.filled(
                              tooltip: l.scanRemovePhoto,
                              iconSize: 14,
                              visualDensity: VisualDensity.compact,
                              style: IconButton.styleFrom(backgroundColor: EcoColors.coral),
                              onPressed: () => onRemove!(i),
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l.scanPhotoCount(state.photos.length),
            style: AppTheme.weighted(13, 700, color: context.eco.muted),
          ),
        ],
      ),
    );
  }
}

/// Boutons d'import : côte à côte sur grand écran, empilés sur mobile.
class _PickButtons extends StatelessWidget {
  const _PickButtons({required this.camera, required this.gallery});

  final Widget camera;
  final Widget gallery;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => c.maxWidth < 480
        ? Column(children: [camera, const SizedBox(height: 10), gallery])
        : Row(
            children: [
              Expanded(child: camera),
              const SizedBox(width: 10),
              Expanded(child: gallery),
            ],
          ),
  );
}
