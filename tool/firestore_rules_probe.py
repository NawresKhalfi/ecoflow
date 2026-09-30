#!/usr/bin/env python3
"""Sonde des règles Firestore d'EcoFlow (epics 4-9) contre l'ÉMULATEUR local.

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
def stamp(w, *paths):
    w['updateTransforms']=[{'fieldPath':p,'setToServerValue':'REQUEST_TIME'} for p in paths]; return w
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

# --- Epic 7 : notifications, position en direct, messagerie --------------
code3=''.join(random.choice('ABCDEFGHJKMNPQRSTUVWXYZ23456789') for _ in range(8)); cid3='probe'+code3.lower()
outsider, ouid = login('probe-outsider@ecoflow.test')
owner_set(f'users/{ouid}', {'displayName':'Outsider','role':'citizen','status':'active','verificationStatus':'notRequired'})
check('citizen creates 3rd estimate', leila, [create(f'estimates/{code3}', {'citizenUid':luid,'lines':[line],'totalKg':2.0,'totalDt':8.0,'confidence':.8,'priceScaleId':'default','status':'estimated','createdAt':now})], True)
check('citizen creates 3rd request', leila, [create(f'collections/{cid3}', {'citizenUid':luid,'estimateCode':code3,'place':{'point':{'lat':35.8256,'lng':10.6084},'address':'Rue probe 3','zoneId':'sousse'},'zoneId':'sousse','slotId':slot,'instructions':'','hasInstructionPhoto':False,'estimatedKg':2.0,'estimatedDt':8.0,'categories':['can'],'status':'searching','refusedBy':[],'recurrence':'none','lateCancellation':False,'rated':False,'createdAt':now})], True)
check('collector accepts 3rd', karim, [upd(f'collections/{cid3}', {'status':'accepted','collectorUid':kuid,'proposedCollectorUid':None,'acceptedAt':now,'updatedAt':now})], True)
notif=lambda frm, to, t='assigned': create(f'notifications/n{code3}{t}{frm[:4]}', {'toUid':to,'fromUid':frm,'type':t,'collectionId':cid3,'address':'x','preview':'','critical':False,'read':False,'createdAt':now})
check('collector notifies citizen', karim, [notif(kuid, luid)], True)
check('outsider cannot notify citizen', outsider, [notif(ouid, luid, 'message')], False)
check('collector cannot spoof sender', karim, [create(f'notifications/spoof{code3}', {'toUid':luid,'fromUid':ouid,'type':'assigned','collectionId':cid3,'read':False,'createdAt':now})], False)
s_,q=http(B+':runQuery', {'structuredQuery':{'from':[{'collectionId':'notifications'}],'where':{'fieldFilter':{'field':{'fieldPath':'toUid'},'op':'EQUAL','value':val(luid)}}}}, leila)
results.append(s_==200); print('PASS' if s_==200 else 'FAIL', 'citizen lists own notifications →', s_)
check('live position refused before departure', karim, [create(f'liveLocations/{cid3}', {'collectorUid':kuid,'point':{'lat':35.83,'lng':10.61},'at':now})], False)
check('collector -> onTheWay (3)', karim, [upd(f'collections/{cid3}', {'status':'onTheWay','onTheWayAt':now})], True)
check('collector publishes live position', karim, [create(f'liveLocations/{cid3}', {'collectorUid':kuid,'point':{'lat':35.83,'lng':10.61},'at':now})], True)
s_,_=http(f'{B}/liveLocations/{cid3}', token=leila); results.append(s_==200); print('PASS' if s_==200 else 'FAIL', 'citizen reads live position →', s_)
s_,_=http(f'{B}/liveLocations/{cid3}', token=outsider); results.append(s_==403); print('PASS' if s_==403 else 'FAIL', 'outsider cannot read live position →', s_)
check('citizen sends message', leila, [create(f'collections/{cid3}/messages/m1{code3}', {'fromUid':luid,'text':'Bonjour, 2e étage','at':now})], True)
check('outsider cannot post in chat', outsider, [create(f'collections/{cid3}/messages/m2{code3}', {'fromUid':ouid,'text':'spam','at':now})], False)
check('message over 500 chars refused', karim, [create(f'collections/{cid3}/messages/m3{code3}', {'fromUid':kuid,'text':'x'*501,'at':now})], False)
check('collector -> arrived (3)', karim, [upd(f'collections/{cid3}', {'status':'arrived','arrivedAt':now})], True)
check('collector -> inProgress (3)', karim, [upd(f'collections/{cid3}', {'status':'inProgress','inProgressAt':now})], True)
s_,_=http(f'{B}/liveLocations/{cid3}', token=leila); results.append(s_==403); print('PASS' if s_==403 else 'FAIL', 'live position hidden once on site →', s_)

check('non-admin cannot write optimization history', karim, [create(f'config/optimization/history/h{code}', {'maxDetourKm':99.0,'by':kuid})], False)

# --- Epic 8 : Recycle Wallet & EcoPoints ---------------------------------
for u in (luid,): http(f'{B}/wallets/{u}', token='owner', method='DELETE')
cit2, c2uid = login('probe-citizen2@ecoflow.test')
owner_set(f'users/{c2uid}', {'displayName':'Probe citizen 2','role':'citizen','status':'active','verificationStatus':'notRequired'})
http(f'{B}/wallets/{c2uid}', token='owner', method='DELETE')
def wallet(uid, **kw):
    base={'earned':0,'spent':0,'expired':0,'held':0,'collections':0,'kg':0.0,'dayCount':0,'lastEntryId':None,
          'lastRedemptionId':None,'referredBy':None,'referralCode':None,'frozen':False,'frozenReason':None}
    base.update(kw); return upd(f'wallets/{uid}', base, exists=False)
def earn(uid, c, pts, kg, status='credited', by=None):
    return create(f'pointEntries/c_{c}', {'uid':uid,'type':'earn','points':pts,'status':status,'collectionId':c,
                 'redemptionId':None,'kg':kg,'byCategory':by or {'can':kg},'flags':[],'label':None,'createdAt':now})
# Pesée : 2,5 kg de canettes (×2) → 2,5 × 2 × 10 = 50 + bonus 1re collecte 50 = 100.
first=stamp(wallet(luid, earned=100, collections=1, kg=2.5, dayCount=1, lastEntryId=f'c_{cid}'), 'lastEarnAt')
check('EcoPoints inflated (500) refused', leila, [earn(luid, cid, 500, 2.5), stamp(wallet(luid, earned=500, collections=1, kg=2.5, dayCount=1, lastEntryId=f'c_{cid}'), 'lastEarnAt')], False)
check('points entry without wallet update refused', leila, [earn(luid, cid, 100, 2.5)], False)
check('wallet tampering alone refused', leila, [wallet(luid, earned=9999)], False)
check('points marked credited when not weighed refused', leila, [create(f'pointEntries/c_{cid3}', {'uid':luid,'type':'earn','points':50,'status':'credited','collectionId':cid3,'redemptionId':None,'kg':2.0,'byCategory':{'can':2.0},'flags':[],'label':None,'createdAt':now}), stamp(wallet(luid, earned=50, collections=1, kg=2.0, dayCount=1, lastEntryId=f'c_{cid3}'), 'lastEarnAt')], False)
check('EcoPoints = weighing formula (+wallet)', leila, [earn(luid, cid, 100, 2.5), first], True)
check('same collection credited twice refused', leila, [earn(luid, cid, 100, 2.5), stamp(wallet(luid, earned=200, collections=2, kg=5.0, dayCount=2, lastEntryId=f'c_{cid}'), 'lastEarnAt')], False)
check('collector cannot credit citizen points', karim, [upd(f'wallets/{luid}', {'earned':1000})], False)
s_,_=http(f'{B}/wallets/{luid}', token=cit2); results.append(s_==403); print('PASS' if s_==403 else 'FAIL', 'other citizen cannot read wallet →', s_)
check('non-admin cannot publish points rules', leila, [upd('config/points', {'pointsPerKg':1000.0}, exists=False)], False)

owner_set(f'rewards/rw{code}', {'partnerId':'probe','partnerName':'Probe shop','title':'-10 %','cost':80,'stock':5,'active':True})
owner_set(f'rewards/big{code}', {'partnerId':'probe','partnerName':'Probe shop','title':'Vélo','cost':500,'stock':None,'active':True})
def redeem(rw, cost, rid, spent, stock=None, entry_pts=None):
    w=[create(f'redemptions/{rid}', {'uid':luid,'rewardId':rw,'rewardTitle':'x','partnerName':'Probe shop','cost':cost,'code':'ABCD-EF23','status':'active','createdAt':now}),
       create(f'pointEntries/r_{rid}', {'uid':luid,'type':'redeem','points':-(entry_pts or cost),'status':'credited','collectionId':None,'redemptionId':rid,'kg':0.0,'byCategory':{},'flags':[],'label':'x','createdAt':now}),
       upd(f'wallets/{luid}', {'spent':spent,'lastEntryId':f'r_{rid}','lastRedemptionId':rid})]
    if stock is not None: w.append(upd(f'rewards/{rw}', {'stock':stock}))
    return w
check('redeem above balance refused (500 > 100)', leila, redeem(f'big{code}', 500, f'rb{code}', 500), False)
check('coupon with wrong cost refused', leila, redeem(f'rw{code}', 1, f'rc{code}', 1, stock=4), False)
check('redeem without stock decrement refused', leila, redeem(f'rw{code}', 80, f'rd{code}', 80), False)
check('redeem coupon (+entry, +stock)', leila, redeem(f'rw{code}', 80, f'ra{code}', 80, stock=4), True)
owner_set(f'wallets/{luid}', {'earned':500,'spent':80,'expired':0,'held':0,'collections':1,'kg':2.5,'dayCount':1,'lastEntryId':f'r_ra{code}','lastRedemptionId':f'ra{code}','referredBy':None,'referralCode':None,'frozen':True,'frozenReason':'probe'})
check('frozen wallet cannot redeem', leila, redeem(f'rw{code}', 80, f're{code}', 160, stock=3), False)
check('citizen cannot unfreeze own wallet', leila, [upd(f'wallets/{luid}', {'frozen':False})], False)
owner_set(f'wallets/{luid}', {'earned':100,'spent':80,'expired':0,'held':0,'collections':1,'kg':2.5,'dayCount':1,'lastEntryId':f'r_ra{code}','lastRedemptionId':f'ra{code}','referredBy':None,'referralCode':None,'frozen':False,'frozenReason':None})
check('expire own points', leila, [create(f'pointEntries/x{code}', {'uid':luid,'type':'expire','points':-5,'status':'credited','collectionId':None,'redemptionId':None,'kg':0.0,'byCategory':{},'flags':[],'label':None,'createdAt':now}), upd(f'wallets/{luid}', {'expired':5,'lastEntryId':f'x{code}'})], True)

ref=code[:6]
check('citizen creates referral code', leila, [create(f'referralCodes/{ref}', {'uid':luid}), upd(f'wallets/{luid}', {'referralCode':ref})], True)
check('self-referral refused', leila, [upd(f'wallets/{luid}', {'referredBy':luid})], False)
check('friend enters referral code', cit2, [upd(f'wallets/{c2uid}', {'referredBy':luid}, exists=False)], True)
code4=code[::-1]; cid4='probe4'+code.lower()
check('friend creates estimate', cit2, [create(f'estimates/{code4}', {'citizenUid':c2uid,'lines':[line],'totalKg':2.0,'totalDt':8.0,'confidence':.8,'priceScaleId':'default','status':'estimated','createdAt':now})], True)
check('friend creates request', cit2, [create(f'collections/{cid4}', {'citizenUid':c2uid,'estimateCode':code4,'place':{'point':{'lat':35.8256,'lng':10.6084},'address':'Rue probe 4','zoneId':'sousse'},'zoneId':'sousse','slotId':slot,'instructions':'','hasInstructionPhoto':False,'estimatedKg':2.0,'estimatedDt':8.0,'categories':['can'],'status':'searching','refusedBy':[],'recurrence':'none','lateCancellation':False,'rated':False,'createdAt':now})], True)
check('collector accepts (4)', karim, [upd(f'collections/{cid4}', {'status':'accepted','collectorUid':kuid,'proposedCollectorUid':None,'acceptedAt':now,'updatedAt':now})], True)
for st in ['onTheWay','arrived','inProgress']:
    check(f'collector -> {st} (4)', karim, [upd(f'collections/{cid4}', {'status':st, st+'At':now})], True)
check('proof (4)', karim, [create(f'collections/{cid4}/attachments/proof', {'uid':kuid,'data':'AQID','takenAt':now}), upd(f'collections/{cid4}', {'hasProof':True})], True)
# Pesée anormale : 9 kg pour 2 kg estimés (> ×3) → points mis en attente.
check('weighing (4)', karim, [upd(f'estimates/{code4}', {'status':'weighed','actualKg':{'glass':9.0},'actualTotalKg':9.0,'finalDt':9.0,'collectorUid':kuid,'weighedAt':now}), upd(f'collections/{cid4}', {'status':'handedOver','collectorUid':kuid,'handedOverAt':now})], True)
check('friend confirms (4)', cit2, [upd(f'collections/{cid4}', {'status':'completed','completedAt':now})], True)
# 9 × 1,2 × 10 = 108 + 50 = 158, attente anti-fraude (écart estimation).
held=stamp(wallet(c2uid, held=158, collections=1, kg=9.0, dayCount=1, lastEntryId=f'c_{cid4}', referredBy=luid), 'lastEarnAt')
refbonus=[create(f'pointEntries/ref_{c2uid}', {'uid':luid,'type':'referral','points':100,'status':'credited','collectionId':None,'redemptionId':None,'kg':0.0,'byCategory':{},'flags':[],'label':None,'createdAt':now}),
          {'update':{'name':f'{ROOT}/wallets/{luid}','fields':fields({'lastEntryId':f'ref_{c2uid}'})},'updateMask':{'fieldPaths':['lastEntryId']},
           'updateTransforms':[{'fieldPath':'earned','increment':{'integerValue':'100'}}]}]
check('anomalous weighing credited directly refused', cit2, [earn(c2uid, cid4, 158, 9.0, by={'glass':9.0}), stamp(wallet(c2uid, earned=158, collections=1, kg=9.0, dayCount=1, lastEntryId=f'c_{cid4}', referredBy=luid), 'lastEarnAt')], False)
bad=[refbonus[0] | {}, dict(refbonus[1])]
bad[0]=create(f'pointEntries/ref_{c2uid}', {'uid':luid,'type':'referral','points':999,'status':'credited','collectionId':None,'redemptionId':None,'kg':0.0,'byCategory':{},'flags':[],'label':None,'createdAt':now})
bad[1]={**refbonus[1], 'updateTransforms':[{'fieldPath':'earned','increment':{'integerValue':'999'}}]}
check('referral bonus inflated refused', cit2, [earn(c2uid, cid4, 158, 9.0, 'held', {'glass':9.0}), held]+bad, False)
check('held points + referral bonus in one batch', cit2, [earn(c2uid, cid4, 158, 9.0, 'held', {'glass':9.0}), held]+refbonus, True)

# --- Epic 9 : espace recycleur -------------------------------------------
dep2=f'd2{code}'
check('collector deposits a 2nd batch (snapshot)', karim, [create(f'deposits/{dep2}', {'collectorUid':kuid,'recyclerUid':ruid,'recyclerName':'GreenPlast','missionIds':[cid4],'byCategoryKg':{'glass':9.0},'totalKg':9.0,'collectorName':'Probe collector','zoneIds':['sousse'],'missions':[{'id':cid4,'zoneId':'sousse','day':now,'kg':9.0}],'status':'pending','createdAt':now})], True)
check('collector notifies recycler: batch on its way', karim, [create(f'notifications/dep{code}', {'toUid':ruid,'fromUid':kuid,'type':'depositIncoming','collectionId':dep2,'address':'Probe','preview':'9 kg','read':False,'createdAt':now})], True)
check('deposit notice to someone else refused', karim, [create(f'notifications/dep2{code}', {'toUid':luid,'fromUid':kuid,'type':'depositIncoming','collectionId':dep2,'address':'','preview':'','read':False,'createdAt':now})], False)
lot1=f'l1{code}'
def lot(lid, **kw):
    d={'recyclerUid':ruid,'material':'glass','grade':'a','form':'raw','source':'reception','initialKg':8.5,'kg':8.5,'depositId':dep2,'collectorUid':kuid,'collectorName':'Probe collector','zoneIds':['sousse'],'missions':[],'inputLotIds':[],'marketplace':False,'receivedAt':now}
    d.update(kw); return create(f'lots/{lid}', d)
check('lot without confirmed deposit refused', rec, [lot(lot1)], False)
check('collector cannot create stock lots', karim, [lot(lot1, recyclerUid=kuid)], False)
receive=[lot(lot1), create(f'stockMoves/m1{code}', {'recyclerUid':ruid,'lotId':lot1,'material':'glass','deltaKg':8.5,'reason':'reception','note':'','at':now}),
         upd(f'deposits/{dep2}', {'status':'confirmed','note':'','reviewedAt':now,'receivedKg':{'glass':8.5},'quality':'a','contaminationPct':2.0,'lotIds':[lot1]})]
check('recycler receives batch (QC + lot + move)', rec, receive, True)
s_,_=http(f'{B}/lots/{lot1}', token=leila); results.append(s_==403); print('PASS' if s_==403 else 'FAIL', 'citizen cannot read stock →', s_)
check('lot weight cannot grow above intake', rec, [upd(f'lots/{lot1}', {'kg':50.0})], False)
check('sale: stock out + movement', rec, [upd(f'lots/{lot1}', {'kg':6.5}), create(f'stockMoves/m2{code}', {'recyclerUid':ruid,'lotId':lot1,'material':'glass','deltaKg':-2.0,'reason':'sale','note':'','at':now})], True)
lot2=f'l2{code}'
prod=[upd(f'lots/{lot1}', {'kg':1.5}), lot(lot2, source='production', form='granules', initialKg=4.6, kg=4.6, depositId=None, inputLotIds=[lot1], marketplace=True),
      create(f'productions/p{code}', {'recyclerUid':ruid,'material':'glass','inputKg':5.0,'outputKg':4.6,'form':'granules','grade':'a','inputLotIds':[lot1],'outputLotId':lot2,'at':now})]
check('production as raw material refused', rec, [lot(f'l3{code}', source='production', depositId=None)], False)
check('production (input consumed, output lot)', rec, prod, True)
check('recycler sets purchase prices', rec, [upd(f'companies/{ruid}', {'purchasing':{'glass':{'accepting':True,'priceDtPerKg':0.12,'capacityKgMonth':5000.0}}})], True)
check('recycler cannot self-change status', rec, [upd(f'companies/{ruid}', {'status':'approved','purchasing':{}})], True)
check('recycler cannot touch legal data with prices', rec, [upd(f'companies/{ruid}', {'legalName':'Autre','purchasing':{}})], False)

# Nettoyage : l'émulateur reste utilisable pour la démonstration.
for path in [f'estimates/{code}', f'estimates/{code2}', f'collections/{cid}', f'collections/{cid2}',
             f'collections/{cid}/attachments/proof', f'earnings/{cid}', f'payouts/p{code}b',
             f'deposits/d{code}', f'tickets/t{code2}', f'slotCounters/sousse__{slot}',
             f'collectorBalances/{kuid}', f'companies/{ruid}', f'estimates/{code3}',
             f'collections/{cid3}', f'collections/{cid3}/messages/m1{code3}', f'liveLocations/{cid3}',
             f'notifications/n{code3}assigned{kuid[:4]}', f'wallets/{luid}', f'wallets/{c2uid}',
             f'pointEntries/c_{cid}', f'pointEntries/r_ra{code}', f'pointEntries/x{code}',
             f'pointEntries/c_{cid4}', f'pointEntries/ref_{c2uid}', f'redemptions/ra{code}',
             f'rewards/rw{code}', f'rewards/big{code}', f'referralCodes/{code[:6]}',
             f'estimates/{code4}', f'collections/{cid4}', f'collections/{cid4}/attachments/proof',
             f'deposits/d2{code}', f'notifications/dep{code}', f'lots/l1{code}', f'lots/l2{code}',
             f'stockMoves/m1{code}', f'stockMoves/m2{code}', f'productions/p{code}']:
    http(f'{B}/{path}', token='owner', method='DELETE')

print(f'\n{sum(results)}/{len(results)} checks as expected')
raise SystemExit(0 if all(results) else 1)
