import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/collection_repository.dart';
import '../data/collection_support_repositories.dart';
import '../domain/collection_request.dart';

final collectionRepositoryProvider = Provider<CollectionRepository>(
  (ref) => FirestoreCollectionRepository(ref.watch(firestoreProvider)),
);
final presenceRepositoryProvider = Provider<PresenceRepository>(
  (ref) => FirestorePresenceRepository(ref.watch(firestoreProvider)),
);
final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => FirestoreFeedbackRepository(ref.watch(firestoreProvider)),
);
final reverseGeocoderProvider = Provider<ReverseGeocoder>((ref) => NativeReverseGeocoder());

final collectionConfigProvider = StreamProvider<CollectionConfig>(
  (ref) => watchCollectionConfig(ref.watch(firestoreProvider)),
);

final myCollectionsProvider = StreamProvider<List<CollectionRequest>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(collectionRepositoryProvider).watchMine(uid);
});

final collectionByIdProvider = StreamProvider.family<CollectionRequest?, String>(
  (ref, id) => ref.watch(collectionRepositoryProvider).watch(id),
);

final slotCountsProvider = StreamProvider.family<Map<String, int>, String>(
  (ref, zoneId) => ref.watch(collectionRepositoryProvider).watchSlotCounts(zoneId),
);

/// Points de dépôt proposés en alternative (US-036) : recycleurs validés de
/// la ville de la collecte.
final dropPointsProvider = StreamProvider.family<List<({String name, String city})>, String>(
  (ref, city) => ref
      .watch(firestoreProvider)
      .collection('companies')
      .where('status', isEqualTo: 'approved')
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            if ((d.data()['city'] as String? ?? '').toLowerCase().contains(city.toLowerCase()) ||
                city.toLowerCase().contains((d.data()['city'] as String? ?? '~').toLowerCase()))
              (
                name: d.data()['legalName'] as String? ?? '',
                city: d.data()['city'] as String? ?? '',
              ),
        ],
      ),
);
