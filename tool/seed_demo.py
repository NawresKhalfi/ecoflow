#!/usr/bin/env python3
"""Crée les comptes de démo EcoFlow sur le projet Firebase réel (meteo-ba45f).

Passe par l'API publique (clé web) et les règles Firestore, exactement comme
l'app : aucun accès administrateur n'est utilisé.

  python3 tool/seed_demo.py accounts   # étape 1 : comptes + profils
  python3 tool/seed_demo.py approve    # étape 2 : après avoir mis
                                       # role = "admin" sur admin@ dans la console :
                                       # valide Karim et GreenPlast, crée le
                                       # catalogue de récompenses de démo (E08)
  python3 tool/seed_demo.py history    # étape 3 : trois collectes pesées de Leila,
                                       # créditées (pesée datée par le serveur)
  python3 tool/seed_demo.py pickup     # une collecte pesée de plus, aujourd'hui
  python3 tool/seed_demo.py resume     # crédite une collecte confirmée restée sans points

Un administrateur ne peut pas s'auto-attribuer ce rôle (US-003) : le compte
admin@ est donc créé en citoyen, puis promu à la main dans la console.
"""
import json
import os
import random
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

PROJECT = 'meteo-ba45f'
API_KEY = 'AIzaSyCLSoHoFwebyGvjJHgl_mRXwByiu53KsKY'  # clé web publique (firebase_options.dart)
PASSWORD = 'recycle26'
AUTH = 'https://identitytoolkit.googleapis.com/v1/accounts'
DB = f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents'
if os.environ.get('ECOFLOW_EMULATOR'):  # répétition à blanc sur l'Emulator Suite
    AUTH = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts'
    DB = f'http://127.0.0.1:8080/v1/projects/{PROJECT}/databases/(default)/documents'

ACCOUNTS = [
    ('leila@ecoflow.tn', 'Leila Trabelsi', 'citizen'),
    ('karim@ecoflow.tn', 'Karim Collecteur', 'collector'),
    ('greenplast@ecoflow.tn', 'GreenPlast SARL', 'recycler'),
    ('admin@ecoflow.tn', 'Sarra Admin', 'citizen'),  # promu admin dans la console
]


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


def value(v):
    if v is None:
        return {'nullValue': None}
    if isinstance(v, bool):
        return {'booleanValue': v}
    if isinstance(v, int):
        return {'integerValue': str(v)}
    if isinstance(v, float):
        return {'doubleValue': v}
    if isinstance(v, list):
        return {'arrayValue': {'values': [value(x) for x in v]}}
    if isinstance(v, datetime):
        return {'timestampValue': v.isoformat().replace('+00:00', 'Z')}
    if isinstance(v, dict):
        return {'mapValue': {'fields': {k: value(x) for k, x in v.items()}}}
    return {'stringValue': str(v)}


def sign_in(email, name):
    """Connexion, ou inscription si le compte n'existe pas encore."""
    body = {'email': email, 'password': PASSWORD, 'returnSecureToken': True}
    code, r = call(f'{AUTH}:signInWithPassword?key={API_KEY}', body)
    if code != 200:
        code, r = call(f'{AUTH}:signUp?key={API_KEY}', {**body, 'displayName': name})
        if code != 200:
            sys.exit(f'{email}: {r.get("error", {}).get("message")}')
        print(f'  + compte créé {email}')
    return r['localId'], r['idToken']


def set_doc(path, fields, token, mask=None):
    url = f'{DB}/{path}'
    if mask:
        url += '?' + '&'.join(f'updateMask.fieldPaths={f}' for f in mask)
    code, r = call(url, {'fields': {k: value(v) for k, v in fields.items()}}, token, 'PATCH')
    if code != 200:
        sys.exit(f'{path}: {code} {r.get("error", {}).get("message")}')


def get_doc(path, token):
    code, r = call(f'{DB}/{path}', token=token)
    return r.get('fields') if code == 200 else None


def accounts():
    now = datetime.now(timezone.utc)
    for email, name, role in ACCOUNTS:
        uid, token = sign_in(email, name)
        if get_doc(f'users/{uid}', token):
            print(f'  = profil existant {email}')
            continue
        set_doc(f'users/{uid}', {
            'displayName': name,
            'email': email,
            'phoneNumber': None,
            'role': role,
            'languageCode': 'fr',
            'status': 'active',
            'verificationStatus': 'notRequired' if role == 'citizen' else 'notSubmitted',
            'notificationPreferences': {'collectionStatus': True, 'marketplace': True, 'points': True},
            'consent': {'version': '2026-09', 'acceptedAt': now},
            'createdAt': now,
        }, token)
        print(f'  + profil {role} {email} ({uid})')
        if role == 'recycler':
            set_doc(f'companies/{uid}', {
                'legalName': name, 'city': 'Sousse', 'status': 'pending',
                'ownerUid': uid, 'rejectionReason': None,
            }, token)
            print('  + entreprise GreenPlast (en attente)')


