# EcoFlow — suivi des fonctionnalités

Source de vérité : `spec/EcoFlow_Epics_User_Stories.xlsx` (132 user stories, 14 epics).

Légende : ⬜ non démarré · 🟨 en cours / partiel · ✅ implémenté

## Synthèse par epic

| Epic | Nom | Release | Stories | Statut |
|---|---|---|---|---|
| E01 | Authentification & profils | MVP | 9/10 | 🟨 |
| E02 | Vision IA – scan des déchets | MVP | 10/12 | 🟨 |
| E03 | Estimation intelligente quantité & valeur | MVP | 8/8 | ✅ |
| E04 | Demande de collecte | MVP | 10/11 | 🟨 |
| E05 | Espace collecteur & missions | MVP | 13/14 | 🟨 |
| E06 | Optimisation IA des itinéraires | V1 | 7/7 | ✅ |
| E07 | Suivi temps réel & notifications | MVP | 2/6 | 🟨 |
| E08 | Recycle Wallet & EcoPoints | V1 | 9/10 | 🟨 |
| E09 | Espace recycleur – dashboard & stocks | V1 | 9/9 | ✅ |
| E10 | Prédiction IA des volumes | V2 | 0/6 | ⬜ |
| E11 | Marketplace circulaire B2B | V2 | 0/12 | ⬜ |
| E12 | Administration & supervision | MVP | 0/12 | ⬜ |
| E13 | Statistiques & impact citoyen | V1 | 0/5 | ⬜ |
| E14 | Exigences transverses & qualité | MVP | 0/10 | ⬜ |

## E01 — Authentification & profils

_Inscription, connexion, gestion des rôles (citoyen, collecteur, recycleur, admin), vérification des professionnels et profils._

| ID | Acteur | Story | Prio | Release | Statut | Notes |
|---|---|---|---|---|---|---|
| US-001 | Utilisateur | En tant qu'utilisateur, je veux m'inscrire avec mon numéro de téléphone (code OTP par SMS) ou mon e-mail afin de créer un compte rapidement. | Must | MVP | ✅ | E-mail (lien de vérification obligatoire) + téléphone OTP (code 5 min, renvoi après 30 s). Fournisseurs à activer dans la console Firebase. |
| US-002 | Utilisateur | En tant qu'utilisateur, je veux me connecter avec e-mail/mot de passe ou compte Google afin de accéder à mon espace sans friction. | Must | MVP | ✅ | E-mail/mot de passe + Google ; session persistante Firebase (ID token + refresh token) ; verrouillage local 15 min après 5 échecs. |
| US-003 | Utilisateur | En tant qu'utilisateur, je veux choisir mon rôle (citoyen, collecteur, recycleur) à l'inscription afin de accéder à l'interface adaptée. | Must | MVP | ✅ | Rôle choisi à l'inscription, navigation par rôle ; admin non sélectionnable (UI + domaine + règles Firestore). |
| US-004 | Utilisateur | En tant qu'utilisateur, je veux réinitialiser mon mot de passe afin de récupérer l'accès à mon compte. | Must | MVP | 🟨 | Lien Firebase à usage unique, ancien mot de passe invalidé. ⚠️ Expiration 15 min non configurable côté Firebase (1 h par défaut) — nécessite un backend. |
| US-005 | Citoyen | En tant que citoyen, je veux gérer mon profil et mes adresses enregistrées afin de pré-remplir mes demandes de collecte. | Should | MVP | ✅ | CRUD adresses + position GPS + adresse par défaut unique. |
| US-006 | Collecteur | En tant que collecteur, je veux soumettre mes documents (CIN, permis, carte grise, photo véhicule) afin de être vérifié et autorisé à collecter. | Must | MVP | ✅ | 4 pièces (CIN, permis, carte grise, véhicule), statut et motif de refus affichés. Fichiers compressés stockés dans Firestore (plan Spark sans Cloud Storage). |
| US-007 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux créer le profil de mon entreprise (raison sociale, matricule fiscal, matières traitées, capacités) afin de être référencé comme recycleur fiable. | Must | V1 | ✅ | Raison sociale, matricule fiscal validé, matières, capacité ; soumis à validation admin (verrouillé en attente). |
| US-008 | Utilisateur | En tant qu'utilisateur, je veux choisir la langue de l'application (français, arabe, anglais) afin de utiliser l'application dans ma langue. | Should | V1 | ✅ | fr / ar / en, changement à chaud, RTL arabe, synchronisé au profil. |
| US-009 | Utilisateur | En tant qu'utilisateur, je veux gérer mes préférences de notifications afin de ne recevoir que les alertes utiles. | Could | V1 | ✅ | 3 catégories activables (statut collecte, points, marketplace). L'envoi réel des push arrive avec E07. |
| US-010 | Utilisateur | En tant qu'utilisateur, je veux supprimer mon compte et mes données personnelles afin de garder le contrôle de mes données. | Should | V1 | ✅ | Confirmation en 2 étapes (mot SUPPRIMER + ré-authentification), anonymisation immédiate, demande de purge ≤ 30 j tracée ; rôle conservé pour l'historique financier. |

## E02 — Vision IA – scan des déchets

_Détection et classification des déchets par photo avec YOLOv8/YOLO11 : comptage, type de matière, recyclabilité._

