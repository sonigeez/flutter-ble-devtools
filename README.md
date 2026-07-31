# Flutter BLE DevTools

[![CI](https://github.com/sonigeez/flutter-ble-devtools/actions/workflows/ci.yml/badge.svg)](https://github.com/sonigeez/flutter-ble-devtools/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Chrome DevTools for BLE in Flutter: inspect, replay, and share real-device Bluetooth failures.**

Flutter BLE DevTools helps Flutter teams inspect and troubleshoot Bluetooth Low Energy sessions on real devices. It records BLE activity from your app and presents it as a timeline in Flutter DevTools, including connections, GATT operations, MTU negotiation, notifications, RSSI, and reconnection attempts.

```text
14:02:11  Connected
14:02:12  MTU negotiated: 247
14:02:14  Write command: 0x08
14:02:17  Notification timeout
14:02:18  Android GATT status: 133
14:02:21  Reconnect attempt 1 failed
```

Export a sanitized `.bletrace` file and Markdown reproduction report to share a clear, structured record of a Bluetooth failure with your team or hardware vendor.

## What you get

- A live, ordered BLE timeline in Flutter DevTools.
- Scan results, permissions, connection state, GATT discovery, reads, writes, notifications, MTU, RSSI, PHY, bonding, and reconnect attempts.
- Elapsed time between events and a byte inspector for hex, UTF-8, and integer views.
- Sanitized `.bletrace` JSON and a Markdown reproduction report for support tickets and hardware vendors.
- A bounded in-memory recorder, so a long debugging session does not quietly become a memory leak wearing a lanyard.

## Packages

| Package | Use it for |
| --- | --- |
| [`ble_devtools_core`](packages/ble_devtools_core) | The library-agnostic trace model, recorder, byte decoding, export, and report generation. |
| [`ble_devtools_flutter_blue_plus`](packages/ble_devtools_flutter_blue_plus) | FlutterBluePlus instrumentation plus the packaged DevTools extension. |
| [`ble_devtools_extension`](packages/ble_devtools_extension) | The Flutter web source for the DevTools panel. It is bundled into the FlutterBluePlus adapter, not published separately. |

## Quick start: FlutterBluePlus

Add the adapter to the app you want to inspect:

```yaml
dependencies:
  ble_devtools_flutter_blue_plus: ^0.1.0
```

Start it before the BLE work you want to capture:

```dart
import 'package:ble_devtools_flutter_blue_plus/ble_devtools_flutter_blue_plus.dart';

final bleDevTools = FlutterBluePlusBleDevTools();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bleDevTools.start();
  runApp(const App());
}
```

Use the adapter for operations where the underlying global events cannot tell you what actually happened:

```dart
await bleDevTools.startScan(timeout: const Duration(seconds: 15));

final bytes = await bleDevTools.readCharacteristic(characteristic);
await bleDevTools.writeCharacteristic(characteristic, [0x08]);
await bleDevTools.setNotifications(characteristic, true);

bleDevTools.recordOperation(
  kind: BleEventKind.reconnectAttempt,
  deviceId: device.remoteId.toString(),
  metadata: {'attempt': 1, 'result': 'failed'},
);
```

The adapter also subscribes to FlutterBluePlus global streams for scan results, connection state, MTU, RSSI, service discovery, writes, descriptors, and bonding. It does not pretend to see calls made entirely outside it; wrap or explicitly record those operations.

## Open the DevTools panel

1. Run your Flutter app in debug or profile mode with the adapter started.
2. Open Flutter DevTools for that running app.
3. Select **BLE DevTools** in the DevTools navigation.
4. Exercise the device. The timeline polls the running app every 500 ms; pause it when you want to inspect a stable moment.
5. Select an event to inspect bytes. Use **Export repro** to download a `.bletrace` and Markdown report.

The extension reads the trace through the `ext.ble_devtools.getTrace` VM service extension. It does not need a cloud account, a BLE proxy, or a sacrifice to the Android GATT gods.

## Trace and privacy

`.bletrace` is versioned JSON designed to be portable between adapters and importable into the panel. Exports pseudonymize device identifiers and advertising names by default.

Payload bytes are preserved: deleting the byte that caused the failure is peak debugging theatre. That also means a trace can contain application-level secrets. Review it before sharing publicly and avoid placing credentials in BLE payloads in the first place.

## Compatibility

| Component | Requirement |
| --- | --- |
| Dart | 3.4 or newer |
| Flutter | 3.24 or newer (adapter and extension) |
| FlutterBluePlus adapter | `flutter_blue_plus` 2.3.11 or newer |
| App mode | Debug/profile for the live DevTools panel |

## Development

```sh
cd packages/ble_devtools_core
dart pub get
dart format --output=none --set-exit-if-changed lib test
dart analyze
dart test

cd ../ble_devtools_flutter_blue_plus
flutter pub get
flutter analyze
flutter test

cd ../ble_devtools_extension
flutter pub get
flutter analyze
flutter build web --release
dart run devtools_extensions build_and_copy \
  --source=. --dest=../ble_devtools_flutter_blue_plus/extension/devtools
dart run devtools_extensions validate \
  --package=../ble_devtools_flutter_blue_plus
```

The compiled extension assets are intentionally committed in the adapter package. Pub.dev consumers need an extension that exists, not a thrilling scavenger hunt through our CI artifacts.

## Roadmap

The core format is adapter-agnostic. `flutter_blue_plus` is the first supported adapter; `flutter_reactive_ble` and custom-plugin adapters are planned only when there is a real integration demand.

## Contributing

Issues and focused pull requests are welcome. Please include a scrubbed `.bletrace` whenever a timeline, decoding, or export bug is involved. “It broke” is not a trace format.

Released under the [MIT License](LICENSE).
