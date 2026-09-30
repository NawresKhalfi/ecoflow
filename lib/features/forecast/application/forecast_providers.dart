import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/router/routes.dart';
import '../../auth/application/action_controller.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/user_role.dart';
import '../../collection/data/collection_support_repositories.dart';
import '../../scan/application/scan_providers.dart';
import '../../scan/domain/waste_category.dart';
import '../../tracking/application/tracking_providers.dart';
import '../data/forecast_repository.dart';
import '../domain/zone_forecast.dart';

final forecastRepositoryProvider = Provider<ForecastRepository>(
  (ref) => ForecastRepository(ref.watch(firestoreProvider)),
);

/// Prévisions publiées, lisibles par les recycleurs et l'administration.
final forecastsProvider = StreamProvider<List<ZoneForecast>>(
  (ref) => ref.watch(forecastRepositoryProvider).watchForecasts(),
);

final forecastRunsProvider = StreamProvider<List<ForecastRun>>(
  (ref) => ref.watch(forecastRepositoryProvider).watchRuns(),
);

/// Collectes pesées (administration) : carte de chaleur (US-090).
final volumeRecordsProvider = FutureProvider.autoDispose<List<VolumeRecord>>(
  (ref) => ref
      .watch(forecastRepositoryProvider)
      .volumeRecords(ref.read(catalogProvider).value ?? defaultCatalog),
);

/// Délai au-delà duquel le modèle est réentraîné automatiquement (US-093).
const retrainAfter = Duration(hours: 24);

/// Entraîne les modèles sur l'historique et publie les prévisions et les
/// alertes (US-088, US-091, US-093). Lectures ponctuelles : un provider non
/// écouté reste en pause.
Future<List<ForecastAlert>> trainAndPublish(Ref ref, {required String trigger}) async {
  final repo = ref.read(forecastRepositoryProvider);
  final now = ref.read(clockProvider)();
  final zones = (await watchCollectionConfig(ref.read(firestoreProvider)).first).zones;
  final records = await repo.volumeRecords(ref.read(catalogProvider).value ?? defaultCatalog);
  final forecasts = computeForecasts(records, zones, now);
  final alerts = computeAlerts(forecasts, await repo.supply(zones, now));
  await repo.publish(
    forecasts: forecasts,
    alerts: alerts,
    records: records.length,
    adminUid: ref.read(currentUidProvider)!,
    trigger: trigger,
  );
  return alerts;
}

class ForecastController extends ActionController {
  List<ForecastAlert> lastAlerts = const [];

  @override
  AsyncValue<void> build() {
    ref.watch(currentUidProvider);
    return super.build();
  }

  Future<bool> retrain() => run(() async {
    lastAlerts = await trainAndPublish(ref, trigger: 'manual');
  });
}

final forecastControllerProvider =
    NotifierProvider.autoDispose<ForecastController, AsyncValue<void>>(ForecastController.new);

/// Réentraînement automatique à l'ouverture de l'espace administrateur si
/// le dernier date de plus de 24 h (pas de tâche planifiée sans serveur).
/// Les alertes du nouvel entraînement sont notifiées (US-091).
bool _autoRunning = false;

final autoRetrainProvider = FutureProvider.autoDispose<void>((ref) async {
  if (ref.watch(sessionProvider).role != UserRole.admin || _autoRunning) return;
  _autoRunning = true;
  try {
    await _autoRetrain(ref);
  } finally {
    _autoRunning = false;
  }
});

Future<void> _autoRetrain(Ref ref) async {
  final runs = await ref.read(forecastRepositoryProvider).watchRuns().first;
  final last = runs.firstOrNull?.at;
  final now = ref.read(clockProvider)();
  if (last != null && now.difference(last) < retrainAfter) return;
  final alerts = await trainAndPublish(ref, trigger: 'auto');
  if (alerts.isEmpty) return;
  final l = lookupAppLocalizations(ref.read(languageControllerProvider).locale);
  await ref
      .read(localNotifierProvider)
      .show(
        9100,
        l.forecastAlertNotice(alerts.length),
        alerts.map((a) => a.zoneName).join(', '),
        payload: Routes.forecastAdmin,
      );
}
