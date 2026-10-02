#!/bin/sh
# Publie le site web d'EcoFlow sur Firebase Hosting (https://meteo-ba45f.web.app).
#   sh tool/deploy_web.sh
# Version web de l'app Flutter + modèles de vision téléchargeables par l'app
# mobile (hosting/models, US-019). Les modèles embarqués ne sont pas publiés
# avec le site : la détection YOLO ne tourne que sur iOS et Android.
set -e
cd "$(dirname "$0")/.."
flutter build web --release --no-wasm-dry-run
rm -rf build/hosting
cp -R build/web build/hosting
rm -rf build/hosting/assets/assets/models
cp -R hosting/models build/hosting/models
firebase deploy --only hosting --project meteo-ba45f