| ID | Acteur | Story | Prio | Release | Statut | Notes |
|---|---|---|---|---|---|---|
| US-011 | Citoyen | En tant que citoyen, je veux prendre en photo mes déchets avec la caméra de l'application afin de lancer une analyse automatique. | Must | MVP | ✅ | Caméra (permission iOS/Android), aperçu avant analyse. Inférence sur l'appareil : 1,4–2,8 s mesurées sur simulateur iOS (CPU). |
| US-012 | Citoyen | En tant que citoyen, je veux importer une ou plusieurs photos depuis ma galerie afin de analyser des photos déjà prises. | Should | MVP | ✅ | Galerie multi-sélection limitée à 5, JPG/PNG uniquement, redimensionnement 1024 px + JPEG q78. |
| US-013 | Citoyen | En tant que citoyen, je veux voir les déchets détectés avec des cadres (bounding boxes) sur la photo afin de comprendre ce que l'IA a reconnu. | Must | MVP | ✅ | Cadres animés avec libellé et score ; seuil réglable par l'utilisateur (curseur) et par défaut par l'admin. |
| US-014 | Citoyen | En tant que citoyen, je veux obtenir le nombre d'objets par catégorie (bouteilles PET, canettes, carton, verre, autres) afin de connaître précisément ce que je recycle. | Must | MVP | ✅ | Comptage par catégorie + total. ⚠️ Le modèle embarqué (1 objet/image à l'entraînement) détecte surtout la matière dominante, pas chaque bouteille. |
| US-015 | Citoyen | En tant que citoyen, je veux voir la recyclabilité estimée de mes déchets (faible/moyenne/élevée) afin de savoir si mes déchets sont valorisables. | Should | MVP | ✅ | Faible / moyenne / élevée selon la recyclabilité des catégories du catalogue, avec explication. |
| US-016 | Citoyen | En tant que citoyen, je veux corriger manuellement le résultat de l'IA (ajouter, supprimer, changer une catégorie) afin de obtenir un résultat fiable. | Must | MVP | ✅ | Changer de catégorie, supprimer, ajouter ; proposition IA d'origine conservée + résumé des corrections. |
| US-017 | Citoyen | En tant que citoyen, je veux être alerté si ma photo est floue, sombre ou mal cadrée afin de améliorer la qualité de la détection. | Should | V1 | ✅ | Luminosité, netteté (variance du laplacien), cadrage (aucun objet / objets minuscules) ; conseil + « Reprendre la photo ». |
| US-018 | Citoyen | En tant que citoyen, je veux analyser mes déchets sans connexion stable (modèle embarqué TFLite) afin de scanner même avec un réseau faible. | Could | V2 | ✅ | Modèle embarqué : Core ML int8 (iOS, 23 Mo) et TFLite fp16 (Android, 49 Mo) ; résultats synchronisés par le cache hors ligne Firestore. Android non testé sur appareil. |
| US-019 | Administrateur | En tant que administrateur, je veux gérer les versions du modèle YOLO déployé et consulter ses métriques (précision, rappel, mAP) afin de piloter la qualité de l'IA. | Should | V2 | 🟨 | Versions, métriques (seul le rappel 73,5 % est publié pour le modèle embarqué), activation, retour arrière. ⚠️ Chargement d'une 2e version par URL non testé (aucun modèle hébergé). |
| US-020 | Administrateur | En tant que administrateur, je veux exporter les corrections des utilisateurs sous forme de jeu de données annoté afin de réentraîner et améliorer le modèle. | Should | V2 | ✅ | Export ZIP au format YOLO (images anonymisées, noms séquentiels) des seuls scans corrigés avec consentement. |
| US-021 | Système | En tant que système, je dois anonymiser et stocker les photos envoyées de façon sécurisée afin de respecter la vie privée des utilisateurs. | Should | V1 | 🟨 | EXIF/GPS supprimés (ré-encodage), chiffrement au repos Firestore, conservation 90 j. ⚠️ Purge côté app (TTL Firestore impossible sans facturation Blaze). |
| US-022 | Administrateur | En tant que administrateur, je veux définir le catalogue des classes de déchets (PET, HDPE, PP, canette alu, carton, verre…) afin de aligner la détection avec les matières recyclables. | Must | MVP | ✅ | CRUD du catalogue, lien classes du modèle → catégories et catégorie → matière du barème (epic 3). |

## E03 — Estimation intelligente quantité & valeur

_Estimation du poids et de la valeur en DT, indice de confiance, confirmation humaine et calibrage par la pesée réelle._

| ID | Acteur | Story | Prio | Release | Statut | Notes |
|---|---|---|---|---|---|---|
| US-023 | Citoyen | En tant que citoyen, je veux obtenir une estimation du poids par matière (en kg) afin de connaître ma quantité de déchets. | Must | MVP | ✅ | Poids par catégorie + total (kg, 2 décimales) : saisie manuelle > contenant (volume × densité) > nombre d'objets × poids unitaire. |
| US-024 | Citoyen | En tant que citoyen, je veux voir la valeur estimée de mes déchets en DT afin de savoir ce que je vais gagner. | Must | MVP | ✅ | Valeur en DT (3 décimales) selon le barème en vigueur au moment de la demande, mention « estimation » ; barème figé dans l'estimation. |
| US-025 | Citoyen | En tant que citoyen, je veux voir un indice de confiance et être invité à confirmer quand la photo ne suffit pas afin de comprendre la fiabilité de l'estimation. | Must | MVP | ✅ | Fiabilité = confiance de détection × fiabilité de la méthode ; sous 60 % : alerte + confirmation ou saisie obligatoire avant enregistrement. |
| US-026 | Citoyen | En tant que citoyen, je veux préciser le contenant (sac 50 L, carton, caisse) ou saisir un poids manuel afin de affiner l'estimation. | Should | MVP | ✅ | Contenants Sac 30/50/100 L, carton, caisse et poids manuel par matière, recalcul instantané (vérifié sur simulateur). |
| US-027 | Administrateur | En tant que administrateur, je veux configurer le barème des prix par matière (DT/kg) avec dates d'effet afin de refléter les prix du marché. | Must | MVP | ✅ | Barèmes DT/kg par matière avec date d'effet, historique immuable (règles), barème indicatif par défaut à valider. |
| US-028 | Collecteur | En tant que collecteur, je veux saisir le poids réel après pesée et ajuster la valeur finale afin de confirmer le prix réel de la collecte. | Must | MVP | ✅ | Collecteur vérifié uniquement : code de pesée, poids réel obligatoire par matière, valeur finale et écart. ⚠️ Pont par code en attendant les collectes (E04/E05). |
| US-029 | Citoyen | En tant que citoyen, je veux voir l'écart entre l'estimation et la pesée réelle afin de comprendre le prix final. | Should | MVP | ✅ | Comparatif estimé/réel par matière dans « Mes estimations » + message in-app à la validation. Push : epic 7. |
| US-030 | Système | En tant que système, je dois comparer estimations et pesées réelles pour recalibrer les coefficients de poids afin de améliorer la précision au fil du temps. | Could | V2 | ✅ | MAE par matière + coefficients recalibrés (médiane réel/estimé, bornée, ≥ 3 pesées), versionnés. ⚠️ Déclenché par l'admin (pas de job serveur sur plan Spark). |

