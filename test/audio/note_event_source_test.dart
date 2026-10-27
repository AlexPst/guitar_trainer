import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/audio/note_event_source.dart';
import 'package:guitar_trainer/engine/note_event.dart';
import 'package:guitar_trainer/music/pitch.dart';

import 'signals.dart';
import 'synth.dart';

/// Renders [seconds] of [synth] in 1024-sample chunks. The song clock starts
/// at [songStart] with the first sample and runs at [speed].
List<NoteEvent> run(
  Synth synth,
  double seconds, {
  double songStart = 0,
  double speed = 1,
}) {
  final source = NoteEventSource(sampleRate: sampleRate);
  final out = <NoteEvent>[];
  final total = (seconds * sampleRate).round();
  while (synth.position < total) {
    final chunk = synth.render(1024);
    final songTime = songStart + synth.position / sampleRate * speed;
    out.addAll(source.add(chunk, songTime: songTime, speed: speed));
  }
  return out;
}

void main() {
  test('plucks give onsets at the right song time, then their pitch', () {
    final synth = Synth()
      ..pluck(0.5, midiToFrequency(45))
      ..pluck(1.2, midiToFrequency(52));
    final events = run(synth, 2, songStart: -1);

    final onsets = events.where((e) => e.onset).toList();
    expect(onsets, hasLength(2));
    // Sound starts 8 ms after the pick; song time = real time - 1 s.
    expect(onsets[0].time, closeTo(-0.5 + 0.008, 0.012));
    expect(onsets[1].time, closeTo(0.2 + 0.008, 0.012));

    // First pitched frame fully after each attack has the new note.
    for (final (onset, midi) in [(onsets[0], 45), (onsets[1], 52)]) {
      final pitched = events.where(
        (e) =>
            !e.onset && e.time > onset.time + 0.05 && e.time < onset.time + 0.1,
      );
      expect(pitched, isNotEmpty);
      expect(NoteReading.fromFrequency(pitched.first.frequency!).midi, midi);
    }
  });

  test('events come out in time order', () {
    final synth = Synth();
    for (var i = 0; i < 8; i++) {
      synth.pluck(0.2 + i * 0.25, midiToFrequency(40 + i));
    }
    final times = run(synth, 2.5).map((e) => e.time).toList();
    expect(times, [...times]..sort());
  });

  test('metronome clicks alone are not attacks', () {
    final synth = Synth(clickAmp: 0.6);
    for (var i = 0; i < 8; i++) {
      synth.click(0.2 + i * 0.5);
    }
    final events = run(synth, 4.5);
    expect(events.where((e) => e.onset), isEmpty);
  });

  test('clicks on top of a ringing note are not attacks', () {
    final synth = Synth(decay: 2)..pluck(0.1, midiToFrequency(45));
    for (var i = 0; i < 6; i++) {
      synth.click(0.5 + i * 0.4);
    }
    final onsets = run(synth, 3).where((e) => e.onset).toList();
    expect(onsets, hasLength(1));
  });

  test('half speed maps real time to half as much song time', () {
    final synth = Synth()..pluck(1.0, midiToFrequency(45));
    final onset = run(synth, 2, speed: 0.5).firstWhere((e) => e.onset);
    expect(onset.time, closeTo(0.5 + 0.004, 0.008));
  });
}
