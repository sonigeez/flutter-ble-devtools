import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ble_devtools_core/ble_devtools_core.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

class BleDevToolsScreen extends StatefulWidget {
  const BleDevToolsScreen({super.key});

  @override
  State<BleDevToolsScreen> createState() => _BleDevToolsScreenState();
}

class _BleDevToolsScreenState extends State<BleDevToolsScreen>
    with WidgetsBindingObserver {
  BleTrace? _trace;
  BleEvent? _selected;
  String _query = '';
  String? _error;
  bool _loading = false;
  bool _autoRefresh = true;
  bool _panelVisible = true;
  bool _refreshInFlight = false;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncAutoRefresh();
    unawaited(_refreshLive());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _panelVisible = state == AppLifecycleState.resumed;
    _syncAutoRefresh();
  }

  void _syncAutoRefresh() {
    _autoRefreshTimer?.cancel();
    if (!_autoRefresh || !_panelVisible) {
      return;
    }
    _autoRefreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      unawaited(_refreshLive(showLoading: false));
    });
  }

  void _toggleAutoRefresh() {
    setState(() => _autoRefresh = !_autoRefresh);
    _syncAutoRefresh();
    if (_autoRefresh) {
      unawaited(_refreshLive(showLoading: false));
    }
  }

  List<BleEvent> get _visibleEvents {
    final trace = _trace;
    if (trace == null || _query.isEmpty) return trace?.events ?? const [];
    final query = _query.toLowerCase();
    return trace.events.where((event) {
      return [
        event.kind.wireName,
        event.deviceId,
        event.serviceUuid,
        event.characteristicUuid,
        event.message,
        event.metadata.toString(),
        event.bytes == null ? null : BleBytesView(event.bytes!).hex,
      ].any((value) => value?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> _refreshLive({bool showLoading = true}) async {
    if (_refreshInFlight) {
      return;
    }
    _refreshInFlight = true;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await serviceManager
          .callServiceExtensionOnMainIsolate('ext.ble_devtools.getTrace');
      final json = response.json;
      if (json == null) {
        throw const FormatException('The app returned an empty BLE trace.');
      }
      final trace = BleTrace.fromJson(Map<String, Object?>.from(json));
      if (mounted) {
        setState(() {
          _trace = trace;
          _selected = _selected ?? trace.events.lastOrNull;
        });
      }
    } catch (error) {
      if (mounted && (showLoading || _trace == null)) {
        setState(() => _error = '$error');
      }
    } finally {
      _refreshInFlight = false;
      if (showLoading && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _clearLive() async {
    try {
      await serviceManager
          .callServiceExtensionOnMainIsolate('ext.ble_devtools.clearTrace');
      await _refreshLive();
    } catch (error) {
      setState(() => _error = '$error');
    }
  }

  Future<void> _importTrace() async {
    const traceType =
        XTypeGroup(label: 'BLE traces', extensions: ['bletrace', 'json']);
    final file = await openFile(acceptedTypeGroups: [traceType]);
    if (file == null) return;
    try {
      final trace = BleTrace.fromJsonString(await file.readAsString());
      setState(() {
        _trace = trace;
        _selected = trace.events.lastOrNull;
        _error = null;
      });
    } catch (error) {
      setState(() => _error = 'Could not import ${file.name}: $error');
    }
  }

  Future<void> _download(String name, String content, String mimeType) async {
    final location = await getSaveLocation(suggestedName: name);
    if (location == null) return;
    await XFile.fromData(Uint8List.fromList(utf8.encode(content)),
            mimeType: mimeType, name: name)
        .saveTo(location.path);
  }

  @override
  Widget build(BuildContext context) {
    final trace = _trace;
    final colorScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xff00a88f), brightness: Brightness.dark);
    return Theme(
      data: ThemeData(
          colorScheme: colorScheme,
          brightness: Brightness.dark,
          useMaterial3: true),
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.bluetooth_searching),
              SizedBox(width: 10),
              Text('BLE DevTools'),
            ],
          ),
          actions: [
            IconButton(
              tooltip:
                  _autoRefresh ? 'Pause live refresh' : 'Resume live refresh',
              onPressed: _toggleAutoRefresh,
              icon: Icon(_autoRefresh
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline),
            ),
            IconButton(
                tooltip: 'Refresh live trace',
                onPressed: _loading ? null : _refreshLive,
                icon: const Icon(Icons.refresh)),
            IconButton(
                tooltip: 'Clear live trace',
                onPressed: trace == null ? null : _clearLive,
                icon: const Icon(Icons.delete_outline)),
            IconButton(
                tooltip: 'Import .bletrace',
                onPressed: _importTrace,
                icon: const Icon(Icons.upload_file)),
            IconButton(
              tooltip: 'Export sanitized .bletrace',
              onPressed: trace == null
                  ? null
                  : () => _download('ble-session.bletrace',
                      BleTraceExport.bletrace(trace), 'application/json'),
              icon: const Icon(Icons.download),
            ),
            IconButton(
              tooltip: 'Export Markdown repro report',
              onPressed: trace == null
                  ? null
                  : () => _download('ble-repro.md',
                      BleTraceExport.markdownBugReport(trace), 'text/markdown'),
              icon: const Icon(Icons.bug_report_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            _SummaryBar(
              trace: trace,
              loading: _loading,
              autoRefresh: _autoRefresh && _panelVisible,
            ),
            if (_error != null)
              MaterialBanner(
                content: Text(_error!),
                leading: const Icon(Icons.info_outline),
                actions: [
                  TextButton(
                      onPressed: () => setState(() => _error = null),
                      child: const Text('Dismiss'))
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Filter device, event, UUID, payload, or error',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: trace == null
                  ? const _EmptyTrace()
                  : Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _Timeline(
                            trace: trace,
                            events: _visibleEvents,
                            selected: _selected,
                            onSelected: (event) =>
                                setState(() => _selected = event),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                            flex: 2, child: _ByteInspector(event: _selected)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.trace,
    required this.loading,
    required this.autoRefresh,
  });
  final BleTrace? trace;
  final bool loading;
  final bool autoRefresh;

  @override
  Widget build(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            Text(loading
                ? 'Loading trace…'
                : trace == null
                    ? 'No trace loaded'
                    : '${trace!.events.length} events'),
            const SizedBox(width: 20),
            if (trace != null) Text('Source: ${trace!.source}'),
            const SizedBox(width: 20),
            Text(autoRefresh ? 'Live · 500 ms' : 'Live refresh paused'),
            const Spacer(),
            const Text(
                'Exports pseudonymise device IDs and advertising names.'),
          ],
        ),
      );
}

class _EmptyTrace extends StatelessWidget {
  const _EmptyTrace();

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bluetooth_disabled, size: 56),
              SizedBox(height: 16),
              Text('No BLE trace yet',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text(
                'Start FlutterBluePlusBleDevTools in your app, attach DevTools, then refresh. Or import a .bletrace file.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _Timeline extends StatelessWidget {
  const _Timeline(
      {required this.trace,
      required this.events,
      required this.selected,
      required this.onSelected});
  final BleTrace trace;
  final List<BleEvent> events;
  final BleEvent? selected;
  final ValueChanged<BleEvent> onSelected;

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          final isSelected = event.sequence == selected?.sequence;
          return Card(
            color: isSelected
                ? Theme.of(context).colorScheme.secondaryContainer
                : null,
            child: ListTile(
              onTap: () => onSelected(event),
              leading: CircleAvatar(
                  backgroundColor: _eventColor(event.kind),
                  child: Text(event.sequence.toString(),
                      style: const TextStyle(fontSize: 11))),
              title: Text(event.kind.wireName.replaceAll('_', ' '),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_details(event)),
              trailing: Text(_elapsed(trace.elapsedAt(event)),
                  style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()])),
            ),
          );
        },
      );

  String _details(BleEvent event) => [
        event.deviceId,
        event.characteristicUuid,
        event.message,
        event.bytes == null ? null : BleBytesView(event.bytes!).hex
      ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');

  Color _eventColor(BleEventKind kind) => switch (kind) {
        BleEventKind.error || BleEventKind.disconnection => Colors.redAccent,
        BleEventKind.connection || BleEventKind.notification => Colors.teal,
        BleEventKind.characteristicWrite ||
        BleEventKind.characteristicRead =>
          Colors.deepPurple,
        _ => Colors.blueGrey,
      };

  String _elapsed(Duration duration) =>
      '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}.${(duration.inMilliseconds % 1000).toString().padLeft(3, '0')}';
}

class _ByteInspector extends StatelessWidget {
  const _ByteInspector({required this.event});
  final BleEvent? event;

  @override
  Widget build(BuildContext context) {
    if (event == null) {
      return const Center(child: Text('Select an event to inspect its bytes.'));
    }
    final bytes = event!.bytes;
    final view = bytes == null ? null : BleBytesView(bytes);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text('Event ${event!.sequence}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          _Field(label: 'Kind', value: event!.kind.wireName),
          _Field(label: 'Device', value: event!.deviceId ?? '—'),
          _Field(label: 'Service', value: event!.serviceUuid ?? '—'),
          _Field(
              label: 'Characteristic', value: event!.characteristicUuid ?? '—'),
          if (event!.message != null)
            _Field(label: 'Message', value: event!.message!),
          if (event!.metadata.isNotEmpty)
            _Field(
                label: 'Metadata',
                value: const JsonEncoder.withIndent('  ')
                    .convert(event!.metadata)),
          if (view != null) ...[
            const Divider(height: 32),
            Text('Byte inspector',
                style: Theme.of(context).textTheme.titleMedium),
            _Field(label: 'Hex', value: view.hex),
            _Field(label: 'UTF-8', value: view.utf8),
            _Field(
                label: 'uint8',
                value: view.integers(BleIntegerFormat.uint8).join(', ')),
            _Field(
                label: 'uint16 LE',
                value: view.integers(BleIntegerFormat.uint16Le).join(', ')),
            _Field(
                label: 'uint16 BE',
                value: view.integers(BleIntegerFormat.uint16Be).join(', ')),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 3),
            SelectableText(value,
                style: const TextStyle(fontFamily: 'monospace')),
          ],
        ),
      );
}
