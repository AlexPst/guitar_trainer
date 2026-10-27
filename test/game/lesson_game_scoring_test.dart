import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
    for (final name in [Overlays.hud, Overlays.menu, Overlays.finished]) {
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
    expect(game.overlays.isActive(Overlays.finished), isTrue);
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
    expect(game.overlays.isActive(Overlays.finished), isTrue);
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
}
