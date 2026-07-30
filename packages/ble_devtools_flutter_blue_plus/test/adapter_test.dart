import 'package:ble_devtools_core/ble_devtools_core.dart';
import 'package:ble_devtools_flutter_blue_plus/ble_devtools_flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('records an app-level reconnect attempt without a device dependency',
      () {
    final adapter =
        FlutterBluePlusBleDevTools(recorder: BleTraceRecorder(source: 'test'));
    adapter.recordOperation(
      kind: BleEventKind.reconnectAttempt,
      deviceId: 'AA:BB:CC:DD',
      metadata: {'attempt': 1, 'result': 'failed'},
    );

    expect(adapter.recorder.trace.events.single.kind,
        BleEventKind.reconnectAttempt);
  });
}
