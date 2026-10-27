import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/audio/note_event_source.dart';
import 'package:guitar_trainer/engine/calibration.dart';

import '../audio/signals.dart';
import '../audio/synth.dart';

final clicks = [for (var i = 0; i < 12; i++) i * 2 / 3];

void main() {
  test('constant latency is found exactly', () {
    final r = estimateLatency(clicks, [for (final c in clicks) c + 0.085])!;
    expect(r.offset, closeTo(0.085, 1e-9));
    expect(r.spread, closeTo(0, 1e-9));
    expect(r.matched, 12);
  });

  test('human jitter: median close to the true latency', () {
    final rnd = math.Random(5);
    final onsets = [
      for (final c in clicks) c + 0.1 + (rnd.nextDouble() - 0.5) * 0.04,
    ];
    final r = estimateLatency(clicks, onsets)!;
    expect(r.offset, closeTo(0.1, 0.01));
    expect(r.spread, lessThan(0.02));
  });

  test('missed beats, double plucks and stray noise are ignored', () {
    final onsets = <double>[];
    for (var i = 0; i < clicks.length; i++) {
      if (i == 3 || i == 7) continue; // missed
      onsets.add(clicks[i] + 0.06);
      if (i == 5) onsets.add(clicks[i] + 0.18); // double pluck
    }
    onsets.add(clicks[9] + 0.33); // stray noise, far off
    final r = estimateLatency(clicks, [...onsets]..sort())!;
    expect(r.offset, closeTo(0.06, 1e-9));
    expect(r.matched, 10);
  });

  test('negative offset (playing ahead of the click) is allowed', () {
    final r = estimateLatency(clicks, [for (final c in clicks) c - 0.05])!;
    expect(r.offset, closeTo(-0.05, 1e-9));
  });

  test('too few attacks: no result', () {
    expect(
      estimateLatency(clicks, [for (final c in clicks.take(5)) c]),
      isNull,
    );
    expect(estimateLatency(clicks, const []), isNull);
  });

  test('through real audio analysis with clicks in the mic', () {
    // Player's plucks sound 80 ms after each click (e.g. output + reaction
    // offset); the mic also hears the clicks themselves.
    const latency = 0.08;
    final synth = Synth();
    const lead = 1.0; // real seconds before song time 0
    for (var b = -4; b < 12; b++) {
      synth.click(lead + b * 2 / 3);
    }
    for (final c in clicks) {
      synth.pluck(lead + c + latency - 0.008, 110);
    }
    final source = NoteEventSource(sampleRate: sampleRate);
    final onsets = <double>[];
    while (synth.position < (lead + 9) * sampleRate) {
      final chunk = synth.render(1024);
      final songTime = synth.position / sampleRate - lead;
      for (final e in source.add(chunk, songTime: songTime)) {
        if (e.onset) onsets.add(e.time);
      }
    }
    final r = estimateLatency(clicks, onsets)!;
    expect(r.matched, 12);
    expect(r.offset, closeTo(latency, 0.012));
  });
}
