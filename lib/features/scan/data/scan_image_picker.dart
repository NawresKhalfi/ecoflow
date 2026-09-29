import 'package:image_picker/image_picker.dart' hide PickedFile;

import '../../profile/data/document_picker.dart';

/// Photos sélectionnées pour un scan (appareil photo ou galerie).
abstract interface class ScanImagePicker {
  /// [max] : nombre maximal d'images encore acceptées.
  Future<List<PickedFile>> pick(PickSource source, {required int max});
}

class ImagePickerScanPicker implements ScanImagePicker {
  final _picker = ImagePicker();

  @override
  Future<List<PickedFile>> pick(PickSource source, {required int max}) async {
    if (max <= 0) return const [];
    final files = source == PickSource.camera
        ? [?await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 90)]
        : await _picker.pickMultiImage(limit: max < 2 ? 2 : max, maxWidth: 1600, imageQuality: 90);
    return [for (final f in files.take(max)) (name: f.name, bytes: await f.readAsBytes())];
  }
}
