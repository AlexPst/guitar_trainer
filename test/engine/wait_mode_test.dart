import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/engine/note_event.dart';
import 'package:guitar_trainer/engine/note_result.dart';
import 'package:guitar_trainer/engine/song_clock.dart';
import 'package:guitar_trainer/engine/wait_mode.dart';

import 'fake_time.dart';
import 'scoring_helpers.dart';

void main() {
  late FakeTime t;
  late SongClock clock;

  // E2 then A2 twice, beats 0,1,2 at 120 BPM: 0, 0.5, 1.0 s.
  final lesson = lessonOf([(0, 6, 0), (1, 5, 0), (2, 5, 0)]);

  WaitModeSession start() {
    t = FakeTime();
    clock = SongClock(now: t.source)..start(-1);
    return WaitModeSession(lesson, clock);
  }

  /// Advances real time in 16 ms frames, calling update like the game does.
  void run(WaitModeSession s, double seconds) {
    for (var x = 0.0; x < seconds; x += 0.016) {
      t.advance(0.016);
      s.update();
    }
  }

  List<NoteResult> feed(WaitModeSession s, List<NoteEvent> events) => [
    for (final e in events) ?s.addEvent(e),
  ];

  test('clock stops on the first note and waits', () {
    final s = start();
    run(s, 3);
    expect(s.isHolding, isTrue);
    expect(clock.isRunning, isFalse);
    expect(clock.time, 0);
    expect(s.currentIndex, 0);
  });

  test('wrong pitch and octave do not release the clock', () {
    final s = start();
    run(s, 2);
    expect(feed(s, pluck(clock.time, 41)), isEmpty);
    expect(feed(s, pluck(clock.time, 52)), isEmpty);
    run(s, 1);
    expect(clock.time, 0);
    expect(s.isHolding, isTrue);
  });

  test('right note releases, clock continues to the next note', () {
    final s = start();
    run(s, 2);
    final results = feed(s, pluck(clock.time, 40));
    expect(results.single.judgement, Judgement.hit);
    expect(results.single.noteIndex, 0);
    expect(clock.isRunning, isTrue);
    run(s, 0.3);
    expect(clock.time, closeTo(0.3, 0.02));
    run(s, 1);
    expect(clock.time, 0.5); // held at the second note
    expect(s.currentIndex, 1);
  });

  test('repeated note needs a new pluck', () {
    final s = start();
    run(s, 2);
    feed(s, pluck(clock.time, 40));
    run(s, 1);
    expect(feed(s, pluck(clock.time, 45)).single.noteIndex, 1);
    run(s, 1);
    expect(clock.time, 1.0);
    // The A2 still ringing does not play note 2...
    expect(feed(s, ring(clock.time, clock.time + 0.5, 45)), isEmpty);
    expect(s.currentIndex, 2);
    // ...a fresh pluck does.
    expect(feed(s, pluck(clock.time + 0.6, 45)).single.noteIndex, 2);
    expect(s.isComplete, isTrue);
    expect(s.holdTime, isNull);
  });

  test('note played slightly before it arrives is accepted', () {
    final s = start();
    run(s, 0.85); // song time about -0.15
    expect(clock.isRunning, isTrue);
    final r = feed(s, pluck(clock.time, 40));
    expect(r.single.noteIndex, 0);
    run(s, 0.3);
    expect(clock.isRunning, isTrue); // never stopped
  });

  test('too early is ignored', () {
    final s = start();
    run(s, 0.3); // song time about -0.7
    expect(feed(s, pluck(clock.time, 40)), isEmpty);
  });

  test('pitch arriving after the attack still counts', () {
    final s = start();
    run(s, 2);
    final r = feed(s, [
      NoteEvent(clock.time, null, onset: true),
      NoteEvent(clock.time + 0.08, 82.41),
    ]);
    expect(r, hasLength(1));
  });
}
