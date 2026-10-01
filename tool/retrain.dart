// Réentraînement de nuit du modèle de prévision (US-093), sans offre Blaze.
//
//   dart run tool/retrain.dart [--dry-run]
//
// Mêmes fonctions que l'app (lib/features/forecast/domain) : seules la lecture
// et l'écriture passent par l'API REST de Firestore, avec un compte
// administrateur (ECOFLOW_BACKUP_EMAIL / ECOFLOW_BACKUP_PASSWORD). Avec
// ECOFLOW_EMULATOR=1, vise l'émulateur local.
import 'dart:convert';
import 'dart:io';

import 'package:ecoflow/features/collection/domain/service_zone.dart';
import 'package:ecoflow/features/forecast/domain/training_data.dart';
import 'package:ecoflow/features/forecast/domain/zone_forecast.dart';
import 'package:ecoflow/features/scan/domain/waste_category.dart';

final env = Platform.environment;
final project = env['FIREBASE_PROJECT'] ?? 'meteo-ba45f';
final emulator = env['ECOFLOW_EMULATOR'] != null;
const apiKey = 'AIzaSyCLSoHoFwebyGvjJHgl_mRXwByiu53KsKY'; // clé web publique
final docsRoot = 'projects/$project/databases/(default)/documents';
final base = emulator
    ? 'http://127.0.0.1:8080/v1/$docsRoot'
    : 'https://firestore.googleapis.com/v1/$docsRoot';
final auth = emulator
    ? 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts'
    : 'https://identitytoolkit.googleapis.com/v1/accounts';
final client = HttpClient();

Future<(int, Map<String, dynamic>)> call(String url, {Object? body, String? token}) async {
  final req = body == null
      ? await client.getUrl(Uri.parse(url))
      : await client.postUrl(Uri.parse(url));
  req.headers.contentType = ContentType.json;
  if (token != null) req.headers.set('Authorization', 'Bearer $token');
  if (body != null) req.write(jsonEncode(body));
  final res = await req.close();
  final text = await res.transform(utf8.decoder).join();
  return (
    res.statusCode,
    text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>,
  );
}

/// Valeur REST Firestore → Dart (dates en DateTime).
Object? decode(Map<String, dynamic> v) {
  if (v.containsKey('nullValue')) return null;
  if (v['booleanValue'] case final bool b) return b;
  if (v['integerValue'] case final String i) return int.parse(i);
  if (v['doubleValue'] case final num d) return d.toDouble();
  if (v['stringValue'] case final String s) return s;
  if (v['timestampValue'] case final String t) return DateTime.parse(t);
  if (v['mapValue'] case final Map m) {
    return fields(m['fields'] as Map<String, dynamic>? ?? const {});
  }
  if (v['arrayValue'] case final Map a) {
    return [for (final x in (a['values'] as List? ?? const [])) decode(x as Map<String, dynamic>)];
  }
  if (v['geoPointValue'] case final Map g) return {'lat': g['latitude'], 'lng': g['longitude']};
  return null;
}

Map<String, dynamic> fields(Map<String, dynamic> f) => {
  for (final e in f.entries) e.key: decode(e.value as Map<String, dynamic>),
};

/// Dart → valeur REST Firestore.
Map<String, dynamic> encode(Object? v) => switch (v) {
  null => {'nullValue': null},
  bool b => {'booleanValue': b},
  int i => {'integerValue': '$i'},
  double d => {'doubleValue': d},
  String s => {'stringValue': s},
  DateTime t => {'timestampValue': t.toUtc().toIso8601String()},
  Map m => {
    'mapValue': {
      'fields': {for (final e in m.entries) '${e.key}': encode(e.value)},
    },
  },
  Iterable l => {
    'arrayValue': {
      'values': [for (final x in l) encode(x)],
    },
  },
  _ => {'stringValue': '$v'},
};

Future<List<(String, Map<String, dynamic>)>> listDocs(String path, String token) async {
  final out = <(String, Map<String, dynamic>)>[];
  String? page;
  do {
    final q = 'pageSize=300${page == null ? '' : '&pageToken=$page'}';
    final (code, r) = await call('$base/$path?$q', token: token);
    if (code != 200) throw StateError('$path : $code ${r['error']?['message']}');
    for (final d in (r['documents'] as List? ?? const [])) {
      final name = d['name'] as String;
      out.add((
        name.substring(name.lastIndexOf('/') + 1),
        fields(d['fields'] as Map<String, dynamic>? ?? const {}),
      ));
    }
    page = r['nextPageToken'] as String?;
  } while (page != null);
  return out;
}

