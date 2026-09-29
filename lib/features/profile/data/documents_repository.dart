import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/domain/verification_status.dart';
import '../domain/collector_document.dart';

/// Pièces du collecteur. Les métadonnées vivent dans
/// `users/{uid}/documents/{type}` et le fichier (compressé, base64) dans
/// `users/{uid}/documentFiles/{type}` pour ne pas alourdir les listes.
abstract interface class DocumentsRepository {
  Stream<List<CollectorDocument>> watch(String uid);
  Future<void> upload(String uid, CollectorDocumentType type, String fileName, Uint8List bytes);
  Future<void> submitForReview(String uid);
}

class FirestoreDocumentsRepository implements DocumentsRepository {
  FirestoreDocumentsRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) => _db.collection('users').doc(uid);

  @override
  Stream<List<CollectorDocument>> watch(String uid) => _user(uid)
      .collection('documents')
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            if (CollectorDocument.typeFromName(d.id) case final type?)
              CollectorDocument(
                type: type,
                fileName: d.data()['fileName'] as String? ?? '',
                sizeBytes: (d.data()['sizeBytes'] as num?)?.toInt() ?? 0,
                status: VerificationStatus.fromName(d.data()['status'] as String?),
                uploadedAt: (d.data()['uploadedAt'] as Timestamp?)?.toDate(),
                rejectionReason: d.data()['rejectionReason'] as String?,
              ),
        ],
      );

  @override
  Future<void> upload(
    String uid,
    CollectorDocumentType type,
    String fileName,
    Uint8List bytes,
  ) async {
    if (bytes.length > maxDocumentBytes) {
      throw ArgumentError.value(bytes.length, 'bytes', 'Fichier trop volumineux');
    }
    final batch = _db.batch();
    batch.set(_user(uid).collection('documentFiles').doc(type.name), {'data': base64Encode(bytes)});
    batch.set(_user(uid).collection('documents').doc(type.name), {
      'fileName': fileName,
      'sizeBytes': bytes.length,
      'status': VerificationStatus.notSubmitted.name,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  @override
  Future<void> submitForReview(String uid) async {
    final docs = await _user(uid).collection('documents').get();
    final batch = _db.batch();
    for (final d in docs.docs) {
      batch.update(d.reference, {'status': VerificationStatus.pending.name});
    }
    batch.update(_user(uid), {
      'verificationStatus': VerificationStatus.pending.name,
      'submittedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
