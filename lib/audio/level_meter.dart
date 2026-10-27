import 'dart:math' as math;
import 'dart:typed_data';

/// Lowest level we report, so silence maps to a finite value.
const double minDbfs = -90;

/// Root mean square of float samples in range [-1, 1].
double rms(Float32List samples) {
  if (samples.isEmpty) return 0;
  var sum = 0.0;
  for (final s in samples) {
    sum += s * s;
  }
  return math.sqrt(sum / samples.length);
}

/// Converts an RMS amplitude to dBFS, clamped to [minDbfs, 0].
double rmsToDbfs(double rmsValue) {
  if (rmsValue <= 0) return minDbfs;
  final db = 20 * math.log(rmsValue) / math.ln10;
  return db.clamp(minDbfs, 0.0);
}

/// Maps dBFS to 0..1 for a level bar (linear in dB).
double dbfsToUnit(double dbfs) => ((dbfs - minDbfs) / -minDbfs).clamp(0.0, 1.0);

/// Reinterprets raw little-endian float32 bytes as samples.
/// Copies only when the buffer is not 4-byte aligned.
Float32List bytesToFloat32(Uint8List bytes) {
  final usable = bytes.lengthInBytes - bytes.lengthInBytes % 4;
  if (bytes.offsetInBytes % 4 == 0) {
    return Float32List.sublistView(bytes, 0, usable);
  }
  return Float32List.sublistView(Uint8List.fromList(bytes.sublist(0, usable)));
}
