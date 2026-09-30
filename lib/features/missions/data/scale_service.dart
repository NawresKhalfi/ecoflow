import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../domain/scale_protocol.dart';

typedef ScaleDevice = ({String id, String name});

/// Balance connectée (US-049). Non testée sur matériel : toute balance
/// respectant le profil Bluetooth standard « Weight Scale » est visée ;
/// la saisie manuelle reste toujours disponible.
abstract interface class ScaleService {
  Stream<List<ScaleDevice>> scan();

  /// Poids successifs (kg) envoyés par la balance.
  Stream<double> readings(String deviceId);
}

class BleScaleService implements ScaleService {
  final _ble = FlutterReactiveBle();
  final _service = Uuid.parse(weightScaleService);
  final _characteristic = Uuid.parse(weightMeasurementCharacteristic);

  @override
  Stream<List<ScaleDevice>> scan() {
    final found = <String, ScaleDevice>{};
    return _ble
        .scanForDevices(withServices: [_service])
        .map((d) {
          found[d.id] = (id: d.id, name: d.name.isEmpty ? d.id : d.name);
          return found.values.toList();
        })
        .timeout(const Duration(seconds: 20), onTimeout: (sink) => sink.close());
  }

  @override
  Stream<double> readings(String deviceId) async* {
    await for (final update in _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 10),
    )) {
      if (update.connectionState != DeviceConnectionState.connected) continue;
      final c = QualifiedCharacteristic(
        serviceId: _service,
        characteristicId: _characteristic,
        deviceId: deviceId,
      );
      await for (final bytes in _ble.subscribeToCharacteristic(c)) {
        final kg = parseWeightMeasurement(bytes);
        if (kg != null) yield kg;
      }
    }
  }
}
