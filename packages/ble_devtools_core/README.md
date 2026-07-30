# ble_devtools_core

The transport-neutral trace contract behind [Flutter BLE DevTools](https://github.com/sonigeez/flutter-ble-devtools).

Use this package when you are building a BLE adapter, recording a custom BLE stack, or need a portable debugging artifact without depending on a particular plugin.

## Includes

- Immutable, ordered `BleEvent` records with wall-clock and monotonic timing.
- `BleTraceRecorder`, a bounded recorder that can expose the live trace to a DevTools extension.
- Byte renderers for hexadecimal, UTF-8, and signed/unsigned integers.
- Versioned `.bletrace` JSON export/import and a Markdown reproduction report.

```dart
final recorder = BleTraceRecorder(maxEvents: 5000);

recorder.record(
  kind: BleEventKind.connectionState,
  deviceId: 'device-42',
  metadata: {'state': 'connected'},
);

final trace = recorder.snapshot();
final bletrace = BleTraceExport.bletrace(trace);
final report = BleTraceExport.markdownReport(trace);
```

`BleTraceExport.bletrace(trace)` pseudonymizes device IDs and advertising names. It deliberately preserves payload bytes; they are often the only useful evidence. Treat exported traces as potentially sensitive.

For FlutterBluePlus instrumentation and the DevTools panel, use [`ble_devtools_flutter_blue_plus`](https://pub.dev/packages/ble_devtools_flutter_blue_plus).
