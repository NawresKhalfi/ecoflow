import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

enum PickSource { camera, gallery }

typedef PickedFile = ({String name, Uint8List bytes});

/// Sélection d'une photo de document, compressée à la source.
abstract interface class DocumentPicker {
  Future<PickedFile?> pick(PickSource source);
}

class ImagePickerDocumentPicker implements DocumentPicker {
  final _picker = ImagePicker();

  @override
  Future<PickedFile?> pick(PickSource source) async {
    final file = await _picker.pickImage(
      source: source == PickSource.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1400,
      maxHeight: 1400,
      imageQuality: 60,
    );
    if (file == null) return null;
    return (name: file.name, bytes: await file.readAsBytes());
  }
}
