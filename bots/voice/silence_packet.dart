import 'dart:typed_data';

class SilencePacket {
  static const _silenceBytes = [0xF8, 0xFF, 0xFE];

  const SilencePacket();

  Uint8List get buffer => Uint8List.fromList(_silenceBytes);
}
