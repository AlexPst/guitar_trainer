import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/engine/metronome_scheduler.dart';
import 'package:guitar_trainer/engine/song_clock.dart';

import 'fake_time.dart';

/// Drives a scheduler like the game loop does, with irregular frames.
class Loop {
  Loop({double bpm = 70, this.seed = 7})
    : grid = BeatGrid(60 / bpm, 4),
      time = FakeTime() {
    clock = SongClock(now: time.source);
    sink = RecordingSink(time);
    scheduler = MetronomeScheduler(grid);
  }

  final BeatGrid grid;
  final FakeTime time;
  final int seed;
  late final SongClock clock;
  late final RecordingSink sink;
  late final MetronomeScheduler scheduler;
  late final _rnd = math.Random(seed);

  void sync() {
    sink.cancelPending();
    sink.anchor(clock.time, clock.speed);
    scheduler.reset(clock.time);
    scheduler.due(clock.time).forEach(sink.schedule);
  }

  /// Runs frames of 5..40 ms for [seconds] of real time.
  void run(double seconds) {
    final end = time.seconds + seconds;
    while (time.seconds < end) {
      time.advance(0.005 + _rnd.nextDouble() * 0.035);
      scheduler.due(clock.time).forEach(sink.schedule);
    }
  }
}

void main() {
  test('beat grid', () {
    const g = BeatGrid(0.5, 4);
    expect(g.beat(-4).time, -2);
    expect(g.beat(-4).isDownbeat, isTrue);
    expect(g.beat(-3).isDownbeat, isFalse);
    expect(g.beat(8).isDownbeat, isTrue);
    expect(g.firstIndexAtOrAfter(-2), -4);
    expect(g.firstIndexAtOrAfter(1.0), 2);
    expect(g.firstIndexAtOrAfter(1.01), 3);
    // Float noise right on a beat must not skip it.
    expect(g.firstIndexAtOrAfter(3 * 0.1 / 0.1 * 0.5), 3);
  });

  test('2 minutes with jittery frames: every beat once, exactly on time', () {
    final loop = Loop(bpm: 70);
    final spb = loop.grid.secondsPerBeat;
    loop.clock.start(-4 * spb); // one bar count-in
    loop.sync();
    loop.run(120);

    final beats = loop.sink.played;
    final indices = beats.map((p) => p.$1.index).toList();
    expect(indices.first, -4);
    expect(indices, [for (var i = -4; i <= indices.last; i++) i]);
    // 120 s at 70 BPM = 140 beats, plus the 0.3 s lookahead.
    expect(indices.last, inInclusiveRange(135, 137));

    for (final (beat, playAt, scheduledAt) in beats) {
      final ideal = (beat.index + 4) * spb; // real time, clock started at 0
      expect(playAt, closeTo(ideal, 1e-6), reason: '$beat');
      expect(scheduledAt, lessThanOrEqualTo(playAt + 1e-9), reason: 'late');
    }
  });

  test('pause and resume: no duplicates, no gaps, shifted by the pause', () {
    final loop = Loop(bpm: 100, seed: 3);
    loop.clock.start();
    loop.sync();
    loop.run(10);
    loop.clock.pause();
    loop.sink.cancelPending();
    final pausedAt = loop.time.seconds;
    final songAtPause = loop.clock.time;
    loop.time.advance(5);
    loop.clock.resume();
    loop.sync();
    loop.run(10);

    final indices = loop.sink.played.map((p) => p.$1.index).toList();
    expect(indices, [for (var i = 0; i <= indices.last; i++) i]);
    for (final (beat, playAt, _) in loop.sink.played) {
      final ideal = beat.time < songAtPause
          ? beat.time
          : pausedAt + 5 + (beat.time - songAtPause);
      expect(playAt, closeTo(ideal, 1e-6), reason: '$beat');
    }
  });

  test('speed 50%: clicks twice as far apart in real time', () {
    final loop = Loop(bpm: 120);
    loop.clock
      ..start()
      ..speed = 0.5;
    loop.sync();
    loop.run(30);
    final times = loop.sink.played.map((p) => p.$2).toList();
    for (var i = 1; i < times.length; i++) {
      expect(times[i] - times[i - 1], closeTo(1.0, 1e-6));
    }
    expect(times.length, inInclusiveRange(30, 31));
  });

  test('stops after lastIndex', () {
    final s = MetronomeScheduler(const BeatGrid(0.5, 4), lastIndex: 8)
      ..reset(0);
    expect(s.due(100).map((b) => b.index), [for (var i = 0; i <= 8; i++) i]);
    expect(s.due(200), isEmpty);
  });
}
