import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

const bleTraceFormatVersion = 1;

enum BleEventKind {
  adapterState,
  permission,
  scanStarted,
  scanStopped,
  scanResult,
  connection,
  disconnection,
  reconnectAttempt,
  serviceDiscovery,
  characteristicRead,
  characteristicWrite,
  notification,
  descriptorRead,
  descriptorWrite,
  mtu,
  rssi,
  phy,
  bonding,
  error,
  note,
}

extension BleEventKindWireName on BleEventKind {
  String get wireName => switch (this) {
        BleEventKind.adapterState => 'adapter_state',
        BleEventKind.permission => 'permission',
        BleEventKind.scanStarted => 'scan_started',
        BleEventKind.scanStopped => 'scan_stopped',
        BleEventKind.scanResult => 'scan_result',
        BleEventKind.connection => 'connection',
        BleEventKind.disconnection => 'disconnection',
        BleEventKind.reconnectAttempt => 'reconnect_attempt',
        BleEventKind.serviceDiscovery => 'service_discovery',
        BleEventKind.characteristicRead => 'characteristic_read',
        BleEventKind.characteristicWrite => 'characteristic_write',
        BleEventKind.notification => 'notification',
        BleEventKind.descriptorRead => 'descriptor_read',
        BleEventKind.descriptorWrite => 'descriptor_write',
        BleEventKind.mtu => 'mtu',
        BleEventKind.rssi => 'rssi',
        BleEventKind.phy => 'phy',
        BleEventKind.bonding => 'bonding',
        BleEventKind.error => 'error',
        BleEventKind.note => 'note',
      };

  static BleEventKind parse(String value) => BleEventKind.values.firstWhere(
        (kind) => kind.wireName == value,
        orElse: () => throw FormatException('Unknown BLE event kind: $value'),
      );
}

@immutable
class BleEvent {
  const BleEvent({
    required this.sequence,
    required this.at,
    required this.kind,
    this.deviceId,
    this.serviceUuid,
    this.characteristicUuid,
    this.descriptorUuid,
    this.bytes,
    this.message,
    this.metadata = const {},
  });

  final int sequence;
  final DateTime at;
  final BleEventKind kind;
  final String? deviceId;
  final String? serviceUuid;
  final String? characteristicUuid;
  final String? descriptorUuid;
  final Uint8List? bytes;
  final String? message;
  final Map<String, Object?> metadata;

  BleEvent copyWith({
    int? sequence,
    DateTime? at,
    BleEventKind? kind,
    String? deviceId,
    String? serviceUuid,
    String? characteristicUuid,
    String? descriptorUuid,
    Uint8List? bytes,
    String? message,
    Map<String, Object?>? metadata,
  }) =>
      BleEvent(
        sequence: sequence ?? this.sequence,
        at: at ?? this.at,
        kind: kind ?? this.kind,
        deviceId: deviceId ?? this.deviceId,
        serviceUuid: serviceUuid ?? this.serviceUuid,
        characteristicUuid: characteristicUuid ?? this.characteristicUuid,
        descriptorUuid: descriptorUuid ?? this.descriptorUuid,
        bytes: bytes ?? this.bytes,
        message: message ?? this.message,
        metadata: metadata ?? this.metadata,
      );

  Map<String, Object?> toJson() => {
        'sequence': sequence,
        'at': at.toUtc().toIso8601String(),
        'kind': kind.wireName,
        if (deviceId != null) 'deviceId': deviceId,
        if (serviceUuid != null) 'serviceUuid': serviceUuid,
        if (characteristicUuid != null)
          'characteristicUuid': characteristicUuid,
        if (descriptorUuid != null) 'descriptorUuid': descriptorUuid,
        if (bytes != null) 'bytes': base64Encode(bytes!),
        if (message != null) 'message': message,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  factory BleEvent.fromJson(Map<String, Object?> json) {
    final rawBytes = json['bytes'];
    return BleEvent(
      sequence: json['sequence']! as int,
      at: DateTime.parse(json['at']! as String).toLocal(),
      kind: BleEventKindWireName.parse(json['kind']! as String),
      deviceId: json['deviceId'] as String?,
      serviceUuid: json['serviceUuid'] as String?,
      characteristicUuid: json['characteristicUuid'] as String?,
      descriptorUuid: json['descriptorUuid'] as String?,
      bytes: rawBytes is String
          ? Uint8List.fromList(base64Decode(rawBytes))
          : null,
      message: json['message'] as String?,
      metadata: Map<String, Object?>.from(json['metadata'] as Map? ?? const {}),
    );
  }
}

@immutable
class BleTrace {
  BleTrace({
    required List<BleEvent> events,
    required this.startedAt,
    this.id = 'live',
    this.source = 'unknown',
    this.platform,
    Map<String, Object?> metadata = const {},
  })  : events = List.unmodifiable(events),
        metadata = Map.unmodifiable(metadata);

  final String id;
  final String source;
  final String? platform;
  final DateTime startedAt;
  final List<BleEvent> events;
  final Map<String, Object?> metadata;

  Duration elapsedAt(BleEvent event) => event.at.difference(startedAt);

  Map<String, Object?> toJson() => {
        'formatVersion': bleTraceFormatVersion,
        'id': id,
        'source': source,
        if (platform != null) 'platform': platform,
        'startedAt': startedAt.toUtc().toIso8601String(),
        if (metadata.isNotEmpty) 'metadata': metadata,
        'events': events.map((event) => event.toJson()).toList(),
      };

  String toJsonString({bool pretty = false}) =>
      (pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder())
          .convert(toJson());

  factory BleTrace.fromJson(Map<String, Object?> json) {
    final version = json['formatVersion'];
    if (version != bleTraceFormatVersion) {
      throw FormatException('Unsupported .bletrace format: $version');
    }
    return BleTrace(
      id: json['id'] as String? ?? 'imported',
      source: json['source'] as String? ?? 'unknown',
      platform: json['platform'] as String?,
      startedAt: DateTime.parse(json['startedAt']! as String).toLocal(),
      metadata: Map<String, Object?>.from(json['metadata'] as Map? ?? const {}),
      events: (json['events']! as List<Object?>)
          .map((event) =>
              BleEvent.fromJson(Map<String, Object?>.from(event! as Map)))
          .toList(),
    );
  }

  factory BleTrace.fromJsonString(String source) =>
      BleTrace.fromJson(Map<String, Object?>.from(jsonDecode(source) as Map));
}
