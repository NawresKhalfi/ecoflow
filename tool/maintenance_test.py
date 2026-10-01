#!/usr/bin/env python3
"""Test de tool/maintenance.py contre l'émulateur (CI, job « Règles Firestore »).

  firebase emulators:exec --only auth,firestore --project demo-ecoflow \
    "FIREBASE_PROJECT=demo-ecoflow python3 tool/maintenance_test.py"
"""
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone

os.environ['ECOFLOW_EMULATOR'] = '1'
os.environ.setdefault('ECOFLOW_BACKUP_EMAIL', 'maint-admin@ecoflow.test')
os.environ.setdefault('ECOFLOW_BACKUP_PASSWORD', 'recycle26')
sys.path.insert(0, os.path.dirname(__file__))
from backup import API_KEY, AUTH_EMULATOR, PROJECT, call, root  # noqa: E402

BASE = root(True)
now = datetime.now(timezone.utc)


def ts(d):
    return {'timestampValue': d.strftime('%Y-%m-%dT%H:%M:%SZ')}


def put(path, fields):
    code, r = call(f'{BASE}/{path}', {'fields': fields}, 'owner', 'PATCH')
    assert code == 200, (path, r)


def get(path):
    code, r = call(f'{BASE}/{path}', token='owner')
    return r.get('fields') if code == 200 else None


# Administrateur de test (créé dans l'émulateur d'authentification).
body = {'email': os.environ['ECOFLOW_BACKUP_EMAIL'], 'password': os.environ['ECOFLOW_BACKUP_PASSWORD'],
        'returnSecureToken': True}
code, r = call(f'{AUTH_EMULATOR}:signUp?key={API_KEY}', body)
if code != 200:
    code, r = call(f'{AUTH_EMULATOR}:signInWithPassword?key={API_KEY}', body)
put(f'users/{r["localId"]}', {'role': {'stringValue': 'admin'}, 'status': {'stringValue': 'active'}})

# Scan expiré (2 photos) et scan récent.
put('scans/old', {'uid': {'stringValue': 'u1'}, 'expiresAt': ts(now - timedelta(days=1)),
                  'photoCount': {'integerValue': '2'}})
for i in ('0', '1'):
    put(f'scans/old/photos/{i}', {'uid': {'stringValue': 'u1'}, 'data': {'stringValue': 'AQID'}})
put('scans/new', {'uid': {'stringValue': 'u1'}, 'expiresAt': ts(now + timedelta(days=60)),
                  'photoCount': {'integerValue': '1'}})
put('scans/new/photos/0', {'uid': {'stringValue': 'u1'}, 'data': {'stringValue': 'AQID'}})

# Wallet : 100 points gagnés il y a 13 mois, 40 récemment, 30 déjà dépensés.
put('wallets/u1', {k: {'integerValue': str(v)} for k, v in
                   {'earned': 140, 'spent': 30, 'expired': 0, 'held': 0, 'collections': 2}.items()})
for eid, pts, age in [('c_a', 100, 395), ('c_b', 40, 10)]:
    put(f'pointEntries/{eid}', {'uid': {'stringValue': 'u1'}, 'type': {'stringValue': 'earn'},
                                'points': {'integerValue': str(pts)}, 'status': {'stringValue': 'credited'},
                                'createdAt': ts(now - timedelta(days=age))})

out = subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), 'maintenance.py')],
                     capture_output=True, text=True, env=os.environ)
print(out.stdout, out.stderr)

checks = [
    ('expired photos deleted', get('scans/old/photos/0') is None and get('scans/old/photos/1') is None),
    ('scan marked purged', (get('scans/old') or {}).get('photosPurged') == {'booleanValue': True}),
    ('recent photos kept', get('scans/new/photos/0') is not None),
    ('old points expired FIFO (100 - 30 spent = 70)',
     (get('wallets/u1') or {}).get('expired') == {'integerValue': '70'}),
]
for label, ok in checks:
    print('PASS' if ok else 'FAIL', label)
sys.exit(0 if all(ok for _, ok in checks) else 1)
