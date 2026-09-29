import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/account_deletion_repository.dart';
import '../data/address_repository.dart';
import '../data/company_repository.dart';
import '../data/document_picker.dart';
import '../data/documents_repository.dart';
import '../data/location_service.dart';
import '../domain/address.dart';
import '../domain/collector_document.dart';
import '../domain/company_profile.dart';

final addressRepositoryProvider = Provider<AddressRepository>(
    (ref) => FirestoreAddressRepository(ref.watch(firestoreProvider)));
final documentsRepositoryProvider = Provider<DocumentsRepository>(
    (ref) => FirestoreDocumentsRepository(ref.watch(firestoreProvider)));
final companyRepositoryProvider = Provider<CompanyRepository>(
    (ref) => FirestoreCompanyRepository(ref.watch(firestoreProvider)));
final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>(
    (ref) => FirestoreAccountDeletionRepository(ref.watch(firestoreProvider)));
final locationServiceProvider =
    Provider<LocationService>((ref) => GeolocatorLocationService());
final documentPickerProvider =
    Provider<DocumentPicker>((ref) => ImagePickerDocumentPicker());

Stream<T> _forUser<T>(Ref ref, T empty, Stream<T> Function(String uid) watch) {
  final uid = ref.watch(currentUidProvider);
  return uid == null ? Stream.value(empty) : watch(uid);
}

final addressesProvider = StreamProvider.autoDispose<List<SavedAddress>>((ref) =>
    _forUser(ref, const [], ref.watch(addressRepositoryProvider).watch));

final collectorDocumentsProvider = StreamProvider.autoDispose<List<CollectorDocument>>(
    (ref) => _forUser(ref, const [], ref.watch(documentsRepositoryProvider).watch));

final companyProfileProvider = StreamProvider.autoDispose<CompanyProfile?>(
    (ref) => _forUser(ref, null, ref.watch(companyRepositoryProvider).watch));

/// Uid courant, ou erreur si la session a expiré.
String requireUid(Ref ref) {
  final uid = ref.read(currentUidProvider);
  if (uid == null) throw StateError('No signed-in user');
  return uid;
}
