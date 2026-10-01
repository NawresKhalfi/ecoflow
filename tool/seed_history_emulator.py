#!/usr/bin/env python3
"""Historique de démonstration pour la prévision (epic 10) — ÉMULATEUR UNIQUEMENT.

Crée 90 jours de collectes pesées (marquées `demo: true`) dans trois zones,
avec une saisonnalité hebdomadaire (pic le samedi) et une tendance, pour
entraîner et visualiser le modèle. N'agit que sur 127.0.0.1.

  python3 tool/seed_history_emulator.py          # créer
  python3 tool/seed_history_emulator.py clean    # supprimer
"""
import datetime, json, math, random, sys, urllib.request

B = 'http://127.0.0.1:8080/v1/projects/meteo-ba45f/databases/(default)/documents'
KARIM = 'VVmOCwgmM90U0mYwWeh6XD1BdxVx'
LEILA = 'aiffHHU29ii74Dor97f4v8rgAw01'
ZONES = {  # centre, rayon (km), volume moyen / jour (kg)
    'sousse': ((35.8256, 10.6084), 6, 14.0),
    'monastir': ((35.7643, 10.8113), 4, 6.0),
    'tunis': ((36.8065, 10.1815), 8, 9.0),
}
WEEK = [0.9, 1.0, 1.0, 1.05, 1.2, 1.6, 0.4]  # lundi → dimanche


def val(v):
    if v is None: return {'nullValue': None}
    if isinstance(v, bool): return {'booleanValue': v}
    if isinstance(v, int): return {'integerValue': str(v)}
    if isinstance(v, float): return {'doubleValue': v}
    if isinstance(v, datetime.datetime): return {'timestampValue': v.strftime('%Y-%m-%dT%H:%M:%SZ')}
    if isinstance(v, dict): return {'mapValue': {'fields': {k: val(x) for k, x in v.items()}}}
    return {'stringValue': str(v)}


def req(method, path, body=None):
    r = urllib.request.Request(f'{B}/{path}', data=None if body is None else json.dumps(body).encode(), method=method)
    r.add_header('Authorization', 'Bearer owner')
    r.add_header('Content-Type', 'application/json')
    with urllib.request.urlopen(r) as resp:
        return json.loads(resp.read() or b'{}')


def put(path, d): req('PATCH', path, {'fields': {k: val(v) for k, v in d.items()}})


def clean():
    n = 0
    for col in ('collections', 'estimates'):
        page = req('GET', f'{col}?pageSize=1000')
        for d in page.get('documents', []):
            if d['fields'].get('demo', {}).get('booleanValue'):
                req('DELETE', d['name'].split('/documents/')[1]); n += 1
    print(f'{n} documents supprimés')


def seed():
    rnd = random.Random(2026)
    today = datetime.datetime(2026, 10, 1, tzinfo=datetime.timezone.utc)
    n = 0
    for zone, ((lat, lng), radius, mean) in ZONES.items():
        for d in range(1, 91):
            day = today - datetime.timedelta(days=d)
            target = mean * WEEK[day.weekday()] * (1 + 0.004 * (90 - d))
            kg_left = max(0.0, rnd.gauss(target, target * 0.15))
            i = 0
            while kg_left > 0.3:
                kg = min(kg_left, rnd.uniform(1.5, 6.0))
                kg_left -= kg
                pet = round(kg * rnd.uniform(0.45, 0.7), 2)
                can = round(kg * rnd.uniform(0.1, 0.25), 2)
                card = round(kg - pet - can, 2)
                code = f'H{zone[:2].upper()}{d:03d}{i}'
                r = radius * math.sqrt(rnd.random()) / 111
                a = rnd.uniform(0, 2 * math.pi)
                point = {'lat': lat + r * math.cos(a), 'lng': lng + r * math.sin(a) / math.cos(math.radians(lat))}
                put(f'estimates/{code}', {'citizenUid': LEILA, 'status': 'weighed', 'demo': True,
                    'actualKg': {'pet_bottle': pet, 'can': can, 'cardboard': card},
                    'actualTotalKg': round(pet + can + card, 2), 'totalKg': round(kg, 2)})
                put(f'collections/hist_{code}', {'citizenUid': LEILA, 'collectorUid': KARIM, 'estimateCode': code,
                    'status': 'completed', 'demo': True, 'completedAt': day + datetime.timedelta(hours=11),
                    'createdAt': day, 'slotId': day.strftime('%Y-%m-%d') + '_10',
                    'place': {'point': point, 'address': 'Historique démo', 'zoneId': zone}, 'depositId': 'demo'})
                i += 1; n += 1
    print(f'{n} collectes pesées créées')


if __name__ == '__main__':
    clean() if len(sys.argv) > 1 and sys.argv[1] == 'clean' else seed()
