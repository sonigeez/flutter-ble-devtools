import 'dart:convert';
import 'dart:typed_data';

enum BleIntegerFormat {
  uint8,
  int8,
  uint16Le,
  uint16Be,
  int16Le,
  int16Be,
  uint32Le,
  uint32Be
}

class BleBytesView {
  const BleBytesView(this.bytes);

  final Uint8List bytes;

  String get hex => bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join(' ')
      .toUpperCase();

  String get utf8 => const Utf8Decoder(allowMalformed: true).convert(bytes);

  List<num> integers(BleIntegerFormat format) {
    final width = switch (format) {
      BleIntegerFormat.uint8 || BleIntegerFormat.int8 => 1,
      BleIntegerFormat.uint16Le ||
      BleIntegerFormat.uint16Be ||
      BleIntegerFormat.int16Le ||
      BleIntegerFormat.int16Be =>
        2,
      BleIntegerFormat.uint32Le || BleIntegerFormat.uint32Be => 4,
    };
    final data = ByteData.sublistView(bytes);
    final out = <num>[];
    for (var offset = 0; offset + width <= bytes.length; offset += width) {
      out.add(switch (format) {
        BleIntegerFormat.uint8 => data.getUint8(offset),
        BleIntegerFormat.int8 => data.getInt8(offset),
        BleIntegerFormat.uint16Le => data.getUint16(offset, Endian.little),
        BleIntegerFormat.uint16Be => data.getUint16(offset, Endian.big),
        BleIntegerFormat.int16Le => data.getInt16(offset, Endian.little),
        BleIntegerFormat.int16Be => data.getInt16(offset, Endian.big),
        BleIntegerFormat.uint32Le => data.getUint32(offset, Endian.little),
        BleIntegerFormat.uint32Be => data.getUint32(offset, Endian.big),
      });
    }
    return out;
  }
}
