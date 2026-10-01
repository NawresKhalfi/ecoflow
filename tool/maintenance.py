#!/usr/bin/env python3
"""Tâches planifiées d'EcoFlow sans offre Blaze (exécutées chaque nuit par la CI).

  python3 tool/maintenance.py [--dry-run]

1. Purge des photos de scan expirées (US-021) : conservation 90 jours.
2. Expiration des EcoPoints (US-078) : les gains plus anciens que la durée de
   validité (config/points.expiryMonths, 12 mois par défaut) sont déduits en
   FIFO, même si le citoyen n'ouvre pas son wallet — même calcul que
   `duePointsToExpire` (lib/features/wallet/domain/wallet.dart).

Compte administrateur : ECOFLOW_BACKUP_EMAIL / ECOFLOW_BACKUP_PASSWORD
(voir tool/backup.py). ECOFLOW_EMULATOR=1 vise l'émulateur local.
"""
import calendar
import os
import sys
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.dirname(__file__))
from backup import PROJECT, admin_token, call, list_docs, root  # noqa: E402

DRY = '--dry-run' in sys.argv
DOCS = f'projects/{PROJECT}/databases/(default)/documents'


def value(field):
    if field is None:
        return None
    for key in ('integerValue', 'doubleValue'):
        if key in field:
            return float(field[key])
    for key in ('stringValue', 'timestampValue', 'booleanValue'):
        if key in field:
            return field[key]
    return None


def when(field):
    v = value(field)
    return datetime.fromisoformat(v.replace('Z', '+00:00')) if isinstance(v, str) else None


def add_months(d, months):
    """Comme DateTime(y, m + months, j) en Dart : un 31 qui déborde passe au mois suivant."""
    m = d.month - 1 + months
    year, month = d.year + m // 12, m % 12 + 1
    last = calendar.monthrange(year, month)[1]
    return d.replace(year=year, month=month, day=min(d.day, last)) + timedelta(days=max(0, d.day - last))


def commit(base, token, writes, what):
    if DRY or not writes:
        return
    code, r = call(f'{base}:commit', {'writes': writes}, token)
    if code != 200:
        print(f'  ✗ {what} : {code} {r.get("error", {}).get("message")}')


def purge_photos(base, token, now):
    scans, photos = 0, 0
    for scan in list_docs(base, 'scans', token) or []:
        f = scan.get('fields', {})
        expires = when(f.get('expiresAt'))
        if not expires or expires >= now or value(f.get('photosPurged')) is True:
            continue
        rel = scan['name'].split('/documents/', 1)[1]
        children = list_docs(base, f'{rel}/photos', token) or []
        writes = [{'delete': c['name']} for c in children]
        writes.append({'update': {'name': scan['name'], 'fields': {'photosPurged': {'booleanValue': True}}},
                       'updateMask': {'fieldPaths': ['photosPurged']}})
        commit(base, token, writes, f'purge {rel}')
        scans, photos = scans + 1, photos + len(children)
    print(f'✓ photos expirées : {photos} supprimées sur {scans} scans')


def expire_points(base, token, now):
    code, cfg = call(f'{base}/config/points', token=token)
    months = int(value(cfg.get('fields', {}).get('expiryMonths')) or 12) if code == 200 else 12
    entries = {}
    for e in list_docs(base, 'pointEntries', token) or []:
        f = e.get('fields', {})
        entries.setdefault(value(f.get('uid')), []).append(f)
    total, wallets = 0, 0
    for w in list_docs(base, 'wallets', token) or []:
        uid = w['name'].rsplit('/', 1)[1]
        f = w.get('fields', {})
        earned, spent, expired = (int(value(f.get(k)) or 0) for k in ('earned', 'spent', 'expired'))
        balance = earned - spent - expired
        old = sum(int(value(e.get('points')) or 0) for e in entries.get(uid, [])
                  if (value(e.get('points')) or 0) > 0 and value(e.get('status')) == 'credited'
                  and when(e.get('createdAt')) and add_months(when(e['createdAt']), months) <= now)
        due = max(0, min(old - spent - expired, balance))
        if due == 0:
            continue
        eid = f'x_{uid[:8]}_{now:%Y%m%d}'
        commit(base, token, [
            {'update': {'name': f'{DOCS}/pointEntries/{eid}', 'fields': {
                'uid': {'stringValue': uid}, 'type': {'stringValue': 'expire'},
                'points': {'integerValue': str(-due)}, 'status': {'stringValue': 'credited'},
                'collectionId': {'nullValue': None}, 'redemptionId': {'nullValue': None},
                'kg': {'doubleValue': 0}, 'byCategory': {'mapValue': {}},
                'flags': {'arrayValue': {}}, 'label': {'stringValue': 'Expiration automatique'}}},
             'currentDocument': {'exists': False},
             'updateTransforms': [{'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'}]},
            {'update': {'name': w['name'], 'fields': {'expired': {'integerValue': str(expired + due)},
                                                      'lastEntryId': {'stringValue': eid}}},
             'updateMask': {'fieldPaths': ['expired', 'lastEntryId']}},
        ], f'expiration {uid}')
        total, wallets = total + due, wallets + 1
    print(f'✓ EcoPoints expirés : {total} points sur {wallets} wallets (validité {months} mois)')


if __name__ == '__main__':
    emulator = bool(os.environ.get('ECOFLOW_EMULATOR'))
    base, token = root(emulator), admin_token(emulator)
    now = datetime.now(timezone.utc)
    if DRY:
        print('(simulation : aucune écriture)')
    purge_photos(base, token, now)
    expire_points(base, token, now)
