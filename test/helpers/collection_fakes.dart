import 'package:ecoflow/features/collection/data/collection_support_repositories.dart';
import 'package:ecoflow/features/collection/domain/geo.dart';
import 'package:ecoflow/features/profile/data/location_service.dart';

class FakeGeocoder implements ReverseGeocoder {
  @override
  Future<String?> addressOf(GeoPoint p, {String? languageCode}) async => 'Rue de test, Sousse';
}

class FakeLocation implements LocationService {
  FakeLocation([this.position]);
  ({double latitude, double longitude})? position;

  @override
  Future<({double latitude, double longitude})?> currentPosition() async => position;
}
