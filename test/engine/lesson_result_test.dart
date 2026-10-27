import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/engine/lesson_result.dart';
import 'package:guitar_trainer/engine/note_result.dart';

import 'fake_time.dart';

LessonResult resultOf(
  List<Judgement> js, {
  List<double?>? timing,
  bool scored = true,
}) {
  final lesson = testLesson(beats: js.length);
  return LessonResult(
    lesson: lesson,
    results: [
      for (var i = 0; i < js.length; i++)
        NoteResult(i, js[i], timingError: timing?[i]),
    ],
    scored: scored,
    maxCombo: 0,
  );
}

void main() {
  test('accuracy is points out of the maximum', () {
    final r = resultOf([
      Judgement.hit,
      Judgement.late,
      Judgement.octave,
      Judgement.miss,
    ]);
    expect(r.score, 200);
    expect(r.accuracy, closeTo(0.5, 1e-9));
    expect(r.playedCount, 2);
    expect(r.mistakes.map((m) => m.noteIndex), [1, 2, 3]);
  });

  test('stars at 60 / 80 / 95 %', () {
    expect(LessonResult.starsFor(0.59), 0);
    expect(LessonResult.starsFor(0.60), 1);
    expect(LessonResult.starsFor(0.79), 1);
    expect(LessonResult.starsFor(0.80), 2);
    expect(LessonResult.starsFor(0.949), 2);
    expect(LessonResult.starsFor(0.95), 3);
    expect(LessonResult.starsFor(1), 3);
    // 19 hits + 1 miss = 95%
    expect(
      resultOf([...List.filled(19, Judgement.hit), Judgement.miss]).stars,
      3,
    );
  });

  test('wait mode gives no stars', () {
    final r = resultOf(List.filled(3, Judgement.hit), scored: false);
    expect(r.accuracy, 1);
    expect(r.stars, 0);
  });

  test('mean timing of played notes only', () {
    final r = resultOf(
      [Judgement.early, Judgement.hit, Judgement.miss, Judgement.wrongPitch],
      timing: [-0.08, -0.02, null, 0.3],
    );
    expect(r.meanTiming, closeTo(-0.05, 1e-9));
    expect(resultOf([Judgement.miss]).meanTiming, isNull);
  });

  test('unjudged notes count as misses', () {
    final lesson = testLesson();
    final r = LessonResult.fromNotes(
      lesson,
      [const NoteResult(0, Judgement.hit), null, null],
      scored: true,
      maxCombo: 1,
    );
    expect(r.results.map((x) => x.judgement), [
      Judgement.hit,
      Judgement.miss,
      Judgement.miss,
    ]);
  });
}
