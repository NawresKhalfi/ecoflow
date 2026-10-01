import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Droit d'accès (US-127, loi organique n° 2004-63) : copie lisible de
/// toutes les données rattachées au compte. Les photos (base64) sont
/// remplacées par un marqueur pour garder un fichier léger.
const exportFormatVersion = 1;

Object? jsonSafe(Object? v) => switch (v) {
  null || bool() || num() => v,
  String s when s.length > 2000 => '[contenu binaire omis]',
  String() => v,
  Timestamp t => t.toDate().toUtc().toIso8601String(),
  DateTime d => d.toUtc().toIso8601String(),
  GeoPoint g => {'lat': g.latitude, 'lng': g.longitude},
  DocumentReference r => r.path,
  Map m => {for (final e in m.entries) '${e.key}': jsonSafe(e.value)},
  Iterable i => [for (final x in i) jsonSafe(x)],
  _ => v.toString(),
};

/// Sections : documents personnels et requêtes « mes éléments ». Une
/// section illisible (règles, réseau) est signalée sans bloquer l'export.
Future<Map<String, Object?>> collectPersonalData(
  FirebaseFirestore db,
  String uid, {
  required DateTime now,
  String? role,
}) async {
  final out = <String, Object?>{
    'format': 'ecoflow-personal-data',
    'version': exportFormatVersion,
    'exportedAt': now.toUtc().toIso8601String(),
    'uid': uid,
  };
  Future<void> section(String name, Future<Object?> Function() read) async {
    try {
      out[name] = jsonSafe(await read());
    } catch (_) {
      out[name] = {'error': 'unavailable'};
    }
  }

  Future<Object?> one(String path) async => (await db.doc(path).get()).data();
  Future<Object?> many(Query<Map<String, dynamic>> q) async => [
    for (final d in (await q.get()).docs) {'id': d.id, ...d.data()},
  ];
  Future<Object?> sub(String path) => many(db.collection(path));
  Query<Map<String, dynamic>> mine(String col, String field) =>
      db.collection(col).where(field, isEqualTo: uid);

  await section('profile', () => one('users/$uid'));
  await section('addresses', () => sub('users/$uid/addresses'));
  await section('documents', () => sub('users/$uid/documents'));
  if (role == null || role == 'recycler') await section('company', () => one('companies/$uid'));
  await section('wallet', () => one('wallets/$uid'));
  await section('pointEntries', () => many(mine('pointEntries', 'uid')));
  await section('redemptions', () => many(mine('redemptions', 'uid')));
  await section('scans', () => many(mine('scans', 'uid')));
  await section('estimates', () => many(mine('estimates', 'citizenUid')));
  await section('collections', () => many(mine('collections', 'citizenUid')));
  // Espace collecteur : seulement pour ce rôle (requêtes refusées sinon).
  if (role == null || role == 'collector') {
    await section('missions', () => many(mine('collections', 'collectorUid')));
    await section('earnings', () => many(mine('earnings', 'collectorUid')));
    await section('payouts', () => many(mine('payouts', 'collectorUid')));
    await section('collectorBalance', () => one('collectorBalances/$uid'));
  }
  await section('notifications', () => many(mine('notifications', 'toUid')));
  return out;
}

String encodeExport(Map<String, Object?> data) => const JsonEncoder.withIndent('  ').convert(data);
