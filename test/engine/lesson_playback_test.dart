import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/engine/lesson_playback.dart';
import 'package:guitar_trainer/engine/song_clock.dart';

import 'fake_time.dart';

void main() {
  late FakeTime t;
  late LessonPlayback p;

  setUp(() {
    t = FakeTime();
    // 60 BPM, 3 one-beat notes: 3 s of music, 4 s count-in, 1 s tail.
    p = LessonPlayback(testLesson(), clock: SongClock(now: t.source));
  });

  test('ready until started', () {
    expect(p.phase, PlaybackPhase.ready);
    expect(p.countInBeat, isNull);
    t.advance(3);
    expect(p.time, 0);
  });

  test('count-in beats 1..4 then playing', () {
    p.start();
    expect(p.time, -4);
    expect(p.phase, PlaybackPhase.countIn);
    final seen = <int?>[];
    for (var i = 0; i < 4; i++) {
      seen.add(p.countInBeat);
      t.advance(1);
    }
    expect(seen, [1, 2, 3, 4]);
    expect(p.phase, PlaybackPhase.playing);
    expect(p.countInBeat, isNull);
  });

  test('pause / resume', () {
    p.start();
    t.advance(5);
    p.pause();
    expect(p.phase, PlaybackPhase.paused);
    t.advance(10);
    expect(p.time, closeTo(1, 1e-9));
    p.resume();
    expect(p.phase, PlaybackPhase.playing);
  });

  test('finishes after last note plus tail, once', () {
    p.start();
    t.advance(4 + 3 + 0.9);
    expect(p.checkFinished(), isFalse);
    t.advance(0.2);
    expect(p.checkFinished(), isTrue);
    expect(p.checkFinished(), isFalse);
    expect(p.phase, PlaybackPhase.finished);
    expect(p.progress, 1);
    p.pause(); // no effect when finished
    expect(p.phase, PlaybackPhase.finished);
  });

  test('restart from finished', () {
    p.start();
    t.advance(20);
    p.checkFinished();
    p.start();
    expect(p.phase, PlaybackPhase.countIn);
    expect(p.time, -4);
  });

  test('progress and slower speed', () {
    p
      ..start()
      ..speed = 0.5;
    t.advance(8); // count-in takes twice as long
    expect(p.time, closeTo(0, 1e-9));
    t.advance(3);
    expect(p.progress, closeTo(0.5, 1e-9));
  });

  test('metronome runs to the bar line after the last note', () {
    expect(p.lastBeatIndex, 4);
    expect(
      LessonPlayback(testLesson(beats: 5), clock: SongClock()).lastBeatIndex,
      8,
    );
  });
}
