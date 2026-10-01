# Modèle de vision embarqué

- Modèle : `HrutikAdsare/waste-detection-yolov8` (Hugging Face), YOLOv8m, détection, 8 classes
  (cardboard, e-waste, glass, medical, metal, organic, paper, plastic), entrée 512 px.
- Licence : MIT (auteur : Hrutik Adsare).
- Exports réalisés pour EcoFlow avec Ultralytics :
  - iOS : Core ML int8 avec NMS intégré → `waste_yolov8m.mlpackage.zip`
  - Android : LiteRT/TFLite → `waste_yolov8m.tflite`
- Rappel publié par l'auteur (matrice de confusion normalisée) : organique 96 %, papier 83 %,
  métal 81 %, carton 76 %, e-déchets 75 %, plastique 63 %, verre 60 %, médical 54 %.