def approve():
    admin_uid, admin = sign_in('admin@ecoflow.tn', 'Sarra Admin')
    me = get_doc(f'users/{admin_uid}', admin) or {}
    if me.get('role', {}).get('stringValue') != 'admin':
        sys.exit('admin@ecoflow.tn n’a pas encore role = "admin" (à modifier dans la console).')
    now = datetime.now(timezone.utc)
    for email, name in [('karim@ecoflow.tn', 'Karim Collecteur'), ('greenplast@ecoflow.tn', 'GreenPlast SARL')]:
        uid, _ = sign_in(email, name)
        review = {'verificationStatus': 'approved', 'reviewedBy': admin_uid, 'reviewedAt': now}
        set_doc(f'users/{uid}', review, admin, mask=review.keys())
        print(f'  ✓ {email} validé')
        if email.startswith('greenplast'):
            set_doc(f'companies/{uid}', {'status': 'approved'}, admin, mask=['status'])
            print('  ✓ entreprise GreenPlast validée')
    catalogue(admin)


PARTNERS = {
    'cafe-medina': {'name': 'Café de la Médina', 'city': 'Sousse', 'emoji': '☕', 'active': True},
    'green-shop': {'name': 'Green Shop Sousse', 'city': 'Sousse', 'emoji': '🛍️', 'active': True},
}
REWARDS = {
    'cafe': ('cafe-medina', 'Café offert', 'Un café ou un thé à la menthe.', 'discount', '☕', 50, 20),
    'arbre': ('green-shop', 'Planter un arbre', 'Don à une association locale.', 'donation', '🌳', 100, None),
    'sac': ('green-shop', 'Sac en PET recyclé', 'Sac cabas fabriqué à partir de bouteilles.', 'product', '👜', 150, None),
    'remise': ('green-shop', '-15 % en boutique', 'Sur tout le rayon zéro déchet.', 'discount', '🏷️', 300, None),
}


def catalogue(admin):
    for pid, p in PARTNERS.items():
        set_doc(f'partners/{pid}', p, admin)
    for rid, (pid, title, desc, kind, emoji, cost, stock) in REWARDS.items():
        set_doc(f'rewards/{rid}', {
            'partnerId': pid, 'partnerName': PARTNERS[pid]['name'], 'title': title,
            'description': desc, 'kind': kind, 'emoji': emoji, 'cost': cost,
            'stock': stock, 'active': True,
        }, admin)
    print(f'  ✓ catalogue : {len(PARTNERS)} partenaires, {len(REWARDS)} offres')


# --- Étape 3 : historique de collectes (E13) ---------------------------------
# Chaque écriture passe par les règles déployées, dans l'ordre de l'app :
# estimation et demande (Leila), prise en charge, preuve et pesée (Karim),
# confirmation et EcoPoints (Leila), gain du collecteur (Karim).
ROOT = f'projects/{PROJECT}/databases/(default)/documents'
PRICES = {'pet_bottle': .6, 'can': 3.0, 'cardboard': .2, 'paper': .15, 'glass': .1}
MULT = {'pet_bottle': 1.5, 'can': 2.0, 'cardboard': 1.0, 'paper': 1.0, 'glass': 1.2}


def write(path, fields, exists=None, stamp=()):
    w = {'update': {'name': f'{ROOT}/{path}', 'fields': {k: value(v) for k, v in fields.items()}},
         'updateMask': {'fieldPaths': list(fields)}}
    if exists is not None:
        w['currentDocument'] = {'exists': exists}
    if exists is False:
        del w['updateMask']
    if stamp:
        w['updateTransforms'] = [{'fieldPath': f, 'setToServerValue': 'REQUEST_TIME'} for f in stamp]
    return w


def commit(token, writes, what):
    code, r = call(f'{DB}:commit', {'writes': writes}, token)
    if code != 200:
        sys.exit(f'{what}: {code} {r.get("error", {}).get("message")}')


def number(fields, key, default=0):
    v = (fields or {}).get(key, {})
    return float(v.get('doubleValue', v.get('integerValue', default)))


