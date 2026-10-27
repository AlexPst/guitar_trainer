import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/engine/lesson_playback.dart';
import 'package:guitar_trainer/engine/note_event.dart';
import 'package:guitar_trainer/engine/note_result.dart';
import 'package:guitar_trainer/game/feedback.dart';
import 'package:guitar_trainer/game/lesson_game.dart';
import 'package:guitar_trainer/music/pitch.dart';

import '../engine/fake_time.dart';

void main() {
  late FakeTime t;

  // 60 BPM: notes at 0, 1, 2 s; string 6 fret 0 (E2), string 5 fret 1 (A#2),
  // string 4 fret 2 (E3). Count-in 4 s.
  LessonGame create() {
    t = FakeTime();
    final game = LessonGame(lesson: testLesson(), now: t.source);
    for (final name in [Overlays.hud, Overlays.menu]) {
      game.overlays.addEntry(name, (_, _) => const SizedBox());
    }
    return game;
  }

  List<NoteEvent> pluck(double songTime, int midi) => [
    NoteEvent(songTime, null, onset: true),
    NoteEvent(songTime + 0.04, midiToFrequency(midi)),
  ];

  void runTo(LessonGame game, double realSeconds) {
    final end = t.seconds + realSeconds;
    while (t.seconds < end) {
      t.advance(1 / 60);
      game.update(1 / 60);
    }
  }

  testWithGame<LessonGame>('tempo mode: judgements, score, combo', create, (
    game,
  ) async {
    game.start();
    runTo(game, 4); // count-in
    game.addNoteEvents(pluck(0.0, 40)); // hit
    runTo(game, 1.08);
    game.addNoteEvents(pluck(1.08, 46)); // late, right pitch
    runTo(game, 1);
    game.addNoteEvents(pluck(2.0, 53)); // wrong note
    runTo(game, 3);

    expect(game.notes.map((n) => n.judgement), [
      Judgement.hit,
      Judgement.late,
      Judgement.wrongPitch,
    ]);
    expect(game.score.value, 170);
    expect(game.combo.value, 0);
    expect(game.scoreKeeper.maxCombo, 2);
    // Feedback label for the late note was shown.
    expect(game.playback.phase, PlaybackPhase.finished);
  });

  testWithGame<LessonGame>('feedback components appear', create, (game) async {
    game.start();
    runTo(game, 4.05);
    game.addNoteEvents(pluck(-0.08, 40)); // early
    await game.ready();
    expect(game.world.children.query<FeedbackText>(), hasLength(1));
    expect(game.world.children.query<FeedbackText>().single.text, 'Рано');
  });

  testWithGame<LessonGame>('silence: all missed', create, (game) async {
    game.start();
    runTo(game, 10);
    expect(game.notes.map((n) => n.judgement), everyElement(Judgement.miss));
  });

  testWithGame<LessonGame>('heard note shows and fades', create, (game) async {
    game.addNoteEvents([NoteEvent(0, midiToFrequency(45))]);
    expect(game.heard.value, 'A2');
    runTo(game, 0.5);
    expect(game.heard.value, isNull);
  });

  testWithGame<LessonGame>(
    'events before start or in pause are ignored',
    create,
    (game) async {
      game.addNoteEvents(pluck(0, 40));
      game.start();
      runTo(game, 4);
      game.pause();
      game.addNoteEvents(pluck(0, 40));
      expect(game.notes.first.judgement, isNull);
    },
  );

  testWithGame<LessonGame>('wait mode holds and releases', create, (
    game,
  ) async {
    game.setMode(LessonMode.wait);
    game.start();
    runTo(game, 6);
    expect(game.playback.time, closeTo(0, 1e-9)); // held on note 0
    game.addNoteEvents(pluck(0, 52)); // octave: not accepted
    runTo(game, 0.5);
    expect(game.playback.time, closeTo(0, 1e-9));
    game.addNoteEvents(pluck(0, 40));
    runTo(game, 2);
    expect(game.playback.time, closeTo(1, 1e-9)); // held on note 1
    expect(game.notes.first.judgement, Judgement.hit);
    game.addNoteEvents(pluck(1, 46));
    runTo(game, 2);
    game.addNoteEvents(pluck(2, 52));
    runTo(game, 3);
    expect(game.playback.phase, PlaybackPhase.finished);
    expect(game.notes.map((n) => n.judgement), everyElement(Judgement.hit));
  });

  testWithGame<LessonGame>('mode can only change before start', create, (
    game,
  ) async {
    game.setMode(LessonMode.wait);
    game.start();
    game.setMode(LessonMode.tempo);
    expect(game.mode, LessonMode.wait);
  });

  testWithGame<LessonGame>(
    'hit window from settings',
    () {
      t = FakeTime();
      final game = LessonGame(
        lesson: testLesson(),
        now: t.source,
        hitWindow: 0.2,
      );
      for (final name in [Overlays.hud, Overlays.menu]) {
        game.overlays.addEntry(name, (_, _) => const SizedBox());
      }
      return game;
    },
    (game) async {
      game.start();
      runTo(game, 4.2);
      game.addNoteEvents(pluck(0.17, 40)); // outside 120 ms, inside 200 ms
      expect(game.notes.first.judgement, Judgement.late);
    },
  );

  testWithGame<LessonGame>(
    'loop: passes repeat, tempo adapts, never finishes',
    () {
      t = FakeTime();
      // 3 one-beat notes at 60 BPM -> one 4-beat bar per pass.
      final game = LessonGame(lesson: testLesson(), now: t.source, loop: true);
      for (final name in [Overlays.hud, Overlays.menu]) {
        game.overlays.addEntry(name, (_, _) => const SizedBox());
      }
      return game;
    },
    (game) async {
      final phases = <PlaybackPhase>[];
      game.phase.addListener(() => phases.add(game.phase.value));
      game.setSpeed(0.7);
      game.start();
      expect(game.pass.value, 1);

      // Pass 1: play everything right -> tempo goes up.
      runTo(game, 4 / 0.7); // count-in
      for (final (i, midi) in [(0, 40), (1, 46), (2, 52)]) {
        game.addNoteEvents(pluck(game.playback.time, midi));
        runTo(game, (i == 2 ? 2.2 : 1) / 0.7); // pass ends on the bar line
      }
      expect(game.pass.value, 2);
      expect(game.lastPassAccuracy.value, 1.0);
      expect(game.playback.speed, closeTo(0.8, 1e-9));
      expect(game.playback.phase, PlaybackPhase.countIn);
      expect(game.notes.every((n) => n.judgement == null), isTrue);

      // Pass 2: silence -> tempo goes down.
      runTo(game, 9 / 0.8);
      expect(game.pass.value, 3);
      expect(game.lastPassAccuracy.value, 0);
      expect(game.playback.speed, closeTo(0.7, 1e-9));

      expect(phases, isNot(contains(PlaybackPhase.finished)));
      expect(game.result().scored, isFalse);

      // Manual restart resets the pass counter.
      game.start();
      expect(game.pass.value, 1);
    },
  );
}
