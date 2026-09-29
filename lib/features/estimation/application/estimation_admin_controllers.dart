import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/action_controller.dart';
import '../domain/calibration.dart';
import '../domain/estimation_coefficients.dart';
import '../domain/price_scale.dart';
import 'estimation_providers.dart';

/// Publication d'un barème avec date d'effet (US-027).
class PriceScaleController extends ActionController {
  Future<bool> publish(PriceScale scale) =>
      run(() => ref.read(priceScaleRepositoryProvider).publish(scale));
}

final priceScaleControllerProvider =
    NotifierProvider.autoDispose<PriceScaleController, AsyncValue<void>>(PriceScaleController.new);

/// Recalibrage des coefficients à partir des pesées (US-030).
class CalibrationController extends ActionController {
  CalibrationReport? report;

  Future<bool> analyze() => run(() async {
    final records = await ref.read(estimateRepositoryProvider).weighed();
    final current = ref.read(coefficientsProvider).value ?? defaultCoefficients;
    report = calibrate([for (final r in records) r.weighing!], current);
  });

  Future<bool> apply() => run(() async {
    final r = report;
    if (r == null) return;
    final current = ref.read(coefficientsProvider).value ?? defaultCoefficients;
    await ref.read(coefficientsRepositoryProvider).save(r.proposed, current);
  });
}

final calibrationControllerProvider =
    NotifierProvider.autoDispose<CalibrationController, AsyncValue<void>>(
      CalibrationController.new,
    );
