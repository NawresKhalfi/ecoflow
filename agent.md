# ecoflow — instructions de travail

Application Flutter ecoflow qui permet : met en relation les citoyens, les collecteurs et les entreprises de recyclage.
Imagine quelqu’un qui a chez lui 20 bouteilles en plastique, des cartons ou des canettes. Au lieu de les jeter, il ouvre l’application, prend une photo et l’IA reconnaît les déchets. La plateforme lui permet ensuite de demander une collecte.
📱 Fonctionnement
1. Le citoyen photographie ses déchets
Par exemple, il prend en photo un sac contenant des bouteilles.
L’IA peut utiliser YOLO pour détecter et classifier :
🧴 Bouteilles PET : 12
🥫 Canettes : 4
📦 Carton : détecté
♻️ Recyclabilité estimée : élevée

L’IA estime la quantité et la valeur La plateforme pourrait calculer approximativement : 2,4 kg de plastique → valeur estimée : X DT Le prix réel pourrait ensuite être confirmé par le collecteur après pesée.
L'utilisateur demande une collecte Il sélectionne son emplacement et une plage horaire. La plateforme recherche alors un collecteur disponible à proximité.
Le collecteur reçoit la mission Il dispose d'une application avec : 📍 localisation de la collecte ♻️ type de déchets ⚖️ quantité estimée 🗺️ itinéraire 💰 valeur estimée L'IA peut également optimiser son trajet s'il doit effectuer plusieurs collectes.
Les déchets arrivent chez le recycleur Le recycleur dispose d'un dashboard pour voir les quantités collectées : Plastique Quantité PET 850 kg HDPE 320 kg PP 180 kg Autres 75 kg
L’IA peut ensuite prévoir les volumes futurs.
🧠 Où intervient réellement l'IA ?
C'est important pour que ton projet ne soit pas simplement une application de collecte avec le mot « IA ».
Tu pourrais avoir 4 modules IA :
Vision IA → reconnaissance automatique des déchets avec YOLOv8/YOLO11.
Estimation intelligente → estimation de la quantité/poids à partir des informations disponibles, avec confirmation humaine lorsque la photo ne suffit pas.
Prédiction → prévoir les volumes de plastique qui seront disponibles dans chaque zone.
Optimisation → déterminer les meilleurs itinéraires pour les collecteurs afin de réduire kilomètres, temps et carburant.
💰 Et je rajouterais une idée intéressante
Au lieu de simplement donner des points virtuels, tu peux créer un Recycle Wallet.
Chaque collecte validée donne des EcoPoints :
Déchets → collecte → pesée → validation → EcoPoints
Ces points peuvent ensuite donner droit à des récompenses proposées par des partenaires : réductions, produits recyclés, avantages, etc.
Cela donne une raison concrète aux utilisateurs de continuer à recycler.
🏭 Marketplace circulaire
C'est probablement la partie qui différencie le plus le projet.
La plateforme ne s'arrête pas au citoyen.
Citoyen → Collecteur → Centre de tri → Recycleur → Entreprise
Une entreprise pourrait par exemple publier :
🔎 Recherche : 500 kg PET transparent recyclé
📍 Sousse
📅 Besoin avant le 20 octobre

Les recycleurs disposant de cette matière peuvent répondre.
La plateforme devient donc également un marketplace B2B des matières recyclables.
📲 Les 4 espaces de la plateforme
Je construirais le projet autour de 4 interfaces :
👤 Citoyen
→ scanner ses déchets, demander une collecte, suivre le collecteur, consulter ses statistiques et EcoPoints.
🚚 Collecteur
→ missions disponibles, navigation, validation du poids, historique et revenus.
🏭 Recycleur / entreprise
→ acheter/vendre des matières recyclées, gérer les stocks et consulter les prévisions IA.
🖥️ Administrateur
→ utilisateurs, collecteurs, carte des collectes, statistiques, tonnes recyclées, CO₂ estimé évité et performances du système. . Le backlog produit
(132 user stories, 14 epics) vit dans
`spec/EcoFlow_Epics_UserStories.xlsx`. C'est la source de
vérité pour ce qu'il faut construire.

## Méthode de travail (à respecter à chaque nouvelle fonctionnalité)

1. **Implémenter feature par feature**, jamais plusieurs epics en parallèle.
   Une "feature" = un epic du backlog (ou un sous-ensemble cohérent si l'epic
   est gros). Ne pas anticiper les epics suivants au-delà du strict nécessaire
   pour brancher un écran de transition minimal.
2. **Suivi des fonctionnalités** : `docs/FEATURES.md` liste les 132 user
   stories groupées par epic avec un statut (⬜ non démarré / 🟨 en cours /
   ✅ implémenté). Mettre à jour ce fichier à la fin de chaque feature —
   c'est le "check" de ce qui a déjà été livré, à consulter avant de
   commencer une nouvelle feature pour éviter les doublons.
