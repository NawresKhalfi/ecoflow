#!/usr/bin/env python3
"""Crée les comptes de démo EcoFlow sur le projet Firebase réel (meteo-ba45f).

Passe par l'API publique (clé web) et les règles Firestore, exactement comme
l'app : aucun accès administrateur n'est utilisé.

  python3 tool/seed_demo.py accounts   # étape 1 : comptes + profils
  python3 tool/seed_demo.py approve    # étape 2 : après avoir mis
                                       # role = "admin" sur admin@ dans la console :
                                       # valide Karim et GreenPlast, crée le
                                       # catalogue de récompenses de démo (E08)

Un administrateur ne peut pas s'auto-attribuer ce rôle (US-003) : le compte
admin@ est donc créé en citoyen, puis promu à la main dans la console.
"""
import json
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone

PROJECT = 'meteo-ba45f'
API_KEY = 'AIzaSyCLSoHoFwebyGvjJHgl_mRXwByiu53KsKY'  # clé web publique (firebase_options.dart)
PASSWORD = 'recycle26'
AUTH = 'https://identitytoolkit.googleapis.com/v1/accounts'
DB = f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents'

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


if __name__ == '__main__':
    {'accounts': accounts, 'approve': approve}[sys.argv[1] if len(sys.argv) > 1 else 'accounts']()