## E04 — Demande de collecte

_Création, modification, annulation d'une demande avec lieu et plage horaire ; matching avec un collecteur proche._

| ID | Acteur | Story | Prio | Release | Statut | Notes |
|---|---|---|---|---|---|---|
| US-031 | Citoyen | En tant que citoyen, je veux choisir l'emplacement de la collecte (GPS, carte ou adresse enregistrée) afin de être collecté là où je me trouve. | Must | MVP | ✅ | GPS, adresse enregistrée ou carte OpenStreetMap (épingle centrale, déplacer la carte) ; adresse inversée (géocodeur natif) ; zones desservies (cercles par défaut, gestion admin : US-117). |
| US-032 | Citoyen | En tant que citoyen, je veux sélectionner une plage horaire de collecte afin de planifier selon ma disponibilité. | Must | MVP | ✅ | 4 créneaux/jour sur 7 jours, ≥ 1 h à l'avance ; capacité par zone et créneau via compteurs transactionnels ; complets grisés. |
| US-033 | Citoyen | En tant que citoyen, je veux ajouter des instructions (étage, code d'accès, point de repère) afin de faciliter le travail du collecteur. | Should | MVP | ✅ | Instructions 300 caractères + photo facultative (compressée), lisibles par le collecteur (règles). |
| US-034 | Système | En tant que système, je dois rechercher automatiquement un collecteur disponible à proximité afin de assigner rapidement la collecte. | Must | MVP | 🟨 | Rayon 5 → 10 → 20 km, score distance/note/capacité, positions arrondies à ~1 km. ⚠️ Exécuté sur le téléphone du citoyen (pas de backend Spark) ; acceptation/refus du collecteur : epic 5. |
| US-035 | Citoyen | En tant que citoyen, je veux modifier ou annuler ma demande avant l'arrivée du collecteur afin de garder la flexibilité. | Must | MVP | ✅ | Modification ≤ 1 h avant (créneau → compteurs déplacés + nouvelle recherche), annulation avec pénalité uniquement après acceptation. Collecteur : voit la modification sur la demande ; push : epic 7. |
| US-036 | Citoyen | En tant que citoyen, je veux être informé si aucun collecteur n'est disponible et recevoir des alternatives (autre créneau, point de dépôt) afin de ne pas rester bloqué. | Should | V1 | ✅ | Alternatives : 3 prochains créneaux libres, recycleurs validés de la ville comme points de dépôt, file d'attente (relance de la recherche). |
| US-037 | Citoyen | En tant que citoyen, je veux planifier une collecte récurrente (hebdomadaire/mensuelle) afin de automatiser mon recyclage. | Could | V2 | ✅ | Hebdomadaire / mensuelle (fin de mois gérée) : occurrence suivante créée à la fin ou à l'annulation, avec nouvelle estimation (code à usage unique) ; arrêt à tout moment. |
| US-038 | Citoyen | En tant que citoyen, je veux consulter l'historique de mes demandes et leur statut afin de suivre mes collectes passées. | Must | MVP | ✅ | Historique filtrable par statut (toutes / en cours / terminées / annulées) et période (30 j), détail avec frise de suivi ; poids réel après pesée. |
| US-039 | Citoyen | En tant que citoyen, je veux remettre mes déchets en validant un code ou QR avec le collecteur afin de sécuriser la remise et le crédit de points. | Should | V1 | ✅ | Code + QR à usage unique (code de pesée) ; validation croisée : pesée du collecteur (règle getAfter) → confirmation du citoyen. Vérifié sur simulateur. |
| US-040 | Citoyen | En tant que citoyen, je veux noter et commenter le collecteur après la collecte afin de améliorer la qualité du service. | Should | V1 | ✅ | 1 à 5 étoiles + commentaire, une note par collecte (id = collecte), moyenne collecteur en transaction. |
| US-041 | Citoyen | En tant que citoyen, je veux signaler un problème (collecteur absent, poids contesté, comportement) afin de obtenir une résolution. | Should | V1 | ✅ | Motif (absent, poids contesté, comportement, autre) + description + 3 photos → ticket « open » pour l'admin (traitement : US-112). |

## E05 — Espace collecteur & missions

_Disponibilité, missions, navigation, pesée, validation, historique, revenus et dépôt au centre de tri._

| ID | Acteur | Story | Prio | Release | Statut | Notes |
|---|---|---|---|---|---|---|
| US-042 | Collecteur | En tant que collecteur, je veux passer en ligne/hors ligne et définir ma zone de travail afin de recevoir des missions uniquement quand je suis disponible. | Must | MVP | ✅ | En ligne / hors ligne instantané ; zone de travail en rayon (3 à 40 km) respectée par la recherche ; position arrondie ~1 km, effacée hors ligne. |
| US-043 | Collecteur | En tant que collecteur, je veux consulter les missions disponibles autour de moi (liste et carte) afin de choisir les collectes intéressantes. | Must | MVP | ✅ | Liste et carte (OpenStreetMap), tri distance / valeur, filtres matière et quantité ; temps réel. |
| US-044 | Collecteur | En tant que collecteur, je veux accepter ou refuser une mission afin de gérer ma charge de travail. | Must | MVP | ✅ | Acceptation verrouillée (transaction + règle : premier arrivé), refus ; 60 s puis refus automatique. ⚠️ Délai appliqué par les apps (collecteur et citoyen), pas par un serveur. |
| US-045 | Collecteur | En tant que collecteur, je veux voir le détail de la mission (localisation, type de déchets, quantité estimée, valeur estimée) afin de préparer ma collecte. | Must | MVP | ✅ | Matières, nombre, poids et valeur estimés par l'IA, fiabilité, photos du scan, instructions. |
| US-046 | Collecteur | En tant que collecteur, je veux lancer la navigation GPS vers le point de collecte afin de arriver rapidement. | Must | MVP | ✅ | Carte intégrée + ouverture Google Maps / Waze / Plans. Ouverture des apps externes non testée sur appareil. |
| US-047 | Collecteur | En tant que collecteur, je veux signaler mon arrivée et démarrer la collecte afin de informer le citoyen. | Must | MVP | ✅ | Accepté → en route → arrivé → en cours, horodatés (transitions imposées par les règles). |
| US-048 | Collecteur | En tant que collecteur, je veux prendre une photo preuve de la collecte afin de limiter les litiges. | Should | MVP | ✅ | Photo preuve obligatoire (app + règle : pas de remise sans preuve), liée à la mission. |
| US-049 | Collecteur | En tant que collecteur, je veux connecter une balance Bluetooth pour enregistrer le poids automatiquement afin de éviter les erreurs de saisie. | Could | V2 | 🟨 | Profil Bluetooth standard « Weight Scale » (0x181D/0x2A9D), décodage SI et impérial testé ; saisie manuelle en secours. ⚠️ Jamais testé avec une vraie balance. |
| US-050 | Collecteur | En tant que collecteur, je veux clôturer la mission après validation du citoyen afin de déclencher crédit des points et revenus. | Must | MVP | ✅ | Clôture = code de remise du citoyen (sa validation) + poids réels → remise → confirmation citoyen → terminée, revenu crédité. EcoPoints : epic 8. |
| US-051 | Collecteur | En tant que collecteur, je veux consulter l'historique de mes missions et mes revenus afin de suivre mon activité. | Must | MVP | ✅ | Jour / semaine / mois, total DT et kg, gains 7 jours, historique. |
| US-052 | Collecteur | En tant que collecteur, je veux demander le retrait de mes revenus afin de être payé pour mon travail. | Should | V1 | ✅ | Retrait ≥ 20 DT dans la limite du solde (solde transactionnel vérifié par les règles), virement / portefeuille / espèces, suivi du statut. Paiement effectif : admin (epic 12). |
| US-053 | Collecteur | En tant que collecteur, je veux signaler un citoyen absent ou une adresse introuvable afin de clore une mission impossible. | Should | V1 | ✅ | Après l'arrivée seulement : motif + photo, ticket admin, mission annulée sans pénalité pour le collecteur, créneau libéré. |
| US-054 | Collecteur | En tant que collecteur, je veux gérer mon véhicule et sa capacité afin de recevoir des missions adaptées. | Should | V1 | ✅ | Type, capacité (kg), volume (m³), immatriculation ; capacité utilisée par la recherche. |
| US-055 | Collecteur | En tant que collecteur, je veux enregistrer le dépôt de ma tournée au centre de tri ou chez le recycleur afin de assurer la traçabilité des lots. | Must | V1 | ✅ | Recycleur validé, collectes pesées, poids total par matière ; confirmation / refus par le recycleur. Contrôle qualité détaillé : US-080. |

## E06 — Optimisation IA des itinéraires

_Tournées multi-collectes optimisées (km, temps, carburant) sous contraintes de capacité et de créneaux._

| ID | Acteur | Story | Prio | Release | Statut | Notes |
|---|---|---|---|---|---|---|
| US-056 | Système | En tant que système, je dois regrouper plusieurs collectes proches dans une même tournée afin de réduire les déplacements du collecteur. | Should | V1 | ✅ | Regroupement glouton par densité (rayon paramétrable, capacité du véhicule), carte « tournée groupée suggérée » avec acceptation en un geste. |
| US-057 | Collecteur | En tant que collecteur, je veux obtenir l'ordre de visite optimal pour mes collectes du jour afin de économiser kilomètres, temps et carburant. | Should | V1 | ✅ | Solveur CVRPTW à un véhicule (insertion + 2-opt/or-opt, jamais pire que l'ordre naïf), carte numérotée, gain vs ordre naïf. Heuristique, pas un solveur exact : optimal non garanti. |
| US-058 | Système | En tant que système, je dois tenir compte de la capacité du véhicule et des créneaux horaires afin de produire des tournées réalistes. | Should | V1 | ✅ | Créneaux = contraintes dures, déchargement automatique si capacité dépassée ; 200 tournées aléatoires vérifiées à 100 %. Départ calé pour arriver au début du premier créneau. |
| US-059 | Système | En tant que système, je dois recalculer la tournée si une collecte est ajoutée, annulée ou retardée afin de rester optimal en temps réel. | Could | V2 | ✅ | Recalcul automatique à chaque ajout / annulation / retard (2–4 ms mesurés sur simulateur pour 4–5 arrêts, < 10 s pour 30), message in-app au collecteur. Push : epic 7. |
| US-060 | Collecteur | En tant que collecteur, je veux voir les économies estimées (km, temps, carburant, CO₂) de ma tournée afin de mesurer l'intérêt de l'optimisation. | Could | V2 | ✅ | Km, minutes, carburant (DT, conso par type de véhicule) et CO₂ évité (2,31 kg/L) ; bilan de la dernière journée terminée. Bilan de fin de journée non vu sur appareil. |
| US-061 | Système | En tant que système, je dois proposer au collecteur des missions compatibles avec son trajet en cours afin de augmenter son rendement. | Could | V2 | ✅ | Missions ouvertes du jour insérables dans la tournée (créneaux et capacité respectés) avec détour ≤ maximum paramétrable ; ajout en un geste. |
| US-062 | Administrateur | En tant que administrateur, je veux paramétrer les règles d'optimisation (poids des critères, détour maximal) afin de adapter l'algorithme à l'exploitation. | Could | V2 | ✅ | Poids km/attente, détour max, rayon de regroupement, facteur routier, vitesse, durée de collecte, prix carburant ; brouillon + simulation en direct sur 12 collectes ; publication historisée (règles : admin). Publication vérifiée par test UI, pas sur appareil. |

