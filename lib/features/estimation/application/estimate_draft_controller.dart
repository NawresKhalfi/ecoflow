import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../auth/application/auth_providers.dart';
import '../../scan/application/scan_controller.dart';
import '../../scan/application/scan_providers.dart';
import '../../scan/domain/waste_category.dart';
import '../domain/estimate.dart';
import '../domain/estimate_record.dart';
import '../domain/estimation_coefficients.dart';
import 'estimation_providers.dart';

class EstimateDraft {
  const EstimateDraft({
    this.container,
    this.manualKg = const {},
    this.confirmed = false,
    this.savedCode,
    this.saving = false,
    this.error,
  });

  final WasteContainer? container;
  final Map<String, double> manualKg;

  /// L'utilisateur confirme une estimation peu fiable (US-025).
  final bool confirmed;
  final String? savedCode;
  final bool saving;
  final Object? error;

  EstimateDraft copyWith({
    WasteContainer? container,
    bool clearContainer = false,
    Map<String, double>? manualKg,
    bool? confirmed,
    String? savedCode,
    bool? saving,
    Object? error,
  }) => EstimateDraft(
    container: clearContainer ? null : (container ?? this.container),
    manualKg: manualKg ?? this.manualKg,
    confirmed: confirmed ?? this.confirmed,
    savedCode: savedCode ?? this.savedCode,
    saving: saving ?? this.saving,
    error: error,
  );
}

/// Réglages de l'estimation du scan en cours : contenant, poids manuels,
/// confirmation et enregistrement (US-023 à US-026).
class EstimateDraftController extends Notifier<EstimateDraft> {
  @override
  EstimateDraft build() {
    // Nouveau scan → nouvelle estimation.
    ref.listen(scanControllerProvider.select((s) => s.phase), (prev, next) {
      if (next != ScanPhase.result) state = const EstimateDraft();
    });
    return const EstimateDraft();
  }

  void setContainer(WasteContainer? c) => state = c == null
      ? state.copyWith(clearContainer: true, confirmed: false)
      : state.copyWith(container: c, confirmed: false);

  /// [kg] nul ou vide : retour à l'estimation automatique.
  void setManualKg(String categoryId, double? kg) {
    final next = {...state.manualKg};
    if (kg == null || kg <= 0) {
      next.remove(categoryId);
    } else {
      next[categoryId] = kg;
    }
    state = state.copyWith(manualKg: next, confirmed: false);
  }

  void confirm() => state = state.copyWith(confirmed: true);

  /// Enregistre l'estimation et renvoie le code de pesée.
  Future<String?> save() async {
    final estimate = _estimateFrom(ref.read, state);
    final uid = ref.read(currentUidProvider);
    if (estimate == null || estimate.isEmpty || uid == null) return null;
    if (estimate.needsConfirmation && !state.confirmed) return null;
    state = state.copyWith(saving: true);
    try {
      final code = await ref
          .read(estimateRepositoryProvider)
          .create(
            EstimateRecord(
              code: '',
              citizenUid: uid,
              scanId: ref.read(scanControllerProvider).scanId,
              lines: estimate.lines,
              confidence: estimate.confidence,
              priceScaleId: estimate.priceScaleId,
              container: state.container,
            ),
          );
      if (ref.mounted) state = state.copyWith(savedCode: code, saving: false);
      return code;
    } catch (e) {
      debugPrint('EstimateDraft.save failed: $e');
      if (ref.mounted) state = state.copyWith(saving: false, error: e);
      return null;
    }
  }
}

final estimateDraftControllerProvider = NotifierProvider<EstimateDraftController, EstimateDraft>(
  EstimateDraftController.new,
);

/// Calcul commun au provider (qui observe) et à l'enregistrement (qui lit),
/// sans que le controller dépende de [draftEstimateProvider] (cycle).
Estimate? _estimateFrom(T Function<T>(ProviderListenable<T>) read, EstimateDraft draft) {
  final scan = read(scanControllerProvider);
  if (scan.phase != ScanPhase.result) return null;
  return estimateScan(
    detections: scan.visible,
    catalog: read(catalogProvider).value ?? defaultCatalog,
    prices: read(activePriceScaleProvider),
    coefficients: read(coefficientsProvider).value ?? defaultCoefficients,
    container: draft.container,
    manualKg: draft.manualKg,
  );
}

/// Estimation recalculée instantanément à chaque changement (US-026).
final draftEstimateProvider = Provider<Estimate?>(
  (ref) => _estimateFrom(ref.watch, ref.watch(estimateDraftControllerProvider)),
);
