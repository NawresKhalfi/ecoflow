import 'dart:async';

import 'package:ecoflow/features/tracking/application/tracking_providers.dart';
import 'package:ecoflow/features/tracking/data/device_services.dart';
import 'package:ecoflow/features/tracking/domain/eta.dart';
import 'package:flutter_riverpod/misc.dart';

class FakeNotifier implements LocalNotifier {
  final shown = <({String title, String body, String? payload, bool urgent})>[];

  @override
  Future<void> init(void Function(String payload) onTap) async {}

  @override
  Future<void> show(
    int id,
    String title,
    String body, {
    String? payload,
    bool urgent = false,
  }) async => shown.add((title: title, body: body, payload: payload, urgent: urgent));
}

class FakeTokenSource implements PushTokenSource {
  FakeTokenSource([this.value]);
  final String? value;
  @override
  Future<String?> token() async => value;
}

class FakePositions implements PositionStreamSource {
  final controller = StreamController<LivePosition>.broadcast();
  @override
  Stream<LivePosition> positions() => controller.stream;
}

/// Services natifs remplacés par défaut dans les tests.
List<Override> deviceFakes({FakeNotifier? notifier, FakePositions? positions}) => [
  localNotifierProvider.overrideWithValue(notifier ?? FakeNotifier()),
  pushTokenSourceProvider.overrideWithValue(FakeTokenSource()),
  positionStreamProvider.overrideWithValue(positions ?? FakePositions()),
];
