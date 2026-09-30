#!/usr/bin/env python3
"""Sonde des règles Firestore d'EcoFlow (epics 4-5) contre l'ÉMULATEUR local.

`flutter test` utilise un faux Firestore qui n'applique pas les règles : ce
script rejoue les écritures réelles de l'application (citoyen, collecteur,
recycleur) avec de vrais jetons et vérifie ce qui doit être accepté ou refusé.

Usage :
  firebase emulators:start --only auth,firestore   # JDK 21 requis
  python3 tool/firestore_rules_probe.py

N'agit que sur 127.0.0.1 (émulateurs), jamais sur le projet réel.
"""
import json, urllib.request, datetime, random, string
P='meteo-ba45f'; ROOT=f'projects/{P}/databases/(default)/documents'; B='http://127.0.0.1:8080/v1/'+ROOT
AUTH='http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/'
def http(url, body=None, token=None, method=None):
    r=urllib.request.Request(url, data=None if body is None else json.dumps(body).encode(), method=method or ('POST' if body is not None else 'GET'))
    r.add_header('Content-Type','application/json')
    if token: r.add_header('Authorization','Bearer '+token)
    try:
        with urllib.request.urlopen(r) as resp: return resp.status, json.loads(resp.read() or b'{}')
    except urllib.error.HTTPError as e: return e.code, json.loads(e.read() or b'{}')
def val(v):
    if v is None: return {'nullValue':None}
    if isinstance(v,bool): return {'booleanValue':v}
    if isinstance(v,int): return {'integerValue':str(v)}
    if isinstance(v,float): return {'doubleValue':v}
    if isinstance(v,str): return {'stringValue':v}
    if isinstance(v,datetime.datetime): return {'timestampValue':v.strftime('%Y-%m-%dT%H:%M:%SZ')}
    if isinstance(v,list): return {'arrayValue':{'values':[val(x) for x in v]}}
    if isinstance(v,dict): return {'mapValue':{'fields':{k:val(x) for k,x in v.items()}}}
    raise TypeError(v)
def fields(d): return {k:val(v) for k,v in d.items()}
def login(email, pw='recycle26'):
    s,a=http(AUTH+'accounts:signInWithPassword?key=x',{'email':email,'password':pw,'returnSecureToken':True})
    if s!=200:
        s,a=http(AUTH+'accounts:signUp?key=x',{'email':email,'password':pw,'returnSecureToken':True})
    return a['idToken'], a['localId']
def owner_set(path, d): http(f'{B}/{path}', {'fields':fields(d)}, 'owner', 'PATCH')
def upd(path, d, exists=True):
    w={'update':{'name':f'{ROOT}/{path}','fields':fields(d)},'updateMask':{'fieldPaths':list(d.keys())}}
    if exists: w['currentDocument']={'exists':True}
    return w
def create(path, d): return {'update':{'name':f'{ROOT}/{path}','fields':fields(d)},'currentDocument':{'exists':False}}
def commit(token, writes): return http(B+':commit', {'writes':writes}, token)[0]
results=[]
def check(label, token, writes, expect):
    s=commit(token, writes); ok=(s==200)==expect
    results.append(ok); print(('PASS' if ok else 'FAIL'), label, '→', 'allowed' if s==200 else f'denied ({s})')

# Comptes dédiés à la sonde (jamais les comptes de démonstration).
leila, luid = login('probe-citizen@ecoflow.test')
karim, kuid = login('probe-collector@ecoflow.test')
rec, ruid = login('probe-recycler@ecoflow.test')
owner_set(f'users/{luid}', {'displayName':'Probe citizen','role':'citizen','status':'active','verificationStatus':'notRequired'})
owner_set(f'users/{kuid}', {'displayName':'Probe collector','role':'collector','status':'active','verificationStatus':'approved'})
owner_set(f'users/{ruid}', {'displayName':'GreenPlast','role':'recycler','status':'active','verificationStatus':'approved'})
owner_set(f'companies/{ruid}', {'legalName':'GreenPlast','city':'Sousse','status':'approved','ownerUid':ruid})
code=''.join(random.choice('ABCDEFGHJKMNPQRSTUVWXYZ23456789') for _ in range(8))
cid='probe'+code.lower()
now=datetime.datetime.now(datetime.UTC)
line={'category':'can','count':3,'kg':2.0,'price':4.0,'method':'container'}
check('citizen creates estimate', leila, [create(f'estimates/{code}', {'citizenUid':luid,'lines':[line],'totalKg':2.0,'totalDt':8.0,'confidence':.8,'priceScaleId':'default','status':'estimated','createdAt':now})], True)
slot='2026-10-02_10'
check('citizen creates request (+counter, +estimate link)', leila, [
  create(f'collections/{cid}', {'citizenUid':luid,'estimateCode':code,'place':{'point':{'lat':35.8256,'lng':10.6084},'address':'Rue probe','zoneId':'sousse'},'zoneId':'sousse','slotId':slot,'instructions':'','hasInstructionPhoto':False,'estimatedKg':2.0,'estimatedDt':8.0,'categories':['can'],'status':'searching','refusedBy':[],'recurrence':'none','lateCancellation':False,'rated':False,'createdAt':now}),
  upd(f'estimates/{code}', {'requestId':cid})], True)