## E07 — Suivi temps réel & notifications

_Suivi du collecteur sur carte, ETA, notifications push/SMS, messagerie/appel masqué._

| ID | Acteur | Story | Prio | Release | Statut | Notes |
|---|---|---|---|---|---|---|
| US-063 | Citoyen | En tant que citoyen, je veux suivre la position du collecteur en temps réel sur une carte afin de savoir quand il arrive. | Must | MVP | ✅ | Position du collecteur publiée toutes les 5 s (liveLocations, lisible par le citoyen et le collecteur uniquement, et seulement en route / sur place ; effacée ensuite) ; carte avec camion et domicile, alerte si la position a plus de 45 s. Vérifié sur 2 simulateurs. |
| US-064 | Citoyen | En tant que citoyen, je veux voir l'heure d'arrivée estimée (ETA) afin de m'organiser. | Should | V1 | ✅ | ETA = distance × 1,3 (facteur routier) ÷ vitesse mesurée (8–90 km/h), sinon 25 km/h corrigés d’un facteur trafic selon l’heure (pointes 7–9 h et 17–19 h 30). Pas d’API trafic temps réel. Vérifié sur appareil (8 → 5 min). |
| US-065 | Utilisateur | En tant qu'utilisateur, je veux recevoir des notifications push à chaque changement de statut afin de rester informé. | Must | MVP | 🟨 | Chaque changement de statut crée une notification dans Firestore (boîte de réception, compteur non lus, notification locale et toast quand l’app est ouverte ; respecte les préférences). Le push hors application (FCM) est prêt dans functions/ mais demande le plan Blaze et la clé APNs. |
| US-066 | Collecteur | En tant que collecteur, je veux être notifié immédiatement d'une nouvelle mission à proximité afin de ne pas manquer d'opportunité. | Must | MVP | 🟨 | Nouvelle mission proposée → notification urgente au collecteur. Même limite hors application (Blaze + APNs). |
| US-067 | Utilisateur | En tant qu'utilisateur, je veux échanger par messagerie ou appel masqué avec l'autre partie de la collecte afin de coordonner sans divulguer mon numéro. | Should | V1 | 🟨 | Messagerie in-app (500 caractères, numéros masqués automatiquement, visible par les deux parties uniquement). Vérifiée dans les deux sens sur appareil. Appel masqué non livré : il faut un opérateur téléphonique (Twilio Proxy…). |
| US-068 | Utilisateur | En tant qu'utilisateur, je veux recevoir un SMS si je n'ai pas de connexion data afin de être prévenu malgré tout. | Could | V2 | 🟨 | Cloud Function écrite (SMS Twilio pour « arrivé » et « annulée » si aucun push n’a été délivré), non déployée : plan Blaze et compte Twilio requis. |

