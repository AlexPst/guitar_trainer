import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/engine/note_event.dart';
import 'package:guitar_trainer/engine/note_result.dart';
import 'package:guitar_trainer/engine/tempo_scorer.dart';
import 'package:guitar_trainer/music/lesson.dart';

import 'scoring_helpers.dart';

/// Plays [events] in time order with the clock advancing every 16 ms, then
/// runs the clock 2 s past the last note. Returns judgements by note index.
List<Judgement> play(
  TempoScorer s,
  List<NoteEvent> events, {
  double frame = 0.016,
}) {
  final sorted = [...events]..sort((a, b) => a.time.compareTo(b.time));
  final emitted = <NoteResult>[];
  final end = s.lesson.lengthInSeconds + 2;
  var i = 0;
  for (var t = -1.0; t < end; t += frame) {
    while (i < sorted.length && sorted[i].time <= t) {
      emitted.addAll(s.addEvent(sorted[i++]));
    }
    emitted.addAll(s.advance(t));
  }
  // Every note is reported exactly once.
  final indices = emitted.map((r) => r.noteIndex).toList()..sort();
  expect(indices, [for (var n = 0; n < s.lesson.notes.length; n++) n]);
  expect(s.isComplete, isTrue);
  return [for (final r in s.results) r!.judgement];
}

// Open E2 A2 D3 G3 (midi 40 45 50 55) on beats 0..3 = 0, 0.5, 1.0, 1.5 s.
final Lesson scale = lessonOf([(0, 6, 0), (1, 5, 0), (2, 4, 0), (3, 3, 0)]);
const midis = [40, 45, 50, 55];

