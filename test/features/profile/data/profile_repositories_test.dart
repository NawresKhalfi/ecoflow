import 'dart:typed_data';

import 'package:ecoflow/features/profile/data/account_deletion_repository.dart';
import 'package:ecoflow/features/profile/data/address_repository.dart';
import 'package:ecoflow/features/profile/data/company_repository.dart';
import 'package:ecoflow/features/profile/data/documents_repository.dart';
import 'package:ecoflow/features/profile/domain/address.dart';
import 'package:ecoflow/features/profile/domain/collector_document.dart';
import 'package:ecoflow/features/profile/domain/company_profile.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.doc('users/u').set({
      'displayName': 'Amine',
      'role': 'collector',
      'email': 'a@b.tn',
      'phoneNumber': '+21622123456',
      'verificationStatus': 'notSubmitted',
      'status': 'active',
    });
  });

  group('addresses', () {
    const home = SavedAddress(id: '', label: 'Maison', street: 'Rue 1', city: 'Sousse');

    test('first address becomes the default, only one default at a time', () async {
      final repo = FirestoreAddressRepository(db);
      await repo.save('u', home);
      await repo.save(
        'u',
        home.copyWith(label: 'Bureau', isDefault: true, latitude: 35.8, longitude: 10.6),
      );
      var list = await repo.watch('u').first;
      expect(list, hasLength(2));
      expect(list.first.label, 'Bureau');
      expect(list.where((a) => a.isDefault), hasLength(1));
      expect(list.first.hasPosition, isTrue);

      await repo.setDefault('u', list.last.id);
      list = await repo.watch('u').first;
      expect(list.first.label, 'Maison');
    });

    test('deleting the default promotes another address', () async {
      final repo = FirestoreAddressRepository(db);
      await repo.save('u', home);
      await repo.save('u', home.copyWith(label: 'Bureau'));
      final def = (await repo.watch('u').first).first;
      await repo.delete('u', def.id);
      final list = await repo.watch('u').first;
      expect(list.single.isDefault, isTrue);
    });
  });

  group('collector documents', () {
    test('upload stores metadata and file separately, submit sets pending', () async {
      final repo = FirestoreDocumentsRepository(db);
      for (final t in CollectorDocumentType.values) {
        await repo.upload('u', t, '${t.name}.jpg', Uint8List.fromList([1, 2, 3]));
      }
      final docs = await repo.watch('u').first;
      expect(isDossierComplete(docs), isTrue);
      expect((await db.doc('users/u/documentFiles/nationalId').get()).data()!['data'], 'AQID');

      await repo.submitForReview('u');
      expect((await db.doc('users/u').get()).data()!['verificationStatus'], 'pending');
      expect((await repo.watch('u').first).every((d) => d.status.name == 'pending'), isTrue);
    });

    test('rejects files over the size limit', () {
      final repo = FirestoreDocumentsRepository(db);
      expect(
        () => repo.upload(
          'u',
          CollectorDocumentType.vehiclePhoto,
          'big.jpg',
          Uint8List(maxDocumentBytes + 1),
        ),
        throwsArgumentError,
      );
    });
  });

  test('company profile is submitted for admin validation', () async {
    final repo = FirestoreCompanyRepository(db);
    await repo.submit(
      'u',
      const CompanyProfile(
        legalName: ' GreenPlast SARL ',
        taxId: '1234567a/a/m/000',
        materials: {RecyclableMaterial.pp, RecyclableMaterial.pet},
        monthlyCapacityTons: 40,
        city: 'Sousse',
        contactPhone: '+21673000000',
      ),
    );
    final c = await repo.watch('u').first;
    expect(c!.legalName, 'GreenPlast SARL');
    expect(c.taxId, '1234567A/A/M/000');
    expect(c.status.name, 'pending');
    expect(c.materials, {RecyclableMaterial.pet, RecyclableMaterial.pp});
    expect((await db.doc('users/u').get()).data()!['verificationStatus'], 'pending');
  });

  test('account deletion anonymizes personal data and schedules purge', () async {
    await FirestoreAddressRepository(
      db,
    ).save('u', const SavedAddress(id: '', label: 'M', street: 'R', city: 'S'));
    await FirestoreDocumentsRepository(
      db,
    ).upload('u', CollectorDocumentType.nationalId, 'id.jpg', Uint8List(3));
    final now = DateTime(2026, 9, 29);
    await FirestoreAccountDeletionRepository(db).anonymize('u', now);

    final user = (await db.doc('users/u').get()).data()!;
    expect(user['email'], isNull);
    expect(user['phoneNumber'], isNull);
    expect(user['status'], 'deleted');
    expect(user['role'], 'collector', reason: 'role kept for anonymous financial history');
    expect((await db.collection('users/u/addresses').get()).docs, isEmpty);
    expect((await db.collection('users/u/documentFiles').get()).docs, isEmpty);
    final req = (await db.doc('deletionRequests/u').get()).data()!;
    expect(req['purgeBefore'].toDate(), now.add(const Duration(days: 30)));
  });
}
