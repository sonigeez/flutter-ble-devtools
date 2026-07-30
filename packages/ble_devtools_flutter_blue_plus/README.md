# ble_devtools_flutter_blue_plus

FlutterBluePlus instrumentation for [Flutter BLE DevTools](https://github.com/sonigeez/flutter-ble-devtools). It records your BLE session and ships the **BLE DevTools** Flutter DevTools extension.

```yaml
dependencies:
  ble_devtools_flutter_blue_plus: ^0.1.0
```

```dart
final bleTrace = FlutterBluePlusBleDevTools();
await bleTrace.start();

// Existing FlutterBluePlus global streams record scan results, connection,
// MTU, RSSI, service discovery, writes, descriptors, and bonding.
await bleTrace.startScan(timeout: const Duration(seconds: 15));

// Use these helpers where event type matters; a receive event alone cannot
// tell a characteristic read apart from a notification.
final value = await bleTrace.readCharacteristic(characteristic);
await bleTrace.writeCharacteristic(characteristic, [0x08]);
await bleTrace.setNotifications(characteristic, true);

// Record what only your application knows.
bleTrace.recordOperation(
  kind: BleEventKind.reconnectAttempt,
  deviceId: device.remoteId.toString(),
  metadata: {'attempt': 1, 'result': 'failed'},
);
```

Open Flutter DevTools while attached to the application, then select **BLE DevTools** in its navigation. The adapter exposes the live trace through `ext.ble_devtools.getTrace`; the panel refreshes it every 500 ms and lets you pause, inspect bytes, and export a report.

## What is recorded

FlutterBluePlus global events cover scan results, connection state, MTU, RSSI, services, descriptors, writes, and bonding. Use the adapter helpers for reads, writes, and notification configuration because a received byte stream cannot honestly distinguish a read response from a notification on its own.

For app-specific protocol activity, call `recordOperation`. BLE tooling that claims it can infer your proprietary retry state from vibes is lying to you.

## Privacy boundary

Exports pseudonymize device IDs and advertising names. They preserve raw GATT payloads because that is frequently the only useful evidence. Do not attach traces containing application secrets to public bug reports; Bluetooth debugging is not an excuse to post credentials on the internet.

See the [repository README](https://github.com/sonigeez/flutter-ble-devtools#flutter-ble-devtools) for DevTools setup, trace format, and development instructions.
