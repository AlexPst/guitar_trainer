import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/audio/note_event_source.dart';
import 'package:guitar_trainer/engine/lesson_playback.dart';
import 'package:guitar_trainer/engine/note_result.dart';
import 'package:guitar_trainer/engine/song_clock.dart';
import 'package:guitar_trainer/engine/tempo_scorer.dart';
import 'package:guitar_trainer/engine/wait_mode.dart';
import 'package:guitar_trainer/music/lesson.dart';
import 'package:guitar_trainer/music/lesson_parser.dart';

import '../audio/signals.dart';
import '../audio/synth.dart';
import 'fake_time.dart';

Lesson asset(String name) =>
    parseLessonJson(File('assets/lessons/$name').readAsStringSync());

/// Audio -> NoteEventSource -> TempoScorer, with the real metronome clicks
/// mixed in. [play] decides what the "player" does for note i: return the
/// pluck time offset from the note and the midi to play, or null to skip.
(List<Judgement>, int) tempoRun(
  Lesson lesson, {
  (double, num)? Function(int i, TabNote n)? play,
  bool clicks = true,
}) {
  final playback = LessonPlayback(lesson, clock: SongClock());
  final countIn = playback.countInSeconds;
  final synth = Synth();
  // Real time 0 = start of count-in, so song time = real - countIn.
  if (clicks) {
    for (var b = -playback.countInBeats; b <= playback.lastBeatIndex; b++) {
      synth.click(countIn + b * lesson.secondsPerBeat);
    }
  }
  for (var i = 0; i < lesson.notes.length; i++) {
    final n = lesson.notes[i];
    final p = play == null ? (0.0, n.midi()) : play(i, n);
    if (p == null) continue;
    // The pick lands 8 ms before the sound; aim the sound at the note.
    synth.pluck(
      countIn + lesson.noteTime(n) + p.$1 - 0.008,
      440 * math.pow(2, (p.$2 - 69) / 12).toDouble(),
    );
  }

  final source = NoteEventSource(sampleRate: sampleRate);
  final scorer = TempoScorer(
    lesson,
    inputLag: source.delay + 1024 / sampleRate,
  );
  final total = ((countIn + playback.endTime + 1) * sampleRate).round();
  while (synth.position < total) {
    final chunk = synth.render(1024);
    final songTime = synth.position / sampleRate - countIn;
    for (final e in source.add(chunk, songTime: songTime)) {
      scorer.addEvent(e);
    }
    scorer.advance(songTime);
  }
  scorer.advance(double.infinity);
  return ([for (final r in scorer.results) r!.judgement], scorer.extraNotes);
}

void main() {
  test('Ode to Joy played right, with repeated notes and clicks: all hit', () {
    final (judgements, extra) = tempoRun(asset('05_ode_to_joy.json'));
    expect(judgements, everyElement(Judgement.hit));
    expect(extra, 0);
  });

  test('every bundled lesson played right scores all notes', () {
    for (final f in Directory('assets/lessons').listSync().whereType<File>()) {
      final (judgements, extra) = tempoRun(asset(f.uri.pathSegments.last));
      expect(judgements.where((j) => !j.isPlayed), isEmpty, reason: f.path);
      expect(extra, 0, reason: f.path);
    }
  });

  test('metronome alone: every note missed, no extra notes', () {
    final (judgements, extra) = tempoRun(
      asset('05_ode_to_joy.json'),
      play: (_, _) => null,
    );
    expect(judgements, everyElement(Judgement.miss));
    expect(extra, 0);
  });

  test('mixed performance through real audio analysis', () {
    final lesson = asset('04_c_major_scale.json');
    final (j, _) = tempoRun(
      lesson,
      play: (i, n) => switch (i) {
        1 => (-0.09, n.midi()), // early
        2 => (0.09, n.midi()), // late
        3 => (0.0, n.midi() + 12), // octave
        4 => (0.0, n.midi() + 1), // wrong
        5 => null, // skipped
        _ => (0.0, n.midi()),
      },
    );
    expect(j.sublist(0, 7), [
      Judgement.hit,
      Judgement.early,
      Judgement.late,
      Judgement.octave,
      Judgement.wrongPitch,
      Judgement.miss,
      Judgement.hit,
    ]);
  });

  test('wait mode: player answers each stop, lesson completes', () {
    final lesson = asset('05_ode_to_joy.json');
    final t = FakeTime();
    final clock = SongClock(now: t.source)..start(-1);
    final session = WaitModeSession(lesson, clock);
    final source = NoteEventSource(sampleRate: sampleRate);
    final synth = Synth();

    // The player reacts 0.3 s after the song stops on a note.
    double? heldSince;
    var plucked = -1;
    final played = <int>[];
    for (var k = 0; k < 2000 && !session.isComplete; k++) {
      final chunk = synth.render(1024);
      t.advance(1024 / sampleRate);
      session.update();
      final real = synth.position / sampleRate;
      if (session.isHolding) {
        heldSince ??= real;
        if (real - heldSince > 0.3 && plucked < session.currentIndex) {
          plucked = session.currentIndex;
          synth.pluck(real, lesson.notes[plucked].frequency());
        }
      } else {
        heldSince = null;
      }
      for (final e in source.add(chunk, songTime: clock.time)) {
        final r = session.addEvent(e);
        if (r != null) played.add(r.noteIndex);
      }
    }
    expect(session.isComplete, isTrue);
    expect(played, [for (var i = 0; i < lesson.notes.length; i++) i]);
  });
}