## E08 — Recycle Wallet & EcoPoints

_Portefeuille de points, règles d'attribution, catalogue de récompenses partenaires, anti-fraude, gamification._

| ID | Acteur | Story | Prio | Release | Statut | Notes |
|---|---|---|---|---|---|---|
| US-069 | Citoyen | En tant que citoyen, je veux recevoir des EcoPoints après la validation de ma collecte afin de être récompensé pour mon recyclage. | Must | V1 | ✅ | Crédit à la confirmation de remise, calculé sur la pesée réelle : Σ kg × coefficient matière × points/kg + bonus 1re collecte et gros dépôt. Sans serveur, c’est l’app qui écrit : les règles Firestore recalculent le montant et refusent tout écart ; une seule écriture par collecte. Rattrapage automatique des collectes déjà terminées. Vérifié sur appareil (142 points pour 2 collectes). |
| US-070 | Citoyen | En tant que citoyen, je veux consulter mon solde EcoPoints et l'historique de mes gains/dépenses afin de suivre mon Recycle Wallet. | Must | V1 | ✅ | Onglet Wallet : solde, gagnés / dépensés / en vérification, historique détaillé ; solde et kg sur l’accueil. |
| US-071 | Administrateur | En tant que administrateur, je veux définir les règles de calcul des EcoPoints (par kg, par matière, bonus) afin de piloter l'économie de points. | Must | V1 | ✅ | Écran admin : points/kg, coefficient par matière, bonus, parrainage, validité, seuils anti-fraude ; brouillon + simulation en direct, publication historisée (écriture admin uniquement). |
| US-072 | Citoyen | En tant que citoyen, je veux parcourir le catalogue de récompenses partenaires afin de choisir comment utiliser mes points. | Must | V1 | ✅ | Catalogue filtrable (réduction, produit recyclé, don), coût, stock, raison si indisponible. |
| US-073 | Citoyen | En tant que citoyen, je veux échanger mes points contre un coupon ou un QR utilisable chez le partenaire afin de profiter concrètement de mes points. | Must | V1 | ✅ | Échange en une transaction (coupon, dépense, stock), vérifiée par les règles (solde, coût, stock, wallet gelé). Coupon QR + code lisible ; validation par l’administration (recherche du code, « utilisé »). Pas encore d’espace partenaire pour scanner lui-même. |
| US-074 | Administrateur | En tant que administrateur, je veux gérer les partenaires et leurs offres (réductions, produits recyclés) afin de alimenter le catalogue de récompenses. | Should | V1 | ✅ | Gestion admin des partenaires et des offres (création, modification, activation, stock). |
| US-075 | Système | En tant que système, je dois détecter les comportements frauduleux (collectes fictives, doublons) afin de protéger l'intégrité des points. | Should | V2 | ✅ | Mise en attente automatique imposée par les règles : poids > maximum, pesée > estimation × ratio, trop de collectes le même jour. Doublons impossibles (un gain par collecte, code de remise à usage unique). File de contrôle admin : créditer, refuser, geler le wallet. 31 scénarios de fraude rejoués sur l’émulateur. |
| US-076 | Citoyen | En tant que citoyen, je veux gagner des badges et des niveaux selon mon activité afin de rester motivé. | Could | V2 | ✅ | 5 niveaux (Graine → Forêt) avec progression, 10 badges (collectes, kg, matières, parrainage, 1re récompense). |
| US-077 | Citoyen | En tant que citoyen, je veux parrainer un proche et gagner des points bonus afin de faire grandir la communauté. | Could | V2 | ✅ | Code personnel, saisie du code d’un parrain avant la 1re collecte ; bonus au parrain à la 1re collecte du filleul, dans la même transaction. Auto-parrainage refusé. |
| US-078 | Citoyen | En tant que citoyen, je veux faire expirer/geler mes points selon des règles claires afin de comprendre la politique de points. | Could | V2 | 🟨 | Politique affichée (validité, attente, gel), points expirant sous 30 jours et prochaine échéance ; expiration FIFO appliquée à l’ouverture du wallet ; gel par l’administration. Sans tâche planifiée (Blaze), l’expiration n’est pas appliquée tant que le citoyen n’ouvre pas son wallet. |