3. **Tests obligatoires pour chaque feature** :
   - Tests unitaires pour la logique (controllers Riverpod, resolvers,
     validators, repositories) sous `test/.../application|domain|data/`.
   - Tests UI (widget tests Flutter) pour les écrans, sous
     `test/.../presentation/`. Ils tournent via la **virtualisation Flutter**
     (`flutter test`, le "flutter tester" headless) — **pas** de device réel
     ni `integration_test`. (Le dossier `ui-test/` à la racine est un sujet
     séparé : smoke test Maestro/Firebase App Distribution sur device réel en
     CI, ne pas le confondre avec les tests Flutter du dossier `test/`.)
   - Lancer `flutter test` avant de considérer une feature terminée.
4. **Fichiers courts** : viser max ~500 lignes par fichier. Découper en
   petits widgets/fonctions plutôt que des fichiers monolithiques.
5. **Organisation en dossiers/sous-dossiers**, miroir entre `lib/` et `test/`
   (voir structure ci-dessous).
6. **Vérification visuelle après chaque feature** : lancer l'app sur un
   simulateur iOS (`flutter run -d <simulator-id>`), naviguer le parcours,
   prendre des captures d'écran (`xcrun simctl io <udid> screenshot ...` ou
   la commande `s` de `flutter run` qui écrit dans `screenshots/`), et
   vérifier que le rendu est correct avant de clore la tâche.


## Architecture technique

- **State management** : Riverpod (`flutter_riverpod`, `Notifier`/
  `NotifierProvider`). Toute logique métier vit dans des controllers
  Riverpod testables sans widget (via `ProviderContainer` en test).
- **Navigation** : `go_router`. Router déclaré dans
  `lib/core/router/app_router.dart`.
- **Stockage local** : `shared_preferences` via le wrapper
  `lib/core/storage/local_preferences.dart` (`LocalPreferences`), injecté
  par provider (`localPreferencesProvider`, surchargé dans `main.dart` avec
  l'instance réelle chargée avant `runApp`). Chaque feature ajoute son
  propre "local store" typé dans sa couche `data/` plutôt que de manipuler
  des clés brutes partout. Si une feature a besoin de données relationnelles
  plus riches , réévaluer vers une solution
  structurée (ex. Drift) le moment venu — ne pas le faire prématurément.
- **Firebase** : uniquement avec consentement explicite de l'utilisateur . Ne jamais pousser de données par défaut.
- **i18n** : `flutter gen-l10n` (fichiers source dans `lib/l10n/arb/`,
  généré dans `lib/l10n/gen/`, non versionné — régénéré automatiquement par
  `flutter pub get` / `flutter run` / `flutter test` grâce à
  `generate: true` dans `pubspec.yaml`). Langue française = template ARB.
  Langues supportées déclarées dans
  `lib/core/localization/app_language.dart` (garder en phase avec les
  fichiers `.arb` ajoutés). Le choix de langue déduit de la locale du
  téléphone est résolu par `lib/core/localization/locale_resolver.dart`
  (fonction pure, testée unitairement).
- **Thème** : `lib/core/theme/app_theme.dart`.
    l'application responsive design selon le cahier de spécifications ; Je souhaite une interface Modern Layered Premium UI, moderne, élégante, expressive et visuellement riche, sans adopter une approche minimaliste ni l’apparence classique de Material Design. L’interface doit créer une véritable sensation de profondeur grâce à une combinaison de cartes superposées, sections colorées, panneaux flottants, formes décoratives, illustrations modernes, dégradés subtils et ombres travaillées. Utiliser une palette claire et sophistiquée avec un fond légèrement teinté plutôt qu’un blanc pur, accompagnée d’une couleur principale forte et de plusieurs couleurs secondaires harmonieuses pour différencier les fonctionnalités, les statistiques, les alertes et les actions importantes. Les écrans doivent être dynamiques et généreux visuellement : grandes cartes, headers illustrés, widgets, badges, chips, avatars, graphiques, boutons expressifs et blocs d’information clairement séparés. La typographie doit avoir du caractère, avec de grands titres, différents niveaux de graisse et une hiérarchie visuelle marquée. Les composants peuvent utiliser des coins généreusement arrondis, des ombres douces, des effets de profondeur et quelques gradients maîtrisés, sans tomber dans le glassmorphism excessif. Ajouter des micro-animations fluides, des transitions entre les cartes et de légers effets interactifs afin que l’application paraisse vivante. L’objectif est d'obtenir une application premium, chaleureuse, moderne et mémorable, avec une identité graphique forte et beaucoup plus de richesse visuelle qu’une interface minimaliste. je t'ai donné le prototype .
## Structure des dossiers

```
lib/
  main.dart                 # init Firebase + SharedPreferences + runApp
  app.dart                  # MaterialApp.router, theme, locale, l10n
  core/                     # infra transverse, pas de logique métier produit
    router/
    theme/
    storage/
    localization/
  features/
    <feature>/               # un dossier par epic/feature (ex: onboarding)
      domain/                 # modèles, enums, règles pures
      data/                   # repositories / local stores
      application/            # controllers Riverpod (state + use cases)
      presentation/
        screens/
        widgets/
  l10n/
    arb/                     # sources traduisibles (app_fr.arb = template)
    gen/                     # généré, gitignored

test/
  core/...                  # miroir de lib/core
  features/<feature>/
    domain/ data/ application/ presentation/   # miroir de lib/features/<feature>
```

## État d'avancement

Voir `docs/FEATURES.md` pour le détail complet epic par epic.
