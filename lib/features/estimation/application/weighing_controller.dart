import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/domain/verification_status.dart';
import '../domain/estimate_record.dart';
import '../domain/handover_code.dart';
import '../domain/weighing.dart';
import 'estimation_providers.dart';

enum WeighingError { invalidCode, notFound, alreadyWeighed, incomplete, notAllowed, failed }

class WeighingState {
  const WeighingState({
    this.record,
    this.actual = const {},
    this.busy = false,
    this.done = false,
    this.error,
  });

  final EstimateRecord? record;

  /// Poids réels saisis (null = pas encore saisi).
  final Map<String, double?> actual;
  final bool busy;
  final bool done;
  final WeighingError? error;

  bool get complete => record != null && isWeighingComplete(record!.lines, actual);

  WeighingResult? get result => record == null
      ? null
      : compareWeighing(record!.lines, {
          for (final e in actual.entries)
            if (e.value != null) e.key: e.value!,
        });

  WeighingState copyWith({
    EstimateRecord? record,
    Map<String, double?>? actual,
    bool? busy,
    bool? done,
    WeighingError? error,
  }) => WeighingState(
    record: record ?? this.record,
    actual: actual ?? this.actual,
    busy: busy ?? this.busy,
    done: done ?? this.done,
    error: error,
  );
}

/// Saisie du poids réel par le collecteur vérifié (US-028).
class WeighingController extends Notifier<WeighingState> {
  @override
  WeighingState build() => const WeighingState();

  bool get _allowed {
    final p = ref.read(currentProfileProvider).value;
    return p?.role == UserRole.collector && p?.verificationStatus == VerificationStatus.approved;
  }

  Future<void> lookup(String input) async {
    if (!_allowed) {
      state = const WeighingState(error: WeighingError.notAllowed);
      return;
    }
    final code = normalizeHandoverCode(input);
    if (code == null) {
      state = const WeighingState(error: WeighingError.invalidCode);
      return;
    }
    state = const WeighingState(busy: true);
    try {
      final r = await ref.read(estimateRepositoryProvider).fetch(code);
      if (!ref.mounted) return;
      state = switch (r) {
        null => const WeighingState(error: WeighingError.notFound),
        final r when r.isWeighed => const WeighingState(error: WeighingError.alreadyWeighed),
        final r => WeighingState(record: r),
      };
    } catch (_) {
      if (ref.mounted) state = const WeighingState(error: WeighingError.notFound);
    }
  }

  void setActual(String categoryId, double? kg) =>
      state = state.copyWith(actual: {...state.actual, categoryId: kg});

  Future<bool> submit() async {
    final record = state.record;
    final uid = ref.read(currentUidProvider);
    if (record == null || uid == null) return false;
    if (!state.complete) {
      state = state.copyWith(error: WeighingError.incomplete);
      return false;
    }
    state = state.copyWith(busy: true);
    final actual = {for (final l in record.lines) l.categoryId: state.actual[l.categoryId]!};
    try {
      await ref
          .read(estimateRepositoryProvider)
          .submitWeighing(record.code, actual, compareWeighing(record.lines, actual), uid);
      if (ref.mounted) state = state.copyWith(busy: false, done: true);
      return true;
    } catch (_) {
      if (ref.mounted) state = state.copyWith(busy: false, error: WeighingError.failed);
      return false;
    }
  }

  void reset() => state = const WeighingState();
}

final weighingControllerProvider = NotifierProvider.autoDispose<WeighingController, WeighingState>(
  WeighingController.new,
);