Future<Map<String, dynamic>?> getDoc(String path, String token) async {
  final (code, r) = await call('$base/$path', token: token);
  return code == 200 ? fields(r['fields'] as Map<String, dynamic>? ?? const {}) : null;
}

DateTime? readDate(Object? v) => v is DateTime ? v : null;

Future<void> main(List<String> args) async {
  final dry = args.contains('--dry-run');
  final email = env['ECOFLOW_BACKUP_EMAIL'] ?? 'admin@ecoflow.tn';
  final password = env['ECOFLOW_BACKUP_PASSWORD'] ?? 'recycle26';
  final (code, login) = await call(
    '$auth:signInWithPassword?key=$apiKey',
    body: {'email': email, 'password': password, 'returnSecureToken': true},
  );
  if (code != 200) {
    stderr.writeln('Connexion administrateur impossible : ${login['error']?['message']}');
    exit(1);
  }
  final token = login['idToken'] as String;
  final adminUid = login['localId'] as String;
  final now = DateTime.now();

  final catalogDocs = await listDocs('wasteCategories', token);
  final catalog = catalogDocs.isEmpty
      ? defaultCatalog
      : [for (final (id, m) in catalogDocs) WasteCategory.fromMap(id, m)];
  final config = await getDoc('config/collection', token);
  final parsed = [
    for (final e in ((config?['zones'] as Map?) ?? const {}).entries)
      if (ServiceZone.fromMap('${e.key}', e.value as Map) case final z?) z,
  ];
  final zones = parsed.isEmpty ? defaultZones : parsed;

  final collections = [for (final (_, m) in await listDocs('collections', token)) m];
  final completed = [
    for (final m in collections)
      if (m['status'] == 'completed') m,
  ];
  final estimates = {for (final (id, m) in await listDocs('estimates', token)) id: m};
  final records = volumeRecordsFrom(completed, estimates, catalog, readDate);

  final since = now.subtract(const Duration(days: 30));
  final recent = [
    for (final m in collections)
      if (readDate(m['createdAt']) case final d? when !d.isBefore(since)) m,
  ];
  final capacity = <String, double>{};
  for (final uid in {for (final c in activeCollectors(recent).values) ...c}) {
    final p = await getDoc('collectorPresence/$uid', token);
    capacity[uid] = (p?['capacityKg'] as num?)?.toDouble() ?? 200;
  }

  final forecasts = computeForecasts(records, zones, now);
  final alerts = computeAlerts(forecasts, supplyFrom(recent, capacity, zones, now, readDate));
  stdout.writeln(
    '✓ ${records.length} collectes pesées, ${forecasts.length} zones prévues, ${alerts.length} alertes',
  );
  if (dry) return client.close();

  final runId = 'n${now.toUtc().toIso8601String().substring(0, 10).replaceAll('-', '')}';
  final writes = [
    for (final f in forecasts.values)
      {
        'update': {
          'name': '$docsRoot/forecasts/${f.zoneId}',
          'fields': (encode(f.toMap())['mapValue'] as Map)['fields'],
        },
        'updateTransforms': [
          {'fieldPath': 'trainedAt', 'setToServerValue': 'REQUEST_TIME'},
        ],
      },
    {
      'update': {
        'name': '$docsRoot/forecastRuns/$runId',
        'fields':
            (encode(
                  runDocument(
                    forecasts: forecasts,
                    alerts: alerts,
                    records: records.length,
                    adminUid: adminUid,
                    trigger: 'scheduled',
                  ),
                )['mapValue']
                as Map)['fields'],
      },
      'currentDocument': {'exists': false},
      'updateTransforms': [
        {'fieldPath': 'at', 'setToServerValue': 'REQUEST_TIME'},
      ],
    },
  ];
  final (status, r) = await call('$base:commit', body: {'writes': writes}, token: token);
  client.close();
  if (status != 200) {
    stderr.writeln('Publication refusée : $status ${r['error']?['message']}');
    exit(1);
  }
  stdout.writeln('✓ prévisions publiées (entraînement $runId)');
}
