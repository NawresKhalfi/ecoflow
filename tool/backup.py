#!/usr/bin/env python3
"""Sauvegarde et restauration de la base EcoFlow (US-132), sans offre Blaze.

Les sauvegardes planifiées de Firestore exigent l'offre payante : ce script
exporte chaque collection au format REST de Firestore (types conservés) avec
un compte administrateur, via l'API publique et les règles, comme l'app.

  python3 tool/backup.py export [dossier]          # projet réel (compte admin)
  python3 tool/backup.py restore <dossier>         # vers l'ÉMULATEUR uniquement
  python3 tool/backup.py verify <dossier>          # compare émulateur et sauvegarde

Compte : variables ECOFLOW_BACKUP_EMAIL / ECOFLOW_BACKUP_PASSWORD
(compte administrateur ; par défaut le compte de démonstration admin@).
ECOFLOW_EMULATOR=1 exporte depuis l'émulateur. La restauration sur le projet
réel se fait depuis l'émulateur vérifié, par import de la console Firebase ou
par un compte de service : jamais par ce script, pour ne rien écraser par erreur.
"""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

PROJECT = os.environ.get('FIREBASE_PROJECT', 'meteo-ba45f')
API_KEY = 'AIzaSyCLSoHoFwebyGvjJHgl_mRXwByiu53KsKY'  # clé web publique (firebase_options.dart)
EMULATOR = 'http://127.0.0.1:8080/v1'
REAL = 'https://firestore.googleapis.com/v1'
AUTH_REAL = 'https://identitytoolkit.googleapis.com/v1/accounts'
AUTH_EMULATOR = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts'

COLLECTIONS = [
    'users', 'companies', 'deletionRequests', 'scans', 'wasteCategories', 'modelVersions', 'config',
    'priceScales', 'estimates', 'collections', 'slotCounters', 'collectorStats',
    'ratings', 'tickets', 'earnings', 'collectorBalances', 'payouts', 'deposits', 'notifications',
    'pointEntries', 'wallets', 'referralCodes', 'partners', 'rewards', 'redemptions',
    'lots', 'stockMoves', 'productions', 'forecasts', 'forecastRuns', 'listings', 'listingReports',
    'deals', 'orders', 'companyStats', 'auditLog', 'challenges', 'announcements',
]
# Non sauvegardées : présence en ligne et positions en direct (éphémères).
SUBCOLLECTIONS = {
    'users': ['addresses', 'documents', 'documentFiles'],
    'scans': ['photos'],
    'config': ['history'],
    'collections': ['messages', 'attachments'],
    'tickets': ['photos'],
    'deals': ['messages'],
    'challenges': ['participants'],
}


def call(url, body=None, token=None, method=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method=method or ('POST' if data else 'GET'))
    req.add_header('Content-Type', 'application/json')
    if token:
        req.add_header('Authorization', f'Bearer {token}')
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read() or b'{}')
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b'{}')


def root(emulator):
    return f'{EMULATOR if emulator else REAL}/projects/{PROJECT}/databases/(default)/documents'


def admin_token(emulator):
    email = os.environ.get('ECOFLOW_BACKUP_EMAIL', 'admin@ecoflow.tn')
    password = os.environ.get('ECOFLOW_BACKUP_PASSWORD', 'recycle26')
    url = f'{AUTH_EMULATOR if emulator else AUTH_REAL}:signInWithPassword?key={API_KEY}'
    code, r = call(url, {'email': email, 'password': password, 'returnSecureToken': True})
    if code != 200:
        sys.exit(f'Connexion administrateur impossible : {r.get("error", {}).get("message")}')
    return r['idToken']


def list_docs(base, path, token):
    """Tous les documents d'une collection (pagination) ; None si refusé."""
    docs, page = [], None
    while True:
        query = {'pageSize': 300, **({'pageToken': page} if page else {})}
        code, r = call(f'{base}/{path}?{urllib.parse.urlencode(query)}', token=token)
        if code != 200:
            return None
        docs += r.get('documents', [])
        page = r.get('nextPageToken')
        if not page:
            return docs


def export(target=None):
    emulator = bool(os.environ.get('ECOFLOW_EMULATOR'))
    base, token = root(emulator), admin_token(emulator)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%d-%H%M')
    out = target or os.path.join('backups', f'ecoflow-{PROJECT}-{stamp}')
    os.makedirs(out, exist_ok=True)
    manifest = {'project': PROJECT, 'exportedAt': stamp, 'collections': {}, 'refused': []}
    for col in COLLECTIONS:
        docs = list_docs(base, col, token)
        if docs is None:
            manifest['refused'].append(col)
            continue
        for d in list(docs):
            rel = d['name'].split('/documents/', 1)[1]
            for sub in SUBCOLLECTIONS.get(col, []):
                children = list_docs(base, f'{rel}/{sub}', token)
                if children is None:
                    manifest['refused'].append(f'{col}/*/{sub}')
                else:
                    docs += children
        rows = [{'path': d['name'].split('/documents/', 1)[1], 'fields': d.get('fields', {})} for d in docs]
        with open(os.path.join(out, f'{col}.json'), 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False)
        manifest['collections'][col] = len(rows)
    manifest['refused'] = sorted(set(manifest['refused']))
    with open(os.path.join(out, 'manifest.json'), 'w', encoding='utf-8') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    total = sum(manifest['collections'].values())
    print(f'✓ {total} documents dans {out}')
    if manifest['refused']:
        print('  refusé par les règles (non sauvegardé) :', ', '.join(manifest['refused']))
    return out


def rows_of(folder):
    manifest = json.load(open(os.path.join(folder, 'manifest.json'), encoding='utf-8'))
    for col in manifest['collections']:
        for row in json.load(open(os.path.join(folder, f'{col}.json'), encoding='utf-8')):
            yield row


def restore(folder):
    base, n = root(True), 0
    batch = []

    def flush():
        if batch:
            code, r = call(f'{base}:commit', {'writes': batch}, 'owner')
            if code != 200:
                sys.exit(f'Restauration interrompue : {code} {r.get("error", {}).get("message")}')
            batch.clear()

    for row in rows_of(folder):
        batch.append({'update': {'name': f'projects/{PROJECT}/databases/(default)/documents/{row["path"]}',
                                 'fields': row['fields']}})
        n += 1
        if len(batch) == 400:
            flush()
    flush()
    print(f'✓ {n} documents restaurés dans l’émulateur')


def verify(folder):
    base, missing, different = root(True), 0, 0
    rows = list(rows_of(folder))
    for row in rows:
        code, doc = call(f'{base}/{row["path"]}', token='owner')
        if code != 200:
            missing += 1
        elif doc.get('fields', {}) != row['fields']:
            different += 1
    print(f'{len(rows) - missing - different}/{len(rows)} documents identiques'
          f' ({missing} manquants, {different} différents)')
    sys.exit(0 if missing == different == 0 else 1)


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'export'
    arg = sys.argv[2] if len(sys.argv) > 2 else None
    if cmd != 'export' and not arg:
        sys.exit('Indique le dossier de sauvegarde.')
    {'export': lambda: export(arg), 'restore': lambda: restore(arg), 'verify': lambda: verify(arg)}[cmd]()