## E09 — Espace recycleur – dashboard & stocks

_Réception des lots, traçabilité, stocks par matière (PET, HDPE, PP, autres), rapports et export._

| ID | Acteur | Story | Prio | Release | Statut | Notes |
|---|---|---|---|---|---|---|
| US-079 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux consulter un dashboard des quantités collectées par type (PET, HDPE, PP, autres) afin de suivre mes approvisionnements. | Must | V1 | ✅ | Dashboard des kg reçus par matière (PET, PEHD, PP, carton, aluminium, verre, autres), livraisons, qualité moyenne pondérée, réceptions par semaine, top collecteurs, aperçu du stock. Vérifié sur appareil. |
| US-080 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux enregistrer la réception d'un lot livré par un collecteur (poids, contrôle qualité) afin de valider l'entrée en stock. | Must | V1 | ✅ | Réception d’un dépôt : poids pesés par matière (pré-remplis avec la déclaration du collecteur, reclassement PET / PEHD / PP possible), qualité A/B/C, taux d’indésirables, remarque, alerte si écart > 15 %. Crée un lot par matière ; règles : un lot de réception n’existe que lié à un dépôt confirmé par ce recycleur. |
| US-081 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux gérer mon stock par matière et par qualité afin de connaître ce que je peux vendre. | Must | V1 | ✅ | Stock par matière et par qualité, liste des lots (forme, qualité, date, restant), sorties de stock (vente, perte, ajustement) contrôlées ; le poids d’un lot ne peut que baisser. |
| US-082 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux filtrer les quantités par période, zone géographique et collecteur afin de analyser mes flux. | Should | V1 | ✅ | Filtres période (7 j, 30 j, 3 mois, 12 mois), zone et collecteur, appliqués aux indicateurs, graphiques et exports. |
| US-083 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux exporter mes rapports en PDF ou Excel afin de les partager en interne. | Should | V1 | ✅ | Export PDF (police embarquée, accents) et Excel .xlsx (feuilles Synthèse et Lots), partagés via la feuille de partage. En arabe, le rapport est produit en français (police sans glyphes arabes). Vérifié sur appareil. |
| US-084 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux tracer l'origine d'un lot jusqu'aux collectes afin de garantir la traçabilité. | Should | V2 | ✅ | Fiche lot : collecteur, dépôt, zones et collectes d’origine (instantané pris au dépôt : identifiant, zone, jour, kg, sans adresse du citoyen) ; pour un produit transformé, lots consommés cliquables ; historique des mouvements. |
| US-085 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux définir mes capacités et prix d'achat par matière afin de orienter les livraisons. | Could | V2 | ✅ | Prix d’achat et capacité mensuelle par matière (matière acceptée ou non) ; visibles des collecteurs à l’écran de dépôt (meilleurs prix). Seul le champ « purchasing » est modifiable par le recycleur validé. |
| US-086 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux recevoir une notification quand un lot est en route afin de préparer la réception. | Could | V2 | ✅ | Notification « Un lot arrive » au recycleur quand le collecteur enregistre son dépôt (règles : seulement du collecteur du dépôt vers son recycleur) ; compteur de lots en route. Push hors application : même limite que l’epic 7 (Blaze). |
| US-087 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux déclarer la production de matière recyclée (granulés, paillettes…) afin de alimenter la marketplace. | Could | V2 | ✅ | Déclaration de production (paillettes, granulés, balles) : consommation FIFO des lots bruts, rendement contrôlé (sortie ≤ entrée), lot produit traçable jusqu’à ses lots d’origine, option « proposer sur la marketplace » (epic 11). |

