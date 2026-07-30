import 'dart:async';

import 'package:ble_devtools_core/ble_devtools_core.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Observes FlutterBluePlus' global event API and feeds a [BleTraceRecorder].
///
/// Call [start] before BLE work begins. The adapter does not monkey-patch a
/// static plugin API because Dart cannot do that without lying to you. Use the
/// small operation helpers below for scan boundaries and app-specific actions.
class FlutterBluePlusBleDevTools {
  FlutterBluePlusBleDevTools({BleTraceRecorder? recorder})
      : recorder = recorder ?? BleTraceRecorder(source: 'flutter_blue_plus');

  final BleTraceRecorder recorder;
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _scanResultFingerprints = <String>{};
  var _started = false;

  bool get isStarted => _started;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    recorder.registerDevToolsServiceExtensions();

    _subscriptions.add(FlutterBluePlus.adapterState.listen((state) {
      recorder.record(
          kind: BleEventKind.adapterState, metadata: {'state': state.name});
    }));
    _subscriptions.add(FlutterBluePlus.isScanning.listen((isScanning) {
      recorder.record(
          kind:
              isScanning ? BleEventKind.scanStarted : BleEventKind.scanStopped);
      if (isScanning) _scanResultFingerprints.clear();
    }));
    _subscriptions.add(FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        final deviceId = result.device.remoteId.toString();
        final fingerprint =
            '$deviceId:${result.rssi}:${result.advertisementData.advName}';
        if (_scanResultFingerprints.add(fingerprint)) {
          recorder.record(
            kind: BleEventKind.scanResult,
            deviceId: deviceId,
            metadata: {
              'name': result.advertisementData.advName,
              'rssi': result.rssi,
              'connectable': result.advertisementData.connectable,
            },
          );
        }
      }
    }, onError: (Object error, StackTrace stackTrace) {
      recorder.record(
          kind: BleEventKind.error,
          message: '$error',
          metadata: {'operation': 'scan'});
    }));
    _subscriptions
        .add(FlutterBluePlus.events.onConnectionStateChanged.listen((event) {
      final connected =
          event.connectionState == BluetoothConnectionState.connected;
      recorder.record(
        kind: connected ? BleEventKind.connection : BleEventKind.disconnection,
        deviceId: event.device.remoteId.toString(),
        metadata: {'state': event.connectionState.name},
      );
    }));
    _subscriptions.add(FlutterBluePlus.events.onMtuChanged.listen((event) {
      recorder.record(
        kind: BleEventKind.mtu,
        deviceId: event.device.remoteId.toString(),
        metadata: {
          'mtu': event.mtu,
          if (event.error != null) 'error': event.error.toString()
        },
      );
    }));
    _subscriptions.add(FlutterBluePlus.events.onReadRssi.listen((event) {
      recorder.record(
        kind: BleEventKind.rssi,
        deviceId: event.device.remoteId.toString(),
        metadata: {
          'rssi': event.rssi,
          if (event.error != null) 'error': event.error.toString()
        },
      );
    }));
    _subscriptions
        .add(FlutterBluePlus.events.onDiscoveredServices.listen((event) {
      recorder.record(
        kind: BleEventKind.serviceDiscovery,
        deviceId: event.device.remoteId.toString(),
        metadata: {
          'serviceCount': event.services.length,
          if (event.error != null) 'error': event.error.toString()
        },
      );
    }));
    _subscriptions
        .add(FlutterBluePlus.events.onCharacteristicReceived.listen((event) {
      recorder.record(
        kind: BleEventKind.notification,
        deviceId: event.device.remoteId.toString(),
        serviceUuid: event.characteristic.serviceUuid.toString(),
        characteristicUuid: event.characteristic.uuid.toString(),
        bytes: event.value,
        metadata: {if (event.error != null) 'error': event.error.toString()},
      );
    }));
    _subscriptions
        .add(FlutterBluePlus.events.onCharacteristicWritten.listen((event) {
      recorder.record(
        kind: BleEventKind.characteristicWrite,
        deviceId: event.device.remoteId.toString(),
        serviceUuid: event.characteristic.serviceUuid.toString(),
        characteristicUuid: event.characteristic.uuid.toString(),
        bytes: event.value,
        metadata: {if (event.error != null) 'error': event.error.toString()},
      );
    }));
    _subscriptions.add(FlutterBluePlus.events.onDescriptorRead.listen((event) {
      recorder.record(
        kind: BleEventKind.descriptorRead,
        deviceId: event.device.remoteId.toString(),
        descriptorUuid: event.descriptor.uuid.toString(),
        bytes: event.value,
      );
    }));
    _subscriptions
        .add(FlutterBluePlus.events.onDescriptorWritten.listen((event) {
      recorder.record(
        kind: BleEventKind.descriptorWrite,
        deviceId: event.device.remoteId.toString(),
        descriptorUuid: event.descriptor.uuid.toString(),
        bytes: event.value,
      );
    }));
    _subscriptions
        .add(FlutterBluePlus.events.onBondStateChanged.listen((event) {
      recorder.record(
        kind: BleEventKind.bonding,
        deviceId: event.device.remoteId.toString(),
        metadata: {'state': event.bondState.name},
      );
    }));
  }

  Future<void> startScan({Duration? timeout}) async {
    _ensureStarted();
    try {
      await FlutterBluePlus.startScan(timeout: timeout);
    } catch (error) {
      recorder.record(
          kind: BleEventKind.error,
          message: '$error',
          metadata: {'operation': 'startScan'});
      rethrow;
    }
  }

  Future<void> stopScan() async {
    _ensureStarted();
    try {
      await FlutterBluePlus.stopScan();
    } catch (error) {
      recorder.record(
          kind: BleEventKind.error,
          message: '$error',
          metadata: {'operation': 'stopScan'});
      rethrow;
    }
  }

  Future<void> connect(BluetoothDevice device,
      {required License license}) async {
    _ensureStarted();
    try {
      await device.connect(license: license);
    } catch (error) {
      recorder.record(
        kind: BleEventKind.error,
        deviceId: device.remoteId.toString(),
        message: '$error',
        metadata: {'operation': 'connect'},
      );
      rethrow;
    }
  }

  Future<List<BluetoothService>> discoverServices(
      BluetoothDevice device) async {
    _ensureStarted();
    try {
      return await device.discoverServices();
    } catch (error) {
      recorder.record(
        kind: BleEventKind.error,
        deviceId: device.remoteId.toString(),
        message: '$error',
        metadata: {'operation': 'discoverServices'},
      );
      rethrow;
    }
  }

  /// Reads a value while preserving the distinction between a read response
  /// and a notification, which FlutterBluePlus' global receive event lacks.
  Future<List<int>> readCharacteristic(
      BluetoothCharacteristic characteristic) async {
    _ensureStarted();
    try {
      final value = await characteristic.read();
      recorder.record(
        kind: BleEventKind.characteristicRead,
        deviceId: characteristic.remoteId.toString(),
        serviceUuid: characteristic.serviceUuid.toString(),
        characteristicUuid: characteristic.uuid.toString(),
        bytes: value,
      );
      return value;
    } catch (error) {
      recorder.record(
          kind: BleEventKind.error,
          message: '$error',
          metadata: {'operation': 'characteristic.read'});
      rethrow;
    }
  }

  Future<void> writeCharacteristic(
      BluetoothCharacteristic characteristic, List<int> value) async {
    _ensureStarted();
    try {
      await characteristic.write(value);
      recorder.record(
        kind: BleEventKind.characteristicWrite,
        deviceId: characteristic.remoteId.toString(),
        serviceUuid: characteristic.serviceUuid.toString(),
        characteristicUuid: characteristic.uuid.toString(),
        bytes: value,
      );
    } catch (error) {
      recorder.record(
          kind: BleEventKind.error,
          message: '$error',
          metadata: {'operation': 'characteristic.write'});
      rethrow;
    }
  }

  Future<void> setNotifications(
      BluetoothCharacteristic characteristic, bool enabled) async {
    _ensureStarted();
    try {
      await characteristic.setNotifyValue(enabled);
      recorder.record(
        kind: BleEventKind.notification,
        deviceId: characteristic.remoteId.toString(),
        serviceUuid: characteristic.serviceUuid.toString(),
        characteristicUuid: characteristic.uuid.toString(),
        message: enabled ? 'notifications enabled' : 'notifications disabled',
      );
    } catch (error) {
      recorder.record(
          kind: BleEventKind.error,
          message: '$error',
          metadata: {'operation': 'setNotifyValue'});
      rethrow;
    }
  }

  /// Records app-level operations that FlutterBluePlus cannot report globally.
  /// For example: permission result, PHY preference, or a reconnect policy.
  BleEvent recordOperation({
    required BleEventKind kind,
    String? deviceId,
    String? message,
    List<int>? bytes,
    Map<String, Object?> metadata = const {},
  }) =>
      recorder.record(
          kind: kind,
          deviceId: deviceId,
          message: message,
          bytes: bytes,
          metadata: metadata);

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _started = false;
  }

  void _ensureStarted() {
    if (!_started) {
      throw StateError(
          'Call FlutterBluePlusBleDevTools.start() before recording BLE operations.');
    }
  }
}
