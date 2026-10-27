import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/engine/song_clock.dart';

import 'fake_time.dart';

void main() {
  late FakeTime t;
  late SongClock clock;

  setUp(() {
    t = FakeTime();
    clock = SongClock(now: t.source);
  });

  test('stopped clock does not move', () {
    t.advance(5);
    expect(clock.time, 0);
    expect(clock.isRunning, isFalse);
  });

  test('runs from the start position', () {
    clock.start(-2);
    t.advance(1.5);
    expect(clock.time, closeTo(-0.5, 1e-9));
  });

  test('pause freezes, resume continues without a jump', () {
    clock.start();
    t.advance(3);
    clock.pause();
    t.advance(10);
    expect(clock.time, closeTo(3, 1e-9));
    clock.resume();
    t.advance(1);
    expect(clock.time, closeTo(4, 1e-9));
  });

  test('speed 50% halves progress, change keeps position continuous', () {
    clock.start();
    t.advance(2);
    clock.speed = 0.5;
    expect(clock.time, closeTo(2, 1e-9));
    t.advance(2);
    expect(clock.time, closeTo(3, 1e-9));
  });

  test('speed is clamped to 50..100%', () {
    clock.speed = 0.1;
    expect(clock.speed, SongClock.minSpeed);
    clock.speed = 2;
    expect(clock.speed, SongClock.maxSpeed);
  });

  test('seek jumps while running', () {
    clock.start();
    t.advance(1);
    clock.seek(10);
    t.advance(1);
    expect(clock.time, closeTo(11, 1e-9));
  });

  test('time does not depend on how often it is read', () {
    clock.start();
    for (var i = 0; i < 7200; i++) {
      t.advance(1 / 60);
      clock.time;
    }
    expect(clock.time, closeTo(t.seconds, 1e-9));
    expect(clock.time, closeTo(120, 0.01));
  });
}
