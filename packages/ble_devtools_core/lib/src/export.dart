import 'dart:convert';

import 'model.dart';

class BleTraceSanitizer {
  BleTraceSanitizer();

  final _deviceAliases = <String, String>{};
  final _nameAliases = <String, String>{};

  BleTrace sanitize(BleTrace trace) {
    // Allocate aliases before rewriting messages so a platform exception that
    // repeats an address cannot smuggle it into the exported report.
    for (final event in trace.events) {
      if (event.deviceId != null) {
        _alias(event.deviceId!, _deviceAliases, 'device');
      }
      _primeMetadata(event.metadata);
    }
    _primeMetadata(trace.metadata);
    return BleTrace(
      id: trace.id,
      source: trace.source,
      platform: trace.platform,
      startedAt: trace.startedAt,
      metadata: _metadata(trace.metadata),
      events: trace.events.map(_event).toList(),
    );
  }

  BleEvent _event(BleEvent event) => BleEvent(
        sequence: event.sequence,
        at: event.at,
        kind: event.kind,
        deviceId: event.deviceId == null
            ? null
            : _alias(event.deviceId!, _deviceAliases, 'device'),
        serviceUuid: event.serviceUuid,
        characteristicUuid: event.characteristicUuid,
        descriptorUuid: event.descriptorUuid,
        bytes: event.bytes,
        message: _message(event.message),
        metadata: _metadata(event.metadata),
      );

  Map<String, Object?> _metadata(Map<String, Object?> input) {
    final output = <String, Object?>{};
    for (final entry in input.entries) {
      final key = entry.key;
      final normalized = key.toLowerCase();
      if (normalized.contains('address') ||
          normalized.contains('remoteid') ||
          normalized == 'deviceid') {
        if (entry.value != null) {
          output[key] = _alias('${entry.value}', _deviceAliases, 'device');
        }
      } else if (normalized == 'name' || normalized.contains('advname')) {
        if (entry.value != null) {
          output[key] = _alias('${entry.value}', _nameAliases, 'peripheral');
        }
      } else if (normalized.contains('manufacturer') ||
          normalized.contains('servicedata')) {
        output[key] = '[redacted]';
      } else if (normalized.contains('email') ||
          normalized.contains('token') ||
          normalized.contains('secret')) {
        output[key] = '[redacted]';
      } else {
        output[key] = entry.value;
      }
    }
    return output;
  }

  void _primeMetadata(Map<String, Object?> input) {
    for (final entry in input.entries) {
      final normalized = entry.key.toLowerCase();
      if (entry.value == null) {
        continue;
      }
      if (normalized.contains('address') ||
          normalized.contains('remoteid') ||
          normalized == 'deviceid') {
        _alias('${entry.value}', _deviceAliases, 'device');
      } else if (normalized == 'name' || normalized.contains('advname')) {
        _alias('${entry.value}', _nameAliases, 'peripheral');
      }
    }
  }

  String? _message(String? value) {
    if (value == null) return null;
    var sanitized = value;
    for (final entry in _deviceAliases.entries) {
      sanitized = sanitized.replaceAll(entry.key, entry.value);
    }
    for (final entry in _nameAliases.entries) {
      sanitized = sanitized.replaceAll(entry.key, entry.value);
    }
    return sanitized.replaceAll(
        RegExp(r'\b(?:[A-Fa-f0-9]{2}:){5}[A-Fa-f0-9]{2}\b'),
        '[device-address]');
  }

  String _alias(String value, Map<String, String> aliases, String prefix) =>
      aliases.putIfAbsent(value, () => '$prefix-${aliases.length + 1}');
}

class BleTraceExport {
  static String bletrace(BleTrace trace, {bool sanitize = true}) {
    final export = sanitize ? BleTraceSanitizer().sanitize(trace) : trace;
    return const JsonEncoder.withIndent('  ').convert(export.toJson());
  }

  static String markdownBugReport(BleTrace trace, {bool sanitize = true}) {
    final report = sanitize ? BleTraceSanitizer().sanitize(trace) : trace;
    final buffer = StringBuffer()
      ..writeln('# BLE failure report')
      ..writeln()
      ..writeln('- Source: `${report.source}`')
      ..writeln('- Platform: `${report.platform ?? 'unknown'}`')
      ..writeln('- Events: ${report.events.length}')
      ..writeln()
      ..writeln('## Timeline')
      ..writeln()
      ..writeln('| Elapsed | Event | Device | Details |')
      ..writeln('| --- | --- | --- | --- |');
    for (final event in report.events) {
      final elapsed = event.at.difference(report.startedAt);
      final details = event.message ??
          event.metadata.entries.map((e) => '${e.key}=${e.value}').join(', ');
      buffer.writeln(
          '| ${_elapsed(elapsed)} | ${event.kind.wireName} | ${event.deviceId ?? '-'} | ${_escape(details)} |');
    }
    buffer
      ..writeln()
      ..writeln(
          'Attach the matching sanitized `.bletrace` file for raw payload inspection.');
    return buffer.toString();
  }

  static String _elapsed(Duration duration) =>
      '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}.${(duration.inMilliseconds % 1000).toString().padLeft(3, '0')}';

  static String _escape(String value) =>
      value.replaceAll('|', '\\|').replaceAll('\n', '<br>');
}