s,q=http(B+':runQuery', {'structuredQuery':{'from':[{'collectionId':'collections'}],'where':{'fieldFilter':{'field':{'fieldPath':'status'},'op':'IN','value':{'arrayValue':{'values':[val('searching'),val('noCollector')]}}}}}}, karim)
results.append(s==200); print('PASS' if s==200 else 'FAIL', 'collector lists open missions →', s)
check('citizen cannot assign a collector', leila, [upd(f'collections/{cid}', {'collectorUid':luid})], False)
check('collector accepts (locked)', karim, [upd(f'collections/{cid}', {'status':'accepted','collectorUid':kuid,'proposedCollectorUid':None,'acceptedAt':now,'updatedAt':now})], True)
check('collector cannot skip to arrived', karim, [upd(f'collections/{cid}', {'status':'arrived'})], False)
for st in ['onTheWay','arrived','inProgress']:
    check(f'collector → {st}', karim, [upd(f'collections/{cid}', {'status':st, st+'At':now, 'updatedAt':now})], True)
weigh=[upd(f'estimates/{code}', {'status':'weighed','actualKg':{'can':2.5},'actualTotalKg':2.5,'finalDt':10.0,'collectorUid':kuid,'weighedAt':now}),
       upd(f'collections/{cid}', {'status':'handedOver','collectorUid':kuid,'handedOverAt':now,'updatedAt':now})]
check('handover WITHOUT proof photo is refused', karim, weigh, False)
check('collector saves proof photo', karim, [create(f'collections/{cid}/attachments/proof', {'uid':kuid,'data':'AQID','takenAt':now}), upd(f'collections/{cid}', {'hasProof':True,'updatedAt':now})], True)
check('weighing + handover in one batch', karim, weigh, True)
check('citizen confirms (completed)', leila, [upd(f'collections/{cid}', {'status':'completed','completedAt':now,'updatedAt':now})], True)
check('earning with WRONG amount refused', karim, [create(f'earnings/{cid}', {'collectorUid':kuid,'amountDt':99.0,'kg':2.5,'createdAt':now}), upd(f'collectorBalances/{kuid}', {'earnedDt':99.0,'withdrawnDt':0.0,'lastEarningId':cid,'lastPayoutId':None}, exists=False)], False)
check('earning without balance update refused', karim, [create(f'earnings/{cid}', {'collectorUid':kuid,'amountDt':10.0,'kg':2.5,'createdAt':now})], False)
check('balance inflated beyond earning refused', karim, [create(f'earnings/{cid}', {'collectorUid':kuid,'amountDt':10.0,'kg':2.5,'createdAt':now}), upd(f'collectorBalances/{kuid}', {'earnedDt':30.0,'withdrawnDt':0.0,'lastEarningId':cid,'lastPayoutId':None}, exists=False)], False)
check('earning = final weighed value (+balance)', karim, [create(f'earnings/{cid}', {'collectorUid':kuid,'amountDt':10.0,'kg':2.5,'createdAt':now}), upd(f'collectorBalances/{kuid}', {'earnedDt':10.0,'withdrawnDt':0.0,'lastEarningId':cid,'lastPayoutId':None}, exists=False)], True)
check('payout below 20 DT refused', karim, [create(f'payouts/p{code}a', {'collectorUid':kuid,'amountDt':10.0,'method':'cash','status':'requested','requestedAt':now}), upd(f'collectorBalances/{kuid}', {'earnedDt':10.0,'withdrawnDt':10.0,'lastEarningId':cid,'lastPayoutId':f'p{code}a'})], False)
check('payout above balance refused (25 > 10)', karim, [create(f'payouts/p{code}b', {'collectorUid':kuid,'amountDt':25.0,'method':'cash','status':'requested','requestedAt':now}), upd(f'collectorBalances/{kuid}', {'earnedDt':10.0,'withdrawnDt':25.0,'lastEarningId':cid,'lastPayoutId':f'p{code}b'})], False)
owner_set(f'collectorBalances/{kuid}', {'earnedDt':40.0,'withdrawnDt':0.0,'lastEarningId':cid,'lastPayoutId':None})
check('payout within balance (25 <= 40)', karim, [create(f'payouts/p{code}b', {'collectorUid':kuid,'amountDt':25.0,'method':'cash','status':'requested','requestedAt':now}), upd(f'collectorBalances/{kuid}', {'earnedDt':40.0,'withdrawnDt':25.0,'lastEarningId':cid,'lastPayoutId':f'p{code}b'})], True)
check('balance tampering alone refused', karim, [upd(f'collectorBalances/{kuid}', {'earnedDt':999.0,'withdrawnDt':25.0,'lastEarningId':cid,'lastPayoutId':f'p{code}b'})], False)
check('deposit to approved recycler (+mission link)', karim, [create(f'deposits/d{code}', {'collectorUid':kuid,'recyclerUid':ruid,'recyclerName':'GreenPlast','missionIds':[cid],'byCategoryKg':{'can':2.5},'totalKg':2.5,'status':'pending','createdAt':now}), upd(f'collections/{cid}', {'depositId':f'd{code}','updatedAt':now})], True)
check('collector cannot confirm own deposit', karim, [upd(f'deposits/d{code}', {'status':'confirmed','note':'','reviewedAt':now})], False)
check('recycler confirms reception', rec, [upd(f'deposits/d{code}', {'status':'confirmed','note':'OK','reviewedAt':now})], True)

