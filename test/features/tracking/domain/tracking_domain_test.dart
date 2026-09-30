import 'package:ecoflow/features/collection/domain/geo.dart';
import 'package:ecoflow/features/profile/domain/notification_preferences.dart';
import 'package:ecoflow/features/tracking/domain/app_notification.dart';
import 'package:ecoflow/features/tracking/domain/chat.dart';
import 'package:ecoflow/features/tracking/domain/eta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const home = GeoPoint(35.8256, 10.6084);
  final noon = DateTime(2026, 10, 1, 11);

  test('ETA uses measured speed when plausible, else traffic model (US-064)', () {
    final from = LivePosition(point: const GeoPoint(35.8436, 10.6084), at: noon, speedKmh: 30);
    final km = distanceKm(from.point, home) * 1.3;
    expect(
      estimateArrival(from: from, to: home, now: noon).difference(noon).inSeconds,
      closeTo(km / 30 * 3600, 1),
    );
    final parked = LivePosition(point: from.point, at: noon, speedKmh: 0);
    final off = estimateArrival(from: parked, to: home, now: noon).difference(noon).inSeconds;
    final rush = estimateArrival(
      from: parked,
      to: home,
      now: DateTime(2026, 10, 1, 8),
    ).difference(DateTime(2026, 10, 1, 8)).inSeconds;
    expect(rush, closeTo(off * 1.6, 2), reason: 'rush hour is slower');
  });

  test('traffic factor by hour and stale positions (US-063)', () {
    expect(trafficFactor(DateTime(2026, 10, 1, 8)), 1.6);
    expect(trafficFactor(DateTime(2026, 10, 1, 13)), 1.25);
    expect(trafficFactor(DateTime(2026, 10, 1, 22)), 1.0);
    final p = LivePosition(point: home, at: noon);
    expect(isStale(p, noon.add(const Duration(seconds: 30))), isFalse);
    expect(isStale(p, noon.add(const Duration(minutes: 1))), isTrue);
  });

  test('status → notification mapping and preferences (US-065)', () {
    expect(statusNotification('accepted'), NotificationType.assigned);
    expect(statusNotification('arrived'), NotificationType.arrived);
    expect(statusNotification('inProgress'), isNull);
    expect(NotificationType.arrived.critical, isTrue);
    final off = NotificationPreferences.defaults.toggle(
      NotificationCategory.collectionStatus,
      false,
    );
    expect(allowedByPreferences(NotificationType.arrived, off), isFalse);
    expect(allowedByPreferences(NotificationType.message, off), isTrue);
  });

  test('phone numbers are masked in chat (US-067)', () {
    expect(maskPhoneNumbers('Appelle-moi au 22 123 456 stp'), 'Appelle-moi au •••• •••• stp');
    expect(maskPhoneNumbers('+216 98-765-432'), '•••• ••••');
    expect(maskPhoneNumbers('2e étage, code 1234'), '2e étage, code 1234');
    expect(validateMessage('  '), 'empty');
    expect(validateMessage('x' * 501), 'tooLong');
    expect(validateMessage('Ok'), isNull);
  });
}
