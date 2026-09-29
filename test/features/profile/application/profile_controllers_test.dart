import 'dart:typed_data';

import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/core/localization/app_language.dart';
import 'package:ecoflow/core/localization/language_controller.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_failure.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/profile/application/account_deletion_controller.dart';
import 'package:ecoflow/features/profile/application/company_controller.dart';
import 'package:ecoflow/features/profile/application/documents_controller.dart';
import 'package:ecoflow/features/profile/application/profile_providers.dart';
import 'package:ecoflow/features/profile/application/settings_controller.dart';
import 'package:ecoflow/features/profile/data/document_picker.dart';
import 'package:ecoflow/features/profile/domain/collector_document.dart';
import 'package:ecoflow/features/profile/domain/company_profile.dart';
import 'package:ecoflow/features/profile/domain/notification_preferences.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

class _Picker implements DocumentPicker {
  _Picker(this.size);
  final int size;
  @override
  Future<PickedFile?> pick(PickSource source) async => (name: 'cin.jpg', bytes: Uint8List(size));
}

void main() {
  late FakeAuthRepository auth;
  late FakeFirebaseFirestore db;
  late ProviderContainer c;

  Future<void> setUpWith({required AuthUser user, int pickSize = 10}) async {
    auth = FakeAuthRepository(initialUser: user);
    db = FakeFirebaseFirestore();
    await db.doc('users/${user.uid}').set({
      'displayName': 'Amine',
      'role': 'collector',
      'email': user.email,
      'verificationStatus': 'notSubmitted',
      'notificationPreferences': NotificationPreferences.defaults.toMap(),
      'status': 'active',
    });
    c = await testContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        firestoreProvider.overrideWithValue(db),
        documentPickerProvider.overrideWithValue(_Picker(pickSize)),
      ],
    );
    c.listen(currentProfileProvider, (_, _) {});
    await pumpEventQueue();
  }

  const emailUser = AuthUser(
    uid: 'u',
    email: 'a@b.tn',
    emailVerified: true,
    providerIds: ['password'],
  );

  group('SettingsController (US-008/009)', () {
    test('language change is applied and synced to the profile', () async {
      await setUpWith(user: emailUser);
      c.listen(settingsControllerProvider, (_, _) {});
      await c.read(settingsControllerProvider.notifier).selectLanguage(AppLanguage.ar);
      expect(c.read(languageControllerProvider), AppLanguage.ar);
      expect((await db.doc('users/u').get()).data()!['languageCode'], 'ar');
    });

    test('toggles a notification category', () async {
      await setUpWith(user: emailUser);
      c.listen(settingsControllerProvider, (_, _) {});
      await c
          .read(settingsControllerProvider.notifier)
          .toggleNotification(NotificationCategory.marketplace, false);
      final prefs = (await db.doc('users/u').get()).data()!['notificationPreferences'];
      expect(prefs, {'collectionStatus': true, 'points': true, 'marketplace': false});
    });
  });

  group('DocumentsController (US-006)', () {
    test('uploads a picked document', () async {
      await setUpWith(user: emailUser);
      c.listen(documentsControllerProvider, (_, _) {});
      await c
          .read(documentsControllerProvider.notifier)
          .pickAndUpload(CollectorDocumentType.nationalId, PickSource.gallery);
      expect((await db.doc('users/u/documents/nationalId').get()).exists, isTrue);
    });

    test('refuses files that are too large', () async {
      await setUpWith(user: emailUser, pickSize: maxDocumentBytes + 1);
      c.listen(documentsControllerProvider, (_, _) {});
      await c
          .read(documentsControllerProvider.notifier)
          .pickAndUpload(CollectorDocumentType.nationalId, PickSource.camera);
      expect(c.read(documentsControllerProvider).error, isA<DocumentTooLarge>());
    });
  });

  test('CompanyController requires at least one material (US-007)', () async {
    await setUpWith(user: emailUser);
    c.listen(companyControllerProvider, (_, _) {});
    await c
        .read(companyControllerProvider.notifier)
        .submit(
          const CompanyProfile(
            legalName: 'X',
            taxId: '1234567A',
            materials: {},
            monthlyCapacityTons: 1,
            city: 'S',
            contactPhone: '',
          ),
        );
    expect(c.read(companyControllerProvider).error, isA<NoMaterialSelected>());
    expect((await db.doc('companies/u').get()).exists, isFalse);
  });

  group('AccountDeletionController (US-010)', () {
    test('step 1 requires the confirmation word', () async {
      await setUpWith(user: emailUser);
      final ctrl = c.read(accountDeletionControllerProvider.notifier);
      expect(ctrl.isConfirmationValid('supprimer '), isTrue);
      expect(ctrl.isConfirmationValid('oui'), isFalse);
    });

    test('wrong password leaves all data intact', () async {
      await setUpWith(user: emailUser);
      auth.passwords['a@b.tn'] = 'recycle26';
      c.listen(accountDeletionControllerProvider, (_, _) {});
      await c.read(accountDeletionControllerProvider.notifier).deleteAccount(password: 'nope');
      expect(
        (c.read(accountDeletionControllerProvider).error as AuthFailure).code,
        AuthFailureCode.wrongCredentials,
      );
      expect((await db.doc('users/u').get()).data()!['email'], 'a@b.tn');
      expect(auth.deleted, isFalse);
    });

    test('valid password anonymizes, deletes and signs out', () async {
      await setUpWith(user: emailUser);
      auth.passwords['a@b.tn'] = 'recycle26';
      c.listen(accountDeletionControllerProvider, (_, _) {});
      expect(
        await c
            .read(accountDeletionControllerProvider.notifier)
            .deleteAccount(password: 'recycle26'),
        isTrue,
      );
      expect((await db.doc('users/u').get()).data()!['status'], 'deleted');
      expect(auth.deleted, isTrue);
      expect(auth.currentUser, isNull);
    });

    test('phone users must have signed in recently', () async {
      await setUpWith(
        user: const AuthUser(uid: 'u', phoneNumber: '+21622123456', providerIds: ['phone']),
      );
      auth.recentLogin = false;
      c.listen(accountDeletionControllerProvider, (_, _) {});
      await c.read(accountDeletionControllerProvider.notifier).deleteAccount();
      expect(
        (c.read(accountDeletionControllerProvider).error as AuthFailure).code,
        AuthFailureCode.requiresRecentLogin,
      );
      expect((await db.doc('users/u').get()).data()!['status'], 'active');
    });
  });
}