# --- Refus d'une proposition et absence du citoyen (US-044, US-053) ---
code2=''.join(random.choice('ABCDEFGHJKMNPQRSTUVWXYZ23456789') for _ in range(8)); cid2='probe'+code2.lower()
check('citizen creates 2nd estimate', leila, [create(f'estimates/{code2}', {'citizenUid':luid,'lines':[line],'totalKg':2.0,'totalDt':8.0,'confidence':.8,'priceScaleId':'default','status':'estimated','createdAt':now})], True)
check('citizen creates 2nd request', leila, [create(f'collections/{cid2}', {'citizenUid':luid,'estimateCode':code2,'place':{'point':{'lat':35.8256,'lng':10.6084},'address':'Rue probe 2','zoneId':'sousse'},'zoneId':'sousse','slotId':slot,'instructions':'','hasInstructionPhoto':False,'estimatedKg':2.0,'estimatedDt':8.0,'categories':['can'],'status':'searching','refusedBy':[],'recurrence':'none','lateCancellation':False,'rated':False,'createdAt':now})], True)
check('citizen matching proposes to collector', leila, [upd(f'collections/{cid2}', {'status':'proposed','proposedCollectorUid':kuid,'proposedAt':now,'searchRadiusKm':5.0})], True)
check('collector refuses the proposal', karim, [upd(f'collections/{cid2}', {'status':'searching','proposedCollectorUid':None,'refusedBy':[kuid],'updatedAt':now})], True)
check('collector accepts open request', karim, [upd(f'collections/{cid2}', {'status':'accepted','collectorUid':kuid,'proposedCollectorUid':None,'acceptedAt':now,'updatedAt':now})], True)
check('no-show refused before arrival', karim, [upd(f'collections/{cid2}', {'status':'cancelled','cancelledBy':'collector','cancelReason':'citizenAbsent'})], False)
for st in ['onTheWay','arrived']:
    check(f'collector -> {st} (2)', karim, [upd(f'collections/{cid2}', {'status':st, st+'At':now})], True)
check('no-show after arrival + ticket', karim, [
  create(f'tickets/t{code2}', {'collectionId':cid2,'reporterUid':kuid,'reporterRole':'collector','reason':'citizenAbsent','description':'','photoCount':0,'status':'open','createdAt':now}),
  upd(f'collections/{cid2}', {'status':'cancelled','cancelledBy':'collector','cancelReason':'citizenAbsent','noShowTicketId':f't{code2}','cancelledAt':now})], True)

check('non-admin cannot write optimization history', karim, [create(f'config/optimization/history/h{code}', {'maxDetourKm':99.0,'by':kuid})], False)

# Nettoyage : l'émulateur reste utilisable pour la démonstration.
for path in [f'estimates/{code}', f'estimates/{code2}', f'collections/{cid}', f'collections/{cid2}',
             f'collections/{cid}/attachments/proof', f'earnings/{cid}', f'payouts/p{code}b',
             f'deposits/d{code}', f'tickets/t{code2}', f'slotCounters/sousse__{slot}',
             f'collectorBalances/{kuid}', f'companies/{ruid}']:
    http(f'{B}/{path}', token='owner', method='DELETE')

print(f'\n{sum(results)}/{len(results)} checks as expected')
raise SystemExit(0 if all(results) else 1)
