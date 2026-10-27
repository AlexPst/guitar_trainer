import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/audio/click_sound.dart';

void main() {
  test('valid 16-bit mono WAV of the requested length', () {
    final wav = makeClickWav(frequency: 1000, durationMs: 35);
    final b = ByteData.sublistView(wav);
    String tag(int at) => String.fromCharCodes(wav.sublist(at, at + 4));

    expect(tag(0), 'RIFF');
    expect(tag(8), 'WAVE');
    expect(tag(12), 'fmt ');
    expect(tag(36), 'data');
    expect(b.getUint16(20, Endian.little), 1); // PCM
    expect(b.getUint16(22, Endian.little), 1); // mono
    expect(b.getUint32(24, Endian.little), 44100);
    expect(b.getUint16(34, Endian.little), 16);
    final samples = 44100 * 35 ~/ 1000;
    expect(b.getUint32(40, Endian.little), samples * 2);
    expect(wav.length, 44 + samples * 2);
    expect(b.getUint32(4, Endian.little), wav.length - 8);
  });

  test('starts silent, peaks early, decays to near silence', () {
    final wav = makeClickWav(frequency: 1000, amplitude: 0.8);
    final pcm = Int16List.sublistView(wav, 44);
    int peak(int from, int to) => pcm
        .sublist(from, to)
        .map((s) => s.abs())
        .reduce((a, b) => a > b ? a : b);

    expect(pcm.first, 0);
    expect(peak(0, 200), greaterThan(20000));
    expect(peak(pcm.length - 50, pcm.length), lessThan(100));
  });
}
