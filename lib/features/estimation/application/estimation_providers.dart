import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/estimation_repositories.dart';
import '../domain/estimate_record.dart';
import '../domain/estimation_coefficients.dart';
import '../domain/price_scale.dart';

final priceScaleRepositoryProvider = Provider<PriceScaleRepository>(
  (ref) => FirestorePriceScaleRepository(ref.watch(firestoreProvider)),
);
final coefficientsRepositoryProvider = Provider<CoefficientsRepository>(
  (ref) => FirestoreCoefficientsRepository(ref.watch(firestoreProvider)),
);
final estimateRepositoryProvider = Provider<EstimateRepository>(
  (ref) => FirestoreEstimateRepository(ref.watch(firestoreProvider)),
);

final priceScalesProvider = StreamProvider<List<PriceScale>>(
  (ref) => ref.watch(priceScaleRepositoryProvider).watch(),
);

/// Barème en vigueur maintenant (appliqué au moment de la demande).
final activePriceScaleProvider = Provider<PriceScale>(
  (ref) =>
      activeScaleAt(ref.watch(priceScalesProvider).value ?? const [], ref.watch(clockProvider)()),
);

final coefficientsProvider = StreamProvider<EstimationCoefficients>(
  (ref) => ref.watch(coefficientsRepositoryProvider).watch(),
);

final myEstimatesProvider = StreamProvider<List<EstimateRecord>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(estimateRepositoryProvider).watchMine(uid);
});

final estimateByCodeProvider = StreamProvider.family<EstimateRecord?, String>(
  (ref, code) => ref.watch(estimateRepositoryProvider).watch(code),
);
