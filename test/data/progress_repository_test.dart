import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/data/progress_repository.dart';
import 'package:guitar_trainer/engine/lesson_result.dart';
import 'package:guitar_trainer/engine/note_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/fake_time.dart';

LessonResult run(int hits, {int total = 4, bool scored = true}) {
  final lesson = testLesson(beats: total);
  return LessonResult(
    lesson: lesson,
    results: [
      for (var i = 0; i < total; i++)
        NoteResult(i, i < hits ? Judgement.hit : Judgement.miss),
    ],
    scored: scored,
    maxCombo: hits,
  );
}

void main() {
  late ProgressRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = ProgressRepository(await SharedPreferences.getInstance());
  });

  test('stores the first result and only better ones', () async {
    expect(await repo.record(run(2)), RecordOutcome.first); // 50%
    expect(repo.loadAll()['t']!.bestAccuracy, 0.5);
    expect(await repo.record(run(1)), RecordOutcome.notSaved); // worse
    expect(await repo.record(run(2)), RecordOutcome.notSaved); // equal
    expect(await repo.record(run(4)), RecordOutcome.improved); // 100%
    final p = repo.loadAll()['t']!;
    expect((p.bestAccuracy, p.bestScore, p.stars), (1.0, 400, 3));
  });

  test('wait mode results are not stored', () async {
    expect(await repo.record(run(4, scored: false)), RecordOutcome.notSaved);
    expect(repo.loadAll(), isEmpty);
  });

  test('survives a reload of preferences', () async {
    await repo.record(run(3)); // 75% -> 1 star
    final again = ProgressRepository(await SharedPreferences.getInstance());
    expect(again.loadAll()['t']!.stars, 1);
  });

  test('corrupt entry is skipped', () async {
    SharedPreferences.setMockInitialValues({
      'progress.bad': '{oops',
      'progress.ok': '{"bestAccuracy":0.9,"bestScore":90,"stars":2}',
      'other': 'x',
    });
    final r = ProgressRepository(await SharedPreferences.getInstance());
    expect(r.loadAll().keys, ['ok']);
  });

  test('clear removes only progress', () async {
    SharedPreferences.setMockInitialValues({
      'progress.a': '{"bestAccuracy":0.9,"bestScore":90,"stars":2}',
      'settings': '{}',
    });
    final prefs = await SharedPreferences.getInstance();
    final r = ProgressRepository(prefs);
    await r.clear();
    expect(r.loadAll(), isEmpty);
    expect(prefs.getString('settings'), '{}');
  });

  test('unlock rules', () {
    const ids = ['a', 'b', 'c', 'd'];
    LessonProgress p(int stars) =>
        LessonProgress(bestAccuracy: 0.5, bestScore: 1, stars: stars);
    expect(unlockedFlags(ids, {}), [true, false, false, false]);
    expect(unlockedFlags(ids, {'a': p(0)}), [true, false, false, false]);
    expect(unlockedFlags(ids, {'a': p(1)}), [true, true, false, false]);
    // Played before stays open even if the previous one has no stars.
    expect(unlockedFlags(ids, {'a': p(1), 'c': p(0)}), [
      true,
      true,
      true,
      false,
    ]);
  });
}
