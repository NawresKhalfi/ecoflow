import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/profile/application/data_export_controller.dart';
import 'package:ecoflow/features/profile/data/personal_data_export.dart';
import 'package:ecoflow/features/recycler/application/recycler_providers.dart';
import 'package:ecoflow/features/vision_admin/application/vision_admin_controllers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  test('JSON-safe values: dates, positions, large photos omitted', () {
    expect(jsonSafe(Timestamp.fromDate(DateTime.utc(2026, 10, 1))), '2026-10-01T00:00:00.000Z');
    expect(jsonSafe(const GeoPoint(35.8, 10.6)), {'lat': 35.8, 'lng': 10.6});
    expect(jsonSafe('A' * 5000), '[contenu binaire omis]');
    expect(
      jsonSafe({
        'a': [1, null, true],
      }),
      {
        'a': [1, null, true],
      },
    );
  });

  test('right of access: every personal section, other users excluded (US-127)', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/leila').set({
      'displayName': 'Leila',
      'consent': {'version': '2026-09'},
    });
    await db.doc('users/leila/addresses/a1').set({'label': 'Maison'});
    await db.doc('wallets/leila').set({'earned': 120});
    await db.collection('estimates').add({'citizenUid': 'leila', 'totalKg': 3.0});
    await db.collection('estimates').add({'citizenUid': 'other', 'totalKg': 9.0});
    await db.collection('notifications').add({'toUid': 'leila', 'type': 'assigned'});
    final out = await collectPersonalData(db, 'leila', now: DateTime.utc(2026, 10, 1));
    expect((out['format'], out['uid']), ('ecoflow-personal-data', 'leila'));
    expect((out['profile'] as Map)['consent'], {'version': '2026-09'});
    expect((out['addresses'] as List).single['label'], 'Maison');
    expect((out['estimates'] as List).single['totalKg'], 3.0);
    expect((out['notifications'] as List), hasLength(1));
    expect(out['company'], isNull);
    expect(jsonDecode(encodeExport(out)), isA<Map>());
  });

  test('export controller writes the file and opens the share sheet', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/leila').set({
      'displayName': 'Leila',
      'role': 'citizen',
      'status': 'active',
    });
    final tmp = await Directory.systemTemp.createTemp('export');
    addTearDown(() => tmp.delete(recursive: true));
    final shared = <String>[];
    final c = await testContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            initialUser: const AuthUser(uid: 'leila', phoneNumber: '+216', providerIds: ['phone']),
          ),
        ),
        firestoreProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 1)),
        exportDirectoryProvider.overrideWithValue(() async => tmp),
        fileSharerProvider.overrideWithValue((path) async => shared.add(path)),
      ],
    );
    c.listen(dataExportControllerProvider, (_, _) {});
    await pumpEventQueue();
    expect(await c.read(dataExportControllerProvider.notifier).export(), isTrue);
    expect(shared.single, endsWith('ecoflow-mes-donnees-2026-10-01.json'));
    final json = jsonDecode(File(shared.single).readAsStringSync()) as Map;
    expect((json['profile'] as Map)['displayName'], 'Leila');
  });
}
