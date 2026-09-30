import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../collection/domain/collection_request.dart';
import '../../../estimation/application/estimation_providers.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../profile/data/document_picker.dart';
import '../../../scan/application/scan_providers.dart';
import '../../../scan/data/scan_repository.dart';
import '../../../scan/domain/waste_category.dart';
import '../../../scan/presentation/widgets/scan_labels.dart';
import '../../application/mission_actions_controller.dart';
import '../../application/missions_providers.dart';
import 'mission_labels.dart';
import 'missions_map.dart';

/// Photos du scan du citoyen (US-045).
final scanPhotosProvider = FutureProvider.family<List<StoredPhoto>, String>(
  (ref, scanId) => ref.watch(scanRepositoryProvider).photos(scanId),
);

/// Déchets estimés par l'IA, photos et instructions (US-045).
class WasteSection extends ConsumerWidget {
  const WasteSection({super.key, required this.request});
  final CollectionRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final estimate = ref.watch(estimateByCodeProvider(request.estimateCode)).value;
    final catalog = ref.watch(catalogProvider).value ?? defaultCatalog;
    final photos = estimate?.scanId == null
        ? null
        : ref.watch(scanPhotosProvider(estimate!.scanId!)).value;
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('🧠 ${l.missionWaste}', style: Theme.of(context).textTheme.titleMedium),
          if (estimate != null) ...[
            for (final line in estimate.lines)
              EcoListTile(
                leading: EcoAvatar(text: categoryById(catalog, line.categoryId).emoji, size: 40),
                title: categoryById(catalog, line.categoryId).name(languageOf(context)),
                subtitle:
                    '${line.count} × · ${l.approxKg(fmtKg(context, line.kg))} · ${methodLabel(l, line.method)}',
                trailing: EcoChip(
                  label: l.approxDt(fmtDt(context, line.valueDt)),
                  tone: ChipTone.sun,
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                EcoChip(
                  label: '${l.estReliability} ${l.percent((estimate.confidence * 100).round())}',
                  tone: ChipTone.sky,
                ),
                EcoChip(
                  label: '${l.estTotal} ${l.approxDt(fmtDt(context, estimate.estimate.totalDt))}',
                ),
              ],
            ),
          ],
          if (photos != null && photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(l.missionPhotos, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(photos[i].jpeg, width: 90, height: 90, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
          if (request.instructions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('📝 ${l.missionInstructions}', style: Theme.of(context).textTheme.titleSmall),
            Text(request.instructions),
          ],
        ],
      ),
    );
  }
}

/// Carte et ouverture de l'itinéraire dans Google Maps / Waze / Plans (US-046).
class NavigationSection extends ConsumerWidget {
  const NavigationSection({super.key, required this.request});
  final CollectionRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(myPresenceDataProvider).value?.point;
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('🗺️ ${l.missionNavigate}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          MissionsMap(missions: [request], me: me, height: 220),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (app, label) in [
                (NavApp.googleMaps, l.missionGoogleMaps),
                (NavApp.waze, l.missionWaze),
                (NavApp.appleMaps, l.missionAppleMaps),
              ])
                EcoChip(
                  label: '🧭 $label',
                  tone: ChipTone.sky,
                  onTap: () => openNavigation(app, request.place.point),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Photo preuve obligatoire avant clôture (US-048).
class ProofSection extends ConsumerWidget {
  const ProofSection({super.key, required this.request});
  final CollectionRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final hasProof = ref.watch(hasProofProvider(request.id)).value ?? false;
    final state = ref.watch(missionActionsControllerProvider);
    final ctrl = ref.read(missionActionsControllerProvider.notifier);
    return EcoCard(
      gradient: hasProof ? EcoGradients.green : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hasProof ? l.missionProofOk : '📷 ${l.missionProofTitle}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: hasProof ? Colors.white : null),
          ),
          if (!hasProof) Text(l.missionProofHelp, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              EcoButton(
                label: hasProof ? l.docReplace : l.missionProofTake,
                leading: '📷',
                style: EcoButtonStyle.ghost,
                expand: false,
                loading: state.isLoading,
                onPressed: () => ctrl.takeProof(request, PickSource.camera),
              ),
              EcoLink(
                label: l.docFromGallery,
                onPressed: () => ctrl.takeProof(request, PickSource.gallery),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
