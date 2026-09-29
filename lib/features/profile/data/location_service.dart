import 'package:geolocator/geolocator.dart';

/// Position GPS courante (US-005), injectable pour les tests.
abstract interface class LocationService {
  /// Renvoie `null` si la permission est refusée ou le GPS désactivé.
  Future<({double latitude, double longitude})?> currentPosition();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<({double latitude, double longitude})?> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    return (latitude: p.latitude, longitude: p.longitude);
  }
}
