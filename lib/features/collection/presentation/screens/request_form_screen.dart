import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/presentation/widgets/error_banner.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../profile/application/profile_providers.dart';
import '../../../profile/data/document_picker.dart';
import '../../application/collection_providers.dart';
import '../../application/request_form_controller.dart';
import '../../domain/collection_request.dart';
import '../../domain/time_slot.dart';
import '../widgets/collection_labels.dart';
import '../widgets/location_picker.dart';
import '../widgets/slot_picker.dart';

String requestErrorText(AppLocalizations l, RequestFormError e) => switch (e) {
  RequestFormError.outOfZone => l.reqErrOutOfZone,
  RequestFormError.noLocation => l.reqErrNoLocation,
  RequestFormError.noSlot => l.reqErrNoSlot,
  RequestFormError.slotFull => l.reqErrSlotFull,
  RequestFormError.tooLong => l.reqErrTooLong,
  RequestFormError.photoTooLarge => l.docTooLarge,
  RequestFormError.estimateUnavailable => l.reqErrEstimate,
  RequestFormError.failed => l.reqErrFailed,
};

/// Demande de collecte à partir d'une estimation (US-031 à US-033, US-037).
class RequestFormScreen extends ConsumerStatefulWidget {
  const RequestFormScreen({super.key, required this.estimateCode});
  final String estimateCode;

  @override
  ConsumerState<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends ConsumerState<RequestFormScreen> {
  late final _address = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(requestFormControllerProvider.notifier).load(widget.estimateCode),
    );
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(requestFormControllerProvider);
    final ctrl = ref.read(requestFormControllerProvider.notifier);
    final config = ref.watch(collectionConfigProvider).value;
    final zone = ctrl.zone;
    final counts = zone == null
        ? const <String, int>{}
        : (ref.watch(slotCountsProvider(zone.id)).value ?? const {});
    final slots = upcomingSlots(ref.watch(clockProvider)());
    final saved = (ref.watch(addressesProvider).value ?? const [])
        .where((a) => a.hasPosition)
        .toList();
    ref.listen(requestFormControllerProvider.select((v) => v.address), (_, a) {
      if (_address.text != a) _address.text = a;
    });
    final estimate = s.estimate;
    return LayeredPage(
      header: HeroHeader(
        title: l.reqTitle,
        subtitle: l.reqSubtitle,
        emoji: '🚚',
        gradient: EcoGradients.coral,
        leading: IconButton.filledTonal(
          tooltip: l.commonBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .22),
            foregroundColor: Colors.white,
          ),
          onPressed: () => context.go(Routes.estimates),
          icon: const BackButtonIcon(),
        ),
      ),
      children: [
        if (estimate == null && s.error == null) const Center(child: CircularProgressIndicator()),
        if (estimate == null && s.error != null) ErrorBanner(requestErrorText(l, s.error!)),
        if (estimate != null) ...[
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.reqLocation, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    EcoChip(
                      label: '🛰️ ${l.reqUseGps}',
                      selected: s.mode == LocationMode.gps,
                      onTap: s.locating ? null : ctrl.useGps,
                    ),
                    for (final a in saved)
                      EcoChip(
                        label: '🏠 ${a.label}',
                        selected: s.mode == LocationMode.saved && s.address.startsWith(a.street),
                        onTap: () => ctrl.useSavedAddress(a),
                      ),
                    EcoChip(
                      label: '🗺️ ${l.reqMap}',
                      selected: s.mode == LocationMode.map,
                      tone: ChipTone.sky,
                    ),
                  ],
                ),
                if (saved.isEmpty) ...[
                  const SizedBox(height: 4),
                  Text(l.reqNoSavedAddress, style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 10),
                PinMap(
                  point: s.point,
                  onMoved: (p) => ctrl.setPoint(p, mode: LocationMode.map),
                ),
                const SizedBox(height: 6),
                Text(l.reqMapHint, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),
                EcoTextField(
                  label: l.reqAddressLabel,
                  emoji: '🏠',
                  controller: _address,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ZoneChip(zone: zone, hasPoint: s.point != null),
                ),
              ],
            ),
          ),
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.reqSlot, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                SlotPicker(
                  slots: slots,
                  counts: counts,
                  capacity: config?.slotCapacity ?? 10,
                  selected: s.slot,
                  onSelect: ctrl.setSlot,
                ),
              ],
            ),
          ),
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.reqInstructions, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: s.instructions,
                  maxLength: maxInstructionsLength,
                  maxLines: 3,
                  decoration: InputDecoration(hintText: l.reqInstructionsHint),
                  onChanged: ctrl.setInstructions,
                ),
                if (s.photo != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(s.photo!, height: 120, fit: BoxFit.cover),
                  ),
                  EcoLink(label: l.reqRemovePhoto, onPressed: ctrl.removePhoto),
                ] else
                  Wrap(
                    spacing: 8,
                    children: [
                      EcoChip(
                        label: '📷 ${l.docTakePhoto}',
                        onTap: () => ctrl.pickPhoto(PickSource.camera),
                      ),
                      EcoChip(
                        label: '🖼️ ${l.docFromGallery}',
                        onTap: () => ctrl.pickPhoto(PickSource.gallery),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.reqRecurrence, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in Recurrence.values)
                      EcoChip(
                        label: recurrenceLabel(l, r),
                        selected: s.recurrence == r,
                        onTap: () => ctrl.setRecurrence(r),
                      ),
                  ],
                ),
              ],
            ),
          ),
          EcoCard(
            gradient: EcoGradients.violet,
            decorated: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🧾 ${l.estTotal}', style: AppTheme.weighted(14, 700, color: Colors.white)),
                Text(
                  '${l.approxKg(fmtKg(context, estimate.estimate.totalKg))} · ${l.approxDt(fmtDt(context, estimate.estimate.totalDt))}',
                  style: AppTheme.weighted(24, 800, color: Colors.white),
                ),
                if (s.slot != null)
                  Text(
                    slotLabel(context, s.slot!),
                    style: AppTheme.weighted(15, 600, color: Colors.white),
                  ),
              ],
            ),
          ),
          if (s.error != null) ErrorBanner(requestErrorText(l, s.error!)),
          EcoButton(
            label: l.reqConfirm,
            leading: '🚚',
            loading: s.submitting,
            onPressed: () async {
              ctrl.setAddress(_address.text);
              final id = await ctrl.submit();
              if (id != null && context.mounted) context.go(Routes.collectionDetail(id));
            },
          ),
        ],
      ],
    );
  }
}
