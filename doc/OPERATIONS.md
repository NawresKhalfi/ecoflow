# EcoFlow — exploitation, supervision et plan de reprise

Projet Firebase : `meteo-ba45f` (offre Spark, sans serveur applicatif).
Ce document couvre la disponibilité (US-125), la supervision (US-131) et la
sauvegarde / restauration (US-132).

## 1. Disponibilité (objectif ≥ 99 %)

EcoFlow ne fait tourner aucun serveur propre : la disponibilité repose sur
les services gérés de Google, dont les engagements dépassent l'objectif.

| Brique | Rôle | Engagement de service Google |
|---|---|---|
| Cloud Firestore | Base de données, règles d'accès | 99,99 % (régional) / 99,999 % (multirégional) |
| Firebase Authentication | Connexion e-mail, téléphone, Google | 99,95 % |
| Firebase Cloud Messaging | Notifications push | sans SLA (au mieux) ; repli : boîte de réception dans l'app |
| Inférence IA (YOLO) | Scan des déchets | sur l'appareil : indépendante du réseau |

Résilience côté application :

- **Hors ligne** : Firestore garde un cache local ; les actions du collecteur
  (étapes, photo preuve, pesée) sont mises en file et envoyées au retour du
  réseau, avec un bandeau « Hors ligne » et un message en cas de conflit
  (US-126). L'acceptation d'une mission et les paiements restent en ligne
  (vérification transactionnelle).
- **Dégradation** : une notification qui échoue ne bloque jamais l'action
  métier ; les tuiles de carte sont facultatives.

### Distribution des modèles de vision (US-019)

Les nouvelles versions du modèle YOLO sont publiées sur Firebase Hosting
(`hosting/models/<version>/`, `firebase deploy --only hosting`), puis déclarées
dans Supervision → IA avec leurs URL. L'app les télécharge au premier scan et
les garde en cache. Quota gratuit de Hosting : 360 Mo/jour de transfert, soit
une quinzaine de téléchargements iOS (24 Mo) ou 6 Android (52 Mo) par jour :
au-delà, passer à Blaze ou héberger les fichiers ailleurs (CDN). Le modèle
embarqué reste la version de repli (« Revenir à la version précédente »).

## 2. Supervision et alertes

| Signal | Outil | Alerte |
|---|---|---|
| Plantages et erreurs Flutter / natives | Firebase Crashlytics | e-mail sur nouvelle erreur, régression et pic (« velocity alert ») |
| Temps d'analyse d'un scan (US-124) | Écran Supervision → Performance : 90ᵉ centile et part < 5 s | pastille rouge au-delà de 5 s |
| Qualité du service | Supervision : taux de matching, délais, annulations, précision IA | revue hebdomadaire |
| Quotas et erreurs Firestore | Console Firebase → Firestore → Utilisation | alerte budgétaire Google Cloud |
| Règles d'accès | CI : sonde des règles (188 scénarios) à chaque commit | échec du pipeline |
| Statut des services Google | https://status.firebase.google.com | abonnement RSS |

Mise en service de Crashlytics (une fois) :

1. Console Firebase → **Crashlytics** → « Activer » pour les apps iOS et Android.
2. Lancer une version *release* (la collecte est désactivée en debug ; pour
   vérifier en debug : `flutter run --dart-define=CRASHLYTICS_IN_DEBUG=true`).
3. Console → Crashlytics → **Alertes** : activer les e-mails pour les nouveaux
   problèmes et les pics.

Les rapports n'identifient l'utilisateur que par son `uid` et son rôle :
jamais de nom ni d'e-mail (US-127).

## 3. Sauvegardes (quotidiennes) et restauration testée

Les exports planifiés de Firestore exigent l'offre Blaze ; EcoFlow utilise à la
place `tool/backup.py`, exécuté chaque nuit par la CI
(`.github/workflows/nightly.yml`) :

1. export de toutes les collections avec un compte administrateur dédié
   (format REST de Firestore, types conservés) ;
2. **restauration testée** à chaque exécution dans un émulateur vierge, puis
   comparaison document par document (`verify`) ;
3. archive chiffrée (AES-256) conservée 30 jours.

Non sauvegardés volontairement : présence en ligne des collecteurs et
positions en direct (données éphémères). Les photos de scan (base64) sont
incluses dans les sous-collections.

À configurer une fois dans GitHub (Settings → Secrets → Actions) :
`ECOFLOW_BACKUP_EMAIL`, `ECOFLOW_BACKUP_PASSWORD` (compte administrateur
dédié), `ECOFLOW_BACKUP_PASSPHRASE`.

Commandes manuelles :

```sh
python3 tool/backup.py export                     # → backups/ecoflow-meteo-ba45f-AAAAMMJJ-HHMM
firebase emulators:start --only auth,firestore    # dans un autre terminal
python3 tool/backup.py restore backups/<dossier>  # vers l'émulateur uniquement
python3 tool/backup.py verify backups/<dossier>
```

## 4. Maintenance de nuit

Après la sauvegarde, la même tâche planifiée lance `tool/maintenance.py` :

- **purge des photos de scan expirées** (90 jours, US-021) ;
- **expiration des EcoPoints** en FIFO pour tous les wallets (US-078), avec
  un mouvement « Expiration automatique » dans l'historique du citoyen.
- **réentraînement des prévisions** (US-093) : `dart run tool/retrain.dart`
  (`--dry-run` pour simuler), mêmes fonctions de calcul que l'app.

Simulation sans écriture : `python3 tool/maintenance.py --dry-run`. Le script
est testé à chaque commit contre l'émulateur (`tool/maintenance_test.py`).

## 5. Plan de reprise

Objectifs : perte de données maximale **24 h** (sauvegarde quotidienne),
remise en service **4 h**.

| Incident | Réaction |
|---|---|
| Panne Google / Firebase | Suivre status.firebase.google.com ; l'app continue hors ligne (cache, file d'actions) ; annonce aux utilisateurs dès le retour (Supervision → Annonces). |
| Règles Firestore erronées déployées | Console → Firestore → Règles → historique → republier la version précédente, ou `git checkout <commit> -- firestore.rules && firebase deploy --only firestore:rules`. |
| Données corrompues ou supprimées | 1) geler les écritures concernées (règles) ; 2) déchiffrer la dernière archive saine ; 3) la restaurer dans l'émulateur et la vérifier ; 4) réimporter les documents concernés (console Firebase ou compte de service) ; 5) tracer l'opération dans le journal d'audit. |
| Compte compromis | Supervision → Comptes → bloquer ; Authentication → désactiver ; Wallet → geler ; revue du journal d'audit. |
| Plantage massif après une version | Crashlytics → identifier la version ; retirer la version des stores / republier la précédente. |

Tester le plan au moins une fois par trimestre (restauration complète dans
l'émulateur, republication d'une version de règles).