def collect(leila, luid, karim, kuid, kg, estimated_kg, day):
    """Une collecte complète, pesée le jour [day] ; renvoie les points gagnés."""
    code = 'DEMO' + ''.join(random.choice('ABCDEFGHJKMNPQRSTUVWXYZ23456789') for _ in range(4))
    cid = 'demo' + code[4:].lower() + day.strftime('%m%d')
    lines = [{'category': c, 'count': 0, 'kg': estimated_kg[c], 'price': PRICES[c], 'method': 'manual'}
             for c in estimated_kg]
    est_total = sum(estimated_kg.values())
    est_dt = round(sum(estimated_kg[c] * PRICES[c] for c in estimated_kg), 3)
    commit(leila, [write(f'estimates/{code}', {
        'citizenUid': luid, 'lines': lines, 'totalKg': est_total, 'totalDt': est_dt, 'confidence': .85,
        'priceScaleId': 'default', 'status': 'estimated', 'createdAt': day - timedelta(hours=3)}, exists=False)],
        'estimation')
    commit(leila, [write(f'collections/{cid}', {
        'citizenUid': luid, 'estimateCode': code,
        'place': {'point': {'lat': 35.8256, 'lng': 10.6084}, 'address': 'Rue de Monastir, Sousse', 'zoneId': 'sousse'},
        'zoneId': 'sousse', 'slotId': day.strftime('%Y-%m-%d_10'), 'instructions': '', 'hasInstructionPhoto': False,
        'estimatedKg': est_total, 'estimatedDt': est_dt, 'categories': list(estimated_kg), 'status': 'searching',
        'refusedBy': [], 'recurrence': 'none', 'lateCancellation': False, 'rated': False,
        'createdAt': day - timedelta(hours=3)}, exists=False),
        write(f'estimates/{code}', {'requestId': cid})], 'demande')
    commit(karim, [write(f'collections/{cid}', {'status': 'accepted', 'collectorUid': kuid, 'proposedCollectorUid': None,
                                                'acceptedAt': day - timedelta(hours=2), 'updatedAt': day})], 'prise en charge')
    for st in ['onTheWay', 'arrived', 'inProgress']:
        commit(karim, [write(f'collections/{cid}', {'status': st, st + 'At': day, 'updatedAt': day})], st)
    commit(karim, [write(f'collections/{cid}/attachments/proof', {'uid': kuid, 'data': 'AQID', 'takenAt': day}, exists=False),
                   write(f'collections/{cid}', {'hasProof': True, 'updatedAt': day})], 'preuve')
    total = sum(kg.values())
    final_dt = round(sum(kg[c] * PRICES[c] for c in kg), 3)
    # Date de pesée posée par le serveur (exigé par les règles).
    commit(karim, [write(f'estimates/{code}', {'status': 'weighed', 'actualKg': kg, 'actualTotalKg': total,
                                               'finalDt': final_dt, 'collectorUid': kuid}, stamp=['weighedAt']),
                   write(f'collections/{cid}', {'status': 'handedOver', 'collectorUid': kuid,
                                                'handedOverAt': day, 'updatedAt': day})], 'pesée')
    commit(leila, [write(f'collections/{cid}', {'status': 'completed', 'completedAt': day, 'updatedAt': day})],
           'confirmation')
    credit(leila, luid, karim, kuid, cid, kg, est_total, final_dt, day)


