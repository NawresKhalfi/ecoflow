import '../../auth/domain/verification_status.dart';

/// Pièces justificatives d'un collecteur (US-006).
enum CollectorDocumentType { nationalId, drivingLicense, vehicleRegistration, vehiclePhoto }

/// Métadonnées d'un document envoyé (le fichier est stocké à part).
class CollectorDocument {
  const CollectorDocument({
    required this.type,
    required this.fileName,
    required this.sizeBytes,
    required this.status,
    this.uploadedAt,
    this.rejectionReason,
  });

  final CollectorDocumentType type;
  final String fileName;
  final int sizeBytes;
  final VerificationStatus status;
  final DateTime? uploadedAt;
  final String? rejectionReason;

  static CollectorDocumentType? typeFromName(String n) {
    for (final t in CollectorDocumentType.values) {
      if (t.name == n) return t;
    }
    return null;
  }
}

/// Taille maximale d'un fichier (après compression) : il est stocké dans
/// Firestore, limité à 1 Mio par document encodage base64 compris.
const maxDocumentBytes = 700 * 1024;

/// Le dossier est complet quand les 4 pièces sont présentes.
bool isDossierComplete(Iterable<CollectorDocument> docs) {
  final types = docs.map((d) => d.type).toSet();
  return CollectorDocumentType.values.every(types.contains);
}
