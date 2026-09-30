import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import '../../collection/domain/geo.dart';
import '../domain/eta.dart';

/// Affichage de notifications sur l'appareil (avec son) — US-065/066.
abstract interface class LocalNotifier {
  Future<void> init(void Function(String payload) onTap);
  Future<void> show(int id, String title, String body, {String? payload, bool urgent = false});
}

class PluginLocalNotifier implements LocalNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  Future<void> init(void Function(String payload) onTap) async {
    if (_ready || kIsWeb) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) onTap(r.payload!);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  @override
  Future<void> show(int id, String title, String body, {String? payload, bool urgent = false}) async {
    if (!_ready) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          urgent ? 'ecoflow_missions' : 'ecoflow_updates',
          urgent ? 'Nouvelles missions' : 'Suivi des collectes',
          importance: urgent ? Importance.max : Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(presentSound: true, presentBanner: true, presentList: true),
      ),
    );
  }
}

/// Jeton FCM de l'appareil (null sur simulateur iOS sans APNs).
abstract interface class PushTokenSource {
  Future<String?> token();
}

class FirebasePushTokenSource implements PushTokenSource {
  @override
  Future<String?> token() async {
    try {
      final m = FirebaseMessaging.instance;
      await m.requestPermission();
      if (!kIsWeb && Platform.isIOS && await m.getAPNSToken() == null) return null;
      return await m.getToken();
    } catch (_) {
      return null;
    }
  }
}

/// Flux de positions GPS du collecteur (US-063).
abstract interface class PositionStreamSource {
  Stream<LivePosition> positions();
}

class GeolocatorPositionStream implements PositionStreamSource {
  @override
  Stream<LivePosition> positions() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
  ).map((p) => LivePosition(
        point: GeoPoint(p.latitude, p.longitude),
        at: DateTime.now(),
        speedKmh: p.speed >= 0 ? p.speed * 3.6 : null,
      ));
}
