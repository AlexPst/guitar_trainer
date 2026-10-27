import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/engine/lesson_playback.dart';
import 'package:guitar_trainer/game/components.dart';
import 'package:guitar_trainer/game/layout.dart';
import 'package:guitar_trainer/game/lesson_game.dart';

import '../engine/fake_time.dart';

void main() {
  late FakeTime t;
  late RecordingSink sink;

  LessonGame create() {
    t = FakeTime();
    sink = RecordingSink(t);
    final game = LessonGame(
      lesson: testLesson(),
      metronome: sink,
      now: t.source,
    );
    for (final name in [Overlays.hud, Overlays.menu]) {
      game.overlays.addEntry(name, (_, _) => const SizedBox());
    }
    return game;
  }

  double noteX(NoteComponent n) => n.position.x;

  testWithGame<LessonGame>('notes are laid out from song time', create, (
    game,
  ) async {
    expect(game.notes, hasLength(3));
    expect(game.playback.phase, PlaybackPhase.ready);
    // Before start the song is at 0: first note sits on the hit line.
    expect(noteX(game.notes[0]), closeTo(SceneLayout.hitX, 1e-3));
    expect(
      noteX(game.notes[1]),
      closeTo(SceneLayout.hitX + SceneLayout.pixelsPerSecond, 1e-3),
    );
    expect(game.notes[0].position.y, closeTo(SceneLayout.stringY(6), 1e-3));
    expect(game.notes[1].position.y, closeTo(SceneLayout.stringY(5), 1e-3));

    game.start();
    game.update(0);
    // Count-in: song time -4 s, notes 4 s to the right.
    expect(
      noteX(game.notes[0]),
      closeTo(SceneLayout.hitX + 4 * SceneLayout.pixelsPerSecond, 1e-3),
    );

    t.advance(4.5);
    game.update(0.016);
    expect(
      noteX(game.notes[1]),
      closeTo(SceneLayout.hitX + 0.5 * SceneLayout.pixelsPerSecond, 1e-3),
    );
  });

  testWithGame<LessonGame>('highlights the nearest note', create, (game) async {
    game.start();
    t.advance(4 + 0.05); // just after the first note
    game.update(0);
    expect(game.notes.map((n) => n.state), [
      NoteState.current,
      NoteState.upcoming,
      NoteState.upcoming,
    ]);
    t.advance(0.5);
    game.update(0);
    expect(game.notes.map((n) => n.state), [
      NoteState.passed,
      NoteState.current,
      NoteState.upcoming,
    ]);
  });

  testWithGame<LessonGame>('count-in, metronome and finish', create, (
    game,
  ) async {
    expect(game.overlays.isActive(Overlays.menu), isFalse); // set by widget
    game.start();
    for (var i = 0; i < 60 * 10; i++) {
      t.advance(1 / 60);
      game.update(1 / 60);
      if (i == 30) {
        final countIn = game.world.children.query<CountInComponent>();
        expect(countIn.single.text, '1');
      }
    }
    expect(game.playback.phase, PlaybackPhase.finished);
    expect(game.playback.phase, PlaybackPhase.finished);
    // 4 count-in clicks + beats 0..4 (bar line after the 3 notes).
    expect(sink.played.map((p) => p.$1.index), [
      for (var i = -4; i <= 4; i++) i,
    ]);
    expect(game.progress.value, 1);
  });

  testWithGame<LessonGame>('pause stops motion and pending clicks', create, (
    game,
  ) async {
    game.start();
    t.advance(1);
    game.update(0);
    game.pause();
    expect(game.overlays.isActive(Overlays.menu), isTrue);
    final x = game.notes[0].position.x;
    t.advance(3);
    game.update(0);
    expect(game.notes[0].position.x, x);
    expect(sink.cancels, greaterThan(0));
    game.resume();
    expect(game.overlays.isActive(Overlays.menu), isFalse);
  });

  testWithGame<LessonGame>('slower speed changes tempo, not spacing', create, (
    game,
  ) async {
    game.setSpeed(0.5);
    game.start();
    t.advance(8); // count-in at half speed
    game.update(0);
    expect(game.playback.time, closeTo(0, 1e-9));
    expect(
      noteX(game.notes[1]) - noteX(game.notes[0]),
      closeTo(SceneLayout.pixelsPerSecond, 1e-3),
    );
  });

  testWithGame<LessonGame>(
    'left-handed layout mirrors positions',
    () {
      t = FakeTime();
      final game = LessonGame(
        lesson: testLesson(),
        now: t.source,
        leftHanded: true,
      );
      for (final name in [Overlays.hud, Overlays.menu]) {
        game.overlays.addEntry(name, (_, _) => const SizedBox());
      }
      return game;
    },
    (game) async {
      expect(game.hitX, SceneLayout.width - SceneLayout.hitX);
      // Song at 0: note 0 on the hit line, note 1 one second to the LEFT.
      expect(game.notes[0].position.x, closeTo(game.hitX, 1e-3));
      expect(
        game.notes[1].position.x,
        closeTo(game.hitX - SceneLayout.pixelsPerSecond, 1e-3),
      );
      expect(game.notes.every((n) => n.mirrored), isTrue);
    },
  );

  testWithGame<LessonGame>('notes off screen are not drawn', create, (
    game,
  ) async {
    game.start();
    game.update(0); // count-in: song at -4 s, notes 4+ s to the right
    expect(game.notes[0].isVisible, isTrue); // x = hitX + 1040 < 1280
    expect(game.notes[2].isVisible, isFalse); // 6 s ahead: past the edge
    t.advance(30);
    game.update(0);
    expect(game.notes.every((n) => !n.isVisible), isTrue); // all passed
  });
}