void main() {
  test('played exactly: all hits', () {
    final s = TempoScorer(scale);
    final events = [for (var i = 0; i < 4; i++) ...pluck(i * 0.5, midis[i])];
    expect(play(s, events), List.filled(4, Judgement.hit));
    expect(s.extraNotes, 0);
    expect(s.results[1]!.timingError, closeTo(0, 1e-9));
  });

  test('early, late and inside the tight window', () {
    final s = TempoScorer(scale);
    final events = [
      ...pluck(0 - 0.08, 40),
      ...pluck(0.5 + 0.08, 45),
      ...pluck(1.0 + 0.03, 50),
      ...pluck(1.5 - 0.04, 55),
    ];
    expect(play(s, events), [
      Judgement.early,
      Judgement.late,
      Judgement.hit,
      Judgement.hit,
    ]);
    expect(s.results[0]!.timingError, closeTo(-0.08, 1e-9));
  });

  test('outside the ±120 ms window: miss plus an extra note', () {
    final s = TempoScorer(scale);
    final events = [
      ...pluck(0.2, 40), // 200 ms late, and 300 ms before the next note
      ...pluck(0.5, 45),
      ...pluck(1.0, 50),
      ...pluck(1.5, 55),
    ];
    expect(play(s, events).first, Judgement.miss);
    expect(s.extraNotes, 1);
  });

  test('silence: every note is a miss, reported once', () {
    final s = TempoScorer(scale);
    expect(play(s, const []), List.filled(4, Judgement.miss));
  });

  test('extra notes between targets do not change results', () {
    final s = TempoScorer(scale);
    final events = [
      for (var i = 0; i < 4; i++) ...pluck(i * 0.5, midis[i]),
      ...pluck(0.25, 60),
      ...pluck(0.75, 61),
      ...pluck(3.0, 40), // after the end
    ];
    expect(play(s, events), List.filled(4, Judgement.hit));
    expect(s.extraNotes, 3);
  });

  group('repeated notes', () {
    // A2 four times in a row.
    final repeats = lessonOf([(0, 5, 0), (1, 5, 0), (2, 5, 0), (3, 5, 0)]);

    test('each pluck counts', () {
      final s = TempoScorer(repeats);
      final events = [for (var i = 0; i < 4; i++) ...pluck(i * 0.5, 45)];
      expect(play(s, events), List.filled(4, Judgement.hit));
    });

    test('one pluck ringing on does not play the following notes', () {
      final s = TempoScorer(repeats);
      final events = [...pluck(0, 45), ...ring(0.2, 2.0, 45)];
      expect(play(s, events), [
        Judgement.hit,
        Judgement.miss,
        Judgement.miss,
        Judgement.miss,
      ]);
    });

    test(
      'fast repeats (16ths at 120 BPM, 125 ms apart) go to the right notes',
      () {
        final fast = lessonOf([for (var i = 0; i < 8; i++) (i * 0.25, 5, 0)]);
        final s = TempoScorer(fast);
        final events = [
          for (var i = 0; i < 8; i++)
            ...pluck(i * 0.125 + 0.02, 45, ringFrames: 1),
        ];
        expect(play(s, events), List.filled(8, Judgement.hit));
        expect(s.extraNotes, 0);
      },
    );
  });

  group('pitch', () {
    test('octave counts as almost', () {
      final s = TempoScorer(scale);
      final events = [
        ...pluck(0, 52), // E3 instead of E2
        ...pluck(0.5, 45),
        ...pluck(1.0, 38), // D2 instead of D3
        ...pluck(1.5, 55),
      ];
      expect(play(s, events), [
        Judgement.octave,
        Judgement.hit,
        Judgement.octave,
        Judgement.hit,
      ]);
    });

    test('wrong note', () {
      final s = TempoScorer(scale);
      final events = [
        ...pluck(0, 41),
        for (var i = 1; i < 4; i++) ...pluck(i * 0.5, midis[i]),
      ];
      expect(play(s, events).first, Judgement.wrongPitch);
      expect(s.results[0]!.cents, closeTo(100, 1e-6));
    });

    test('wrong then right inside the window is corrected', () {
      final s = TempoScorer(scale);
      final events = [
        ...pluck(-0.1, 41, ringFrames: 1),
        ...pluck(0.06, 40),
        for (var i = 1; i < 4; i++) ...pluck(i * 0.5, midis[i]),
      ];
      expect(play(s, events).first, Judgement.late);
    });

    test('octave candidate is not replaced by a wrong note', () {
      final s = TempoScorer(scale);
      final events = [
        ...pluck(-0.05, 52, ringFrames: 1),
        ...pluck(0.05, 43, ringFrames: 1),
        for (var i = 1; i < 4; i++) ...pluck(i * 0.5, midis[i]),
      ];
      expect(play(s, events).first, Judgement.octave);
    });

    test('pitch arriving 80 ms after the attack is credited to it', () {
      final s = TempoScorer(scale);
      final events = [
        for (var i = 0; i < 4; i++)
          ...pluck(i * 0.5, midis[i], pitchDelay: 0.08),
      ];
      expect(play(s, events), List.filled(4, Judgement.hit));
    });

    test('pitch too late after the attack is ignored', () {
      final s = TempoScorer(scale);
      final events = [
        NoteEvent(0, null, onset: true),
        NoteEvent(0.15, 82.41), // 150 ms > pitchSettle
        for (var i = 1; i < 4; i++) ...pluck(i * 0.5, midis[i]),
      ];
      expect(play(s, events).first, Judgement.miss);
    });

    test('unpitched attacks alone are misses', () {
      final s = TempoScorer(scale);
      final events = [
        for (var i = 0; i < 4; i++) NoteEvent(i * 0.5, null, onset: true),
      ];
      expect(play(s, events), List.filled(4, Judgement.miss));
    });
  });

  test('calibration offset compensates input latency', () {
    const latency = 0.1;
    final events = [
      for (var i = 0; i < 4; i++) ...pluck(i * 0.5 + latency, midis[i]),
    ];
    expect(play(TempoScorer(scale), events), List.filled(4, Judgement.late));
    expect(
      play(TempoScorer(scale, calibrationOffset: latency), events),
      List.filled(4, Judgement.hit),
    );
  });

  test('at 50% speed windows keep their real-time width', () {
    // 80 ms of song time = 160 ms real at half speed: outside the window.
    final s = TempoScorer(scale, speed: 0.5);
    final events = [
      ...pluck(0.08, 40),
      ...pluck(0.5 + 0.02, 45), // 40 ms real: hit
      ...pluck(1.0 - 0.04, 50), // 80 ms real: early
      ...pluck(1.5, 55),
    ];
    expect(play(s, events), [
      Judgement.miss,
      Judgement.hit,
      Judgement.early,
      Judgement.hit,
    ]);
  });

  test('random human timing within ±100 ms: everything played once', () {
    final rnd = math.Random(42);
    final long = lessonOf([
      for (var i = 0; i < 64; i++) (i.toDouble(), 6 - i % 6, i % 5),
    ]);
    final s = TempoScorer(long);
    final events = [
      for (var i = 0; i < 64; i++)
        ...pluck(
          long.noteTime(long.notes[i]) + (rnd.nextDouble() - 0.5) * 0.2,
          long.notes[i].midi(),
          pitchDelay: 0.02 + rnd.nextDouble() * 0.06,
        ),
    ];
    final judgements = play(s, events);
    expect(judgements.every((j) => j.isPlayed), isTrue);
    expect(s.extraNotes, 0);
  });
}