## E10 — Prédiction IA des volumes

_Prévision des volumes de plastique par zone, cartes de chaleur, alertes et suivi de précision du modèle._

| ID | Acteur | Story | Prio | Release | Statut | Notes |
|---|---|---|---|---|---|---|
| US-088 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux voir la prévision des volumes de plastique par zone (7 et 30 jours) afin de planifier mon approvisionnement. | Should | V2 | ⬜ |  |
| US-089 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux intégrer les prévisions dans mon dashboard afin de décider avec des données. | Should | V2 | ⬜ |  |
| US-090 | Administrateur | En tant que administrateur, je veux visualiser une carte de chaleur des zones à fort potentiel de déchets afin de déployer les collecteurs au bon endroit. | Could | V2 | ⬜ |  |
| US-091 | Administrateur | En tant que administrateur, je veux recevoir des alertes de sous-collecte ou de surcharge prévue afin de anticiper les déséquilibres. | Could | V2 | ⬜ |  |
| US-092 | Administrateur | En tant que administrateur, je veux suivre la précision du modèle de prévision (MAPE) afin de juger de sa fiabilité. | Could | V2 | ⬜ |  |
| US-093 | Système | En tant que système, je dois réentraîner automatiquement le modèle de prévision avec les nouvelles données afin de conserver sa pertinence. | Could | V2 | ⬜ |  |

## E11 — Marketplace circulaire B2B

_Demandes d'achat et offres de vente de matières recyclées, recherche, négociation, commandes et notation._

| ID | Acteur | Story | Prio | Release | Statut | Notes |
|---|---|---|---|---|---|---|
| US-094 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux publier une demande d'achat (matière, quantité, lieu, date limite) afin de trouver des recycleurs disposant de la matière. | Should | V2 | ⬜ |  |
| US-095 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux publier une offre de vente de matières recyclées afin de trouver des acheteurs. | Should | V2 | ⬜ |  |
| US-096 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux rechercher et filtrer les annonces (matière, région, quantité, date) afin de repérer les opportunités. | Should | V2 | ⬜ |  |
| US-097 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux répondre à une demande avec une offre (prix, quantité, délai) afin de conclure des affaires. | Should | V2 | ⬜ |  |
| US-098 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux négocier via une messagerie sécurisée afin de convenir des conditions. | Could | V2 | ⬜ |  |
| US-099 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux accepter une offre et générer une commande afin de formaliser l'accord. | Should | V2 | ⬜ |  |
| US-100 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux suivre le statut de ma commande jusqu'à la livraison afin de garder la visibilité. | Could | V2 | ⬜ |  |
| US-101 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux noter et évaluer mes partenaires commerciaux afin de bâtir la confiance. | Could | V2 | ⬜ |  |
| US-102 | Système | En tant que système, je dois suggérer les annonces correspondant à mon stock ou à mes besoins afin de gagner du temps. | Could | V2 | ⬜ |  |
| US-103 | Administrateur | En tant que administrateur, je veux modérer les annonces et signalements afin de maintenir la qualité de la marketplace. | Should | V2 | ⬜ |  |
| US-104 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux payer et facturer via la plateforme afin de sécuriser les transactions. | Could | V2 | ⬜ |  |
| US-105 | Recycleur / Entreprise | En tant que recycleur / entreprise, je veux télécharger un certificat de recyclage pour mes lots afin de justifier ma démarche RSE. | Could | V2 | ⬜ |  |

## E12 — Administration & supervision

_Gestion des utilisateurs, validations, carte des collectes, statistiques, CO₂ évité, litiges et journal d'audit._

