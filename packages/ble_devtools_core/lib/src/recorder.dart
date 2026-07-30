import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'model.dart';

class BleTraceRecorder {
  BleTraceRecorder({
    this.source = 'unknown',
    this.maxEvents = 5000,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String source;
  final int maxEvents;
  final DateTime Function() _clock;
  final _events = <BleEvent>[];
  final _changes = StreamController<BleEvent>.broadcast();
  late final DateTime _startedAt = _clock();
  var _sequence = 0;
  var _registered = false;

  Stream<BleEvent> get events => _changes.stream;
  BleTrace get trace => BleTrace(
        source: source,
        startedAt: _startedAt,
        events: _events,
      );

  BleEvent record({
    required BleEventKind kind,
    String? deviceId,
    String? serviceUuid,
    String? characteristicUuid,
    String? descriptorUuid,
    List<int>? bytes,
    String? message,
    Map<String, Object?> metadata = const {},
    DateTime? at,
  }) {
    final event = BleEvent(
      sequence: _sequence++,
      at: at ?? _clock(),
      kind: kind,
      deviceId: deviceId,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      descriptorUuid: descriptorUuid,
      bytes: bytes == null ? null : Uint8List.fromList(bytes),
      message: message,
      metadata: Map.unmodifiable(metadata),
    );
    _events.add(event);
    if (_events.length > maxEvents) _events.removeAt(0);
    _changes.add(event);
    return event;
  }

  void clear() {
    _events.clear();
    _sequence = 0;
  }

  /// Makes the current trace available to a connected DevTools extension.
  void registerDevToolsServiceExtensions() {
    if (_registered) return;
    _registered = true;
    developer.registerExtension('ext.ble_devtools.getTrace', (_, __) async {
      return developer.ServiceExtensionResponse.result(trace.toJsonString());
    });
    developer.registerExtension('ext.ble_devtools.clearTrace', (_, __) async {
      clear();
      return developer.ServiceExtensionResponse.result('{"cleared":true}');
    });
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}
