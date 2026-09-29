import '../../scan/domain/detection.dart';
import '../../scan/domain/waste_category.dart';

/// Une image annotée prête pour l'export.
class AnnotatedImage {
  const AnnotatedImage({required this.name, required this.detections});

  final String name;
  final List<Detection> detections;
}

/// Fichier `data.yaml` d'un jeu de données YOLO (US-020).
String yoloDataYaml(List<WasteCategory> classes) {
  final b = StringBuffer()
    ..writeln('# EcoFlow – corrections utilisateurs (images anonymisées)')
    ..writeln('path: .')
    ..writeln('train: images/train')
    ..writeln('val: images/train')
    ..writeln('nc: ${classes.length}')
    ..writeln('names:');
  for (final (i, c) in classes.indexed) {
    b.writeln('  $i: ${c.id}');
  }
  return b.toString();
}

/// Contenu du fichier d'étiquettes YOLO d'une image : une ligne
/// « classe cx cy w h » par objet encadré (les ajouts sans cadre sont ignorés).
String yoloLabelFile(AnnotatedImage image, List<WasteCategory> classes) {
  final index = {for (final (i, c) in classes.indexed) c.id: i};
  final lines = <String>[];
  for (final d in image.detections) {
    final box = d.box;
    final cls = index[d.categoryId];
    if (box == null || cls == null) continue;
    lines.add([cls, ...box.yolo.map((v) => v.clamp(0, 1).toStringAsFixed(6))].join(' '));
  }
  return lines.join('\n');
}
