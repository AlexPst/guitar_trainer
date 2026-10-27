import 'dart:math' as math;
import 'dart:typed_data';

/// Short decaying sine burst as a 16-bit mono WAV file.
Uint8List makeClickWav({
  required double frequency,
  int durationMs = 35,
  int sampleRate = 44100,
  double amplitude = 0.8,
}) {
  final n = sampleRate * durationMs ~/ 1000;
  const headerSize = 44;
  final bytes = ByteData(headerSize + n * 2);

  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, headerSize - 8 + n * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes
    ..setUint32(16, 16, Endian.little) // fmt chunk size
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little) // byte rate
    ..setUint16(32, 2, Endian.little) // block align
    ..setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  bytes.setUint32(40, n * 2, Endian.little);

  // Exponential decay to about -60 dB at the end; short attack avoids a pop.
  final decay = math.log(1000) / n;
  final attack = sampleRate ~/ 2000;
  for (var i = 0; i < n; i++) {
    final env = math.exp(-decay * i) * (i < attack ? i / attack : 1);
    final s =
        amplitude * env * math.sin(2 * math.pi * frequency * i / sampleRate);
    bytes.setInt16(headerSize + i * 2, (s * 32767).round(), Endian.little);
  }
  return bytes.buffer.asUint8List();
}