| ID | Acteur | Story | Prio | Release | Statut | Notes |
|---|---|---|---|---|---|---|
| US-106 | Administrateur | En tant que administrateur, je veux gérer les comptes utilisateurs (recherche, blocage, réactivation) afin de assurer la sécurité de la plateforme. | Must | MVP | ⬜ |  |
| US-107 | Administrateur | En tant que administrateur, je veux valider ou refuser les dossiers des collecteurs et recycleurs afin de garantir la fiabilité des professionnels. | Must | MVP | ⬜ |  |
| US-108 | Administrateur | En tant que administrateur, je veux voir sur une carte toutes les collectes en cours et planifiées afin de superviser l'activité en temps réel. | Must | MVP | ⬜ |  |
| US-109 | Administrateur | En tant que administrateur, je veux consulter les statistiques globales (tonnes recyclées par matière, collectes, utilisateurs actifs) afin de mesurer la performance. | Must | MVP | ⬜ |  |
| US-110 | Administrateur | En tant que administrateur, je veux voir le CO₂ estimé évité afin de mesurer l'impact environnemental. | Should | V1 | ⬜ |  |
| US-111 | Administrateur | En tant que administrateur, je veux suivre les performances du système (taux de matching, délai moyen, précision IA, taux d'annulation) afin de piloter la qualité du service. | Should | V1 | ⬜ |  |
| US-112 | Administrateur | En tant que administrateur, je veux traiter les litiges et signalements afin de résoudre les conflits équitablement. | Should | V1 | ⬜ |  |
| US-113 | Administrateur | En tant que administrateur, je veux gérer les rôles et permissions des administrateurs afin de limiter l'accès aux fonctions sensibles. | Should | V1 | ⬜ |  |
| US-114 | Administrateur | En tant que administrateur, je veux consulter le journal d'audit des actions sensibles afin de assurer la traçabilité. | Should | V1 | ⬜ |  |
| US-115 | Administrateur | En tant que administrateur, je veux exporter des rapports (PDF/Excel) pour les partenaires et institutions afin de communiquer sur les résultats. | Could | V2 | ⬜ |  |
| US-116 | Administrateur | En tant que administrateur, je veux envoyer des annonces et notifications à un segment d'utilisateurs afin de informer la communauté. | Could | V2 | ⬜ |  |
| US-117 | Administrateur | En tant que administrateur, je veux définir les zones géographiques desservies afin de limiter les demandes aux zones opérationnelles. | Should | MVP | ⬜ |  |

## E13 — Statistiques & impact citoyen

_Tableau de bord personnel, CO₂ évité, conseils de tri, défis et partage._

| ID | Acteur | Story | Prio | Release | Statut | Notes |
|---|---|---|---|---|---|---|
| US-118 | Citoyen | En tant que citoyen, je veux consulter mon tableau de bord personnel (kg recyclés, nombre de collectes, valeur cumulée) afin de voir ma contribution. | Should | V1 | ⬜ |  |
| US-119 | Citoyen | En tant que citoyen, je veux voir le CO₂ que j'ai évité grâce à mon recyclage afin de mesurer mon impact. | Should | V1 | ⬜ |  |
| US-120 | Citoyen | En tant que citoyen, je veux consulter des conseils de tri et de réduction des déchets afin de mieux recycler. | Should | V1 | ⬜ |  |
| US-121 | Citoyen | En tant que citoyen, je veux participer à des défis communautaires (quartier, ville) afin de m'engager collectivement. | Could | V2 | ⬜ |  |
| US-122 | Citoyen | En tant que citoyen, je veux partager mes résultats sur les réseaux sociaux afin de sensibiliser mon entourage. | Could | V2 | ⬜ |  |

## E14 — Exigences transverses & qualité

_Sécurité, performance, disponibilité, hors-ligne, conformité données, accessibilité, CI/CD, monitoring._

| ID | Acteur | Story | Prio | Release | Statut | Notes |
|---|---|---|---|---|---|---|
| US-123 | Système | En tant que système, je dois chiffrer toutes les communications (TLS) et protéger les API par JWT et contrôle d'accès par rôle afin de sécuriser les données. | Must | MVP | ⬜ |  |
| US-124 | Système | En tant que système, je dois répondre aux scans en moins de 5 s (inférence + réseau) dans 90 % des cas afin de offrir une expérience fluide. | Must | MVP | ⬜ |  |
| US-125 | Système | En tant que système, je dois garantir une disponibilité d'au moins 99 % afin de fiabiliser le service. | Should | V1 | ⬜ |  |
| US-126 | Collecteur | En tant que collecteur, je veux conserver mes missions et enregistrer mes actions en mode hors ligne partiel afin de travailler en zone de faible couverture. | Should | V1 | ⬜ |  |
| US-127 | Système | En tant que système, je dois se conformer à la loi organique tunisienne sur la protection des données personnelles afin de respecter le cadre légal. | Must | MVP | ⬜ |  |
| US-128 | Système | En tant que système, je dois fonctionner sur Android et iOS avec une base de code Flutter unique afin de toucher tous les utilisateurs. | Must | MVP | ⬜ |  |
| US-129 | Système | En tant que système, je dois appliquer un design system Flutter cohérent et accessible (contrastes, tailles, lecteur d'écran) afin de garantir une bonne ergonomie. | Should | V1 | ⬜ |  |
| US-130 | Système | En tant que système, je dois disposer d'une chaîne CI/CD avec tests automatisés (unitaires, widgets, intégration) afin de livrer de façon fiable. | Should | MVP | ⬜ |  |
| US-131 | Système | En tant que système, je dois centraliser logs, métriques et rapports de plantage afin de détecter et corriger rapidement les incidents. | Should | V1 | ⬜ |  |
| US-132 | Système | En tant que système, je dois sauvegarder automatiquement les bases de données et fichiers afin de éviter toute perte de données. | Must | MVP | ⬜ |  |

## Transverse (E14) déjà amorcé

- US-127 (conformité données) : consentement explicite et versionné enregistré à l'inscription, politique de confidentialité, suppression de compte — reste : traçabilité complète et droit d'accès.
- US-128 (Android + iOS, base Flutter unique) : build iOS simulateur validé ; Android configuré (minSdk 23), non buildé.
- US-129 (design system) : composants réutilisables dans `lib/core/widgets/`, sémantique d'accessibilité, respect de « réduire les animations ».
- US-123 (sécurité) : règles Firestore par rôle déployées (`firestore.rules`), y compris scans privés et catalogue/modèles en écriture admin.
- US-124 (scan < 5 s) : inférence sur l'appareil mesurée à 1,4–2,8 s (simulateur) et affichée à l'utilisateur.
- Qualité : les règles Firestore ne sont pas couvertes par `flutter test` (fake sans règles). `tool/firestore_rules_probe.py` rejoue 34 écritures réelles (citoyen / collecteur / recycleur) contre l'émulateur ; il a révélé une faille (retrait supérieur au solde), corrigée. À brancher dans la CI (US-130).
- Développement local : Emulator Suite (`firebase emulators:start --only auth,firestore`, JDK 21) + `flutter run --dart-define=USE_FIREBASE_EMULATORS=true`.
