import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/audio/level_meter.dart';

void main() {
  Float32List sine(double amplitude, {int n = 4410}) => Float32List.fromList([
    for (var i = 0; i < n; i++)
      amplitude * math.sin(2 * math.pi * 440 * i / 44100),
  ]);

  test('rms of silence and empty buffer is 0', () {
    expect(rms(Float32List(512)), 0);
    expect(rms(Float32List(0)), 0);
  });

  test('rms of full-scale sine is 1/sqrt(2)', () {
    expect(rms(sine(1)), closeTo(1 / math.sqrt2, 1e-3));
  });

  test('dbfs: full-scale square is 0 dB, half amplitude is about -6 dB', () {
    expect(rmsToDbfs(1), 0);
    expect(rmsToDbfs(0.5), closeTo(-6.02, 0.01));
  });

  test('dbfs is clamped to minDbfs for silence', () {
    expect(rmsToDbfs(0), minDbfs);
    expect(rmsToDbfs(1e-9), minDbfs);
  });

  test('dbfsToUnit maps range to 0..1', () {
    expect(dbfsToUnit(minDbfs), 0);
    expect(dbfsToUnit(0), 1);
    expect(dbfsToUnit(minDbfs / 2), closeTo(0.5, 1e-9));
  });

  test('bytesToFloat32 reads aligned and unaligned buffers', () {
    final src = Float32List.fromList([0.25, -0.5, 1]);
    final bytes = src.buffer.asUint8List();
    expect(bytesToFloat32(bytes), src);

    final shifted = Uint8List(bytes.length + 1)
      ..setRange(1, bytes.length + 1, bytes);
    final unaligned = Uint8List.sublistView(shifted, 1);
    expect(bytesToFloat32(unaligned), src);
  });
}
