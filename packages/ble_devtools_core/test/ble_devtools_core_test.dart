import 'dart:typed_data';

import 'package:ble_devtools_core/ble_devtools_core.dart';
import 'package:test/test.dart';

void main() {
  test('trace round trips without losing raw bytes', () {
    final trace = BleTrace(
      source: 'test',
      startedAt: DateTime.utc(2026, 7, 30, 14),
      events: [
        BleEvent(
          sequence: 0,
          at: DateTime.utc(2026, 7, 30, 14, 0, 1),
          kind: BleEventKind.characteristicWrite,
          deviceId: 'AA:BB:CC:DD',
          bytes: Uint8List.fromList([8, 255]),
        ),
      ],
    );

    final restored = BleTrace.fromJsonString(trace.toJsonString());
    expect(restored.events.single.bytes, [8, 255]);
    expect(restored.events.single.kind, BleEventKind.characteristicWrite);
  });

  test('sanitizer preserves consistent aliases and raw command bytes', () {
    final trace = BleTrace(
      source: 'test',
      startedAt: DateTime.utc(2026, 7, 30),
      events: [
        BleEvent(
            sequence: 0,
            at: DateTime.utc(2026, 7, 30),
            kind: BleEventKind.scanResult,
            deviceId: 'AA:BB',
            metadata: {'name': 'Pocket'}),
        BleEvent(
            sequence: 1,
            at: DateTime.utc(2026, 7, 30, 0, 0, 1),
            kind: BleEventKind.characteristicWrite,
            deviceId: 'AA:BB',
            bytes: Uint8List.fromList([8])),
        BleEvent(
            sequence: 2,
            at: DateTime.utc(2026, 7, 30, 0, 0, 2),
            kind: BleEventKind.error,
            message: 'GATT 133 for AA:BB (Pocket)',
            metadata: {'sessionToken': 'nope'}),
      ],
    );

    final output = BleTraceExport.bletrace(trace);
    expect(output, isNot(contains('AA:BB')));
    expect(output, isNot(contains('Pocket')));
    expect(output, isNot(contains('nope')));
    expect(output, contains('device-1'));
    expect(BleTrace.fromJsonString(output).events[1].bytes, [8]);
  });

  test('byte inspector decodes hex, utf8 and little endian integers', () {
    final view = BleBytesView(Uint8List.fromList([0x41, 0x02, 0x01]));
    expect(view.hex, '41 02 01');
    expect(view.utf8, 'A\u0002\u0001');
    expect(view.integers(BleIntegerFormat.uint16Le), [577]);
  });
}