def credit(leila, luid, karim, kuid, cid, kg, est_total, final_dt, day):
    """EcoPoints du citoyen et gain du collecteur pour une collecte confirmée."""
    total = sum(kg.values())
    # EcoPoints : même calcul que computeAward et les règles (barème par défaut).
    w = get_doc(f'wallets/{luid}', leila)
    first = number(w, 'collections') == 0
    points = int(sum(kg[c] * MULT[c] for c in kg) * 10 + 1e-6) + (50 if first else 0) + (20 if total >= 10 else 0)
    last = (w or {}).get('lastEarnAt', {}).get('timestampValue', '')
    same_day = last[:10] == datetime.now(timezone.utc).strftime('%Y-%m-%d')
    day_count = int(number(w, 'dayCount')) + 1 if same_day else 1
    # Anti-fraude (US-075) : au-delà de 3 crédits par jour, points en attente.
    held = day_count > 3 or total > 200 or total > est_total * 3
    wallet = {'earned': int(number(w, 'earned')) + (0 if held else points), 'spent': int(number(w, 'spent')),
              'expired': int(number(w, 'expired')), 'held': int(number(w, 'held')) + (points if held else 0),
              'collections': int(number(w, 'collections')) + 1, 'kg': number(w, 'kg') + total,
              'dayCount': day_count, 'lastEntryId': f'c_{cid}',
              'lastRedemptionId': None, 'referredBy': None, 'referralCode': None,
              'frozen': False, 'frozenReason': None}
    if w:
        for k in ['lastRedemptionId', 'referredBy', 'referralCode', 'frozenReason']:
            wallet[k] = (w.get(k) or {}).get('stringValue')
    commit(leila, [write(f'pointEntries/c_{cid}', {
        'uid': luid, 'type': 'earn', 'points': points, 'status': 'held' if held else 'credited', 'collectionId': cid,
        'redemptionId': None, 'kg': total, 'byCategory': kg, 'flags': [], 'label': None}, exists=False,
        stamp=['createdAt']),
        write(f'wallets/{luid}', wallet, stamp=['lastEarnAt'])], 'EcoPoints')
    b = get_doc(f'collectorBalances/{kuid}', karim)
    commit(karim, [write(f'earnings/{cid}', {'collectorUid': kuid, 'amountDt': final_dt, 'kg': total, 'createdAt': day},
                         exists=False),
                   write(f'collectorBalances/{kuid}', {'earnedDt': number(b, 'earnedDt') + final_dt,
                                                       'withdrawnDt': number(b, 'withdrawnDt'), 'lastEarningId': cid,
                                                       'lastPayoutId': (b or {}).get('lastPayoutId', {}).get('stringValue')})],
           'gain collecteur')
    note = ' en attente de contrôle (plus de 3 crédits aujourd’hui)' if held else ''
    print(f'  ✓ {day:%d/%m} : {total:g} kg pesés, {final_dt:g} DT, +{points} EcoPoints{note} ({cid})')


def history():
    luid, leila = sign_in('leila@ecoflow.tn', 'Leila Trabelsi')
    kuid, karim = sign_in('karim@ecoflow.tn', 'Karim Collecteur')
    if get_doc(f'wallets/{luid}', leila):
        sys.exit('Leila a déjà un historique (wallet existant) : utiliser « pickup ».')
    now = datetime.now(timezone.utc)
    collect(leila, luid, karim, kuid, {'pet_bottle': 5.0}, {'pet_bottle': 4.5}, now - timedelta(days=58))
    collect(leila, luid, karim, kuid, {'cardboard': 6.0, 'can': 1.5}, {'cardboard': 5.0, 'can': 2.0},
            now - timedelta(days=23))
    collect(leila, luid, karim, kuid, {'pet_bottle': 4.0, 'glass': 6.0, 'can': 2.0},
            {'pet_bottle': 4.0, 'glass': 5.0, 'can': 2.0}, now - timedelta(days=2))


def resume():
    """Crédite les collectes confirmées de Leila restées sans EcoPoints."""
    luid, leila = sign_in('leila@ecoflow.tn', 'Leila Trabelsi')
    kuid, karim = sign_in('karim@ecoflow.tn', 'Karim Collecteur')
    q = {'structuredQuery': {'from': [{'collectionId': 'collections'}], 'where': {'fieldFilter': {
        'field': {'fieldPath': 'citizenUid'}, 'op': 'EQUAL', 'value': {'stringValue': luid}}}}}
    _, rows = call(f'{DB}:runQuery', q, leila)
    for row in rows:
        d = row.get('document')
        if not d or d['fields'].get('status', {}).get('stringValue') != 'completed':
            continue
        cid = d['name'].rsplit('/', 1)[1]
        if get_doc(f'pointEntries/c_{cid}', leila):
            continue
        est = get_doc(f'estimates/{d["fields"]["estimateCode"]["stringValue"]}', leila)
        kg = {k: number(v and {'x': v}, 'x') for k, v in est['actualKg']['mapValue']['fields'].items()}
        day = datetime.fromisoformat(est['weighedAt']['timestampValue'].replace('Z', '+00:00'))
        credit(leila, luid, karim, kuid, cid, kg, number(est, 'totalKg'), number(est, 'finalDt'), day)


def pickup():
    luid, leila = sign_in('leila@ecoflow.tn', 'Leila Trabelsi')
    kuid, karim = sign_in('karim@ecoflow.tn', 'Karim Collecteur')
    collect(leila, luid, karim, kuid, {'pet_bottle': 3.0, 'paper': 2.5}, {'pet_bottle': 3.0, 'paper': 2.0},
            datetime.now(timezone.utc))


if __name__ == '__main__':
    commands = {'accounts': accounts, 'approve': approve, 'history': history, 'pickup': pickup,
                'resume': resume}
    commands[sys.argv[1] if len(sys.argv) > 1 else 'accounts']()
