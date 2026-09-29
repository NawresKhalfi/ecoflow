import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../scan/domain/waste_category.dart';
import '../domain/yolo_dataset.dart';

/// Image anonymisée et ses annotations corrigées.
typedef DatasetItem = ({Uint8List jpeg, AnnotatedImage annotations});

/// Construit l'archive ZIP d'un jeu de données au format YOLO (US-020) :
/// `images/train/*.jpg`, `labels/train/*.txt`, `data.yaml`. Les noms de
/// fichiers sont séquentiels : aucun identifiant utilisateur n'est exporté.
Uint8List buildYoloDatasetZip(List<DatasetItem> items, List<WasteCategory> classes) {
  final archive = Archive();
  void add(String path, List<int> bytes) => archive.addFile(ArchiveFile(path, bytes.length, bytes));
  add('data.yaml', utf8.encode(yoloDataYaml(classes)));
  for (final item in items) {
    final name = item.annotations.name;
    add('images/train/$name.jpg', item.jpeg);
    add('labels/train/$name.txt', utf8.encode(yoloLabelFile(item.annotations, classes)));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
