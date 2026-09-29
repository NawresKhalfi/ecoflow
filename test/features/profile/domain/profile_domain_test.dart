import 'package:ecoflow/features/auth/domain/verification_status.dart';
import 'package:ecoflow/features/profile/domain/address.dart';
import 'package:ecoflow/features/profile/domain/collector_document.dart';
import 'package:ecoflow/features/profile/domain/company_profile.dart';
import 'package:ecoflow/features/profile/domain/notification_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeAddresses keeps exactly one default, first in list', () {
    const a = SavedAddress(id: 'a', label: 'A', street: 's', city: 'c');
    const b = SavedAddress(id: 'b', label: 'B', street: 's', city: 'c', isDefault: true);
    expect(normalizeAddresses([a, b]).map((x) => (x.id, x.isDefault)), [('b', true), ('a', false)]);
    expect(normalizeAddresses([a, a.copyWith(id: 'z')]).first.isDefault, isTrue);
  });

  test('notification preferences default to enabled and serialize', () {
    final p = NotificationPreferences.fromMap({'points': false});
    expect(p.isEnabled(NotificationCategory.points), isFalse);
    expect(p.isEnabled(NotificationCategory.marketplace), isTrue);
    expect(p.toMap(), {'collectionStatus': true, 'points': false, 'marketplace': true});
    expect(NotificationPreferences.fromMap(null).toMap().values.every((v) => v), isTrue);
  });

  test('dossier is complete only with the 4 documents', () {
    CollectorDocument d(CollectorDocumentType t) => CollectorDocument(
      type: t,
      fileName: 'f',
      sizeBytes: 1,
      status: VerificationStatus.notSubmitted,
    );
    expect(isDossierComplete(CollectorDocumentType.values.take(3).map(d)), isFalse);
    expect(isDossierComplete(CollectorDocumentType.values.map(d)), isTrue);
  });

  test('company profile map is normalized', () {
    final m = const CompanyProfile(
      legalName: ' X ',
      taxId: '1234567 a',
      materials: {RecyclableMaterial.pp, RecyclableMaterial.glass},
      monthlyCapacityTons: 2,
      city: 'Sfax',
      contactPhone: '',
    ).toMap();
    expect(m['taxId'], '1234567A');
    expect(m['materials'], ['glass', 'pp']);
    expect(CompanyProfile.fromMap(m).materials, {RecyclableMaterial.pp, RecyclableMaterial.glass});
  });
}
