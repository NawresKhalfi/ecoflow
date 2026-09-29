import '../../auth/domain/verification_status.dart';

/// Matières traitées par un recycleur.
enum RecyclableMaterial { pet, hdpe, pp, cardboard, aluminium, glass, other }

/// Profil entreprise d'un recycleur (US-007), stocké dans `companies/{uid}`.
class CompanyProfile {
  const CompanyProfile({
    required this.legalName,
    required this.taxId,
    required this.materials,
    required this.monthlyCapacityTons,
    required this.city,
    required this.contactPhone,
    this.status = VerificationStatus.notSubmitted,
    this.rejectionReason,
  });

  final String legalName;
  final String taxId;
  final Set<RecyclableMaterial> materials;
  final double monthlyCapacityTons;
  final String city;
  final String contactPhone;
  final VerificationStatus status;
  final String? rejectionReason;

  Map<String, dynamic> toMap() => {
        'legalName': legalName.trim(),
        'taxId': taxId.toUpperCase().replaceAll(' ', ''),
        'materials': materials.map((m) => m.name).toList()..sort(),
        'monthlyCapacityTons': monthlyCapacityTons,
        'city': city.trim(),
        'contactPhone': contactPhone,
      };

  static CompanyProfile fromMap(Map<String, dynamic> m) => CompanyProfile(
        legalName: m['legalName'] as String? ?? '',
        taxId: m['taxId'] as String? ?? '',
        materials: {
          for (final n in (m['materials'] as List? ?? const []))
            ...RecyclableMaterial.values.where((v) => v.name == n),
        },
        monthlyCapacityTons: (m['monthlyCapacityTons'] as num?)?.toDouble() ?? 0,
        city: m['city'] as String? ?? '',
        contactPhone: m['contactPhone'] as String? ?? '',
        status: VerificationStatus.fromName(m['status'] as String?),
        rejectionReason: m['rejectionReason'] as String?,
      );
}
