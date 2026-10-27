import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/lesson_result.dart';

/// Best result of a lesson, kept on the device.
class LessonProgress {
  const LessonProgress({
    required this.bestAccuracy,
    required this.bestScore,
    required this.stars,
  });

  factory LessonProgress.fromJson(Map<String, Object?> json) => LessonProgress(
    bestAccuracy: (json['bestAccuracy']! as num).toDouble(),
    bestScore: json['bestScore']! as int,
    stars: json['stars']! as int,
  );

  final double bestAccuracy;
  final int bestScore;
  final int stars;

  Map<String, Object?> toJson() => {
    'bestAccuracy': bestAccuracy,
    'bestScore': bestScore,
    'stars': stars,
  };
}

enum RecordOutcome {
  /// Not better than the stored best (or not scored at all).
  notSaved,

  /// First result of this lesson.
  first,

  /// Beat the previous best: a new record.
  improved,
}

/// Stores [LessonProgress] per lesson id in shared preferences.
class ProgressRepository {
  ProgressRepository(this._prefs);

  static const _prefix = 'progress.';

  final SharedPreferences _prefs;

  Map<String, LessonProgress> loadAll() {
    final out = <String, LessonProgress>{};
    for (final key in _prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      try {
        final json = jsonDecode(_prefs.getString(key)!) as Map<String, Object?>;
        out[key.substring(_prefix.length)] = LessonProgress.fromJson(json);
      } on Object {
        // A corrupt entry only loses that lesson's record.
      }
    }
    return out;
  }

  /// Saves [result] if it beats the stored one.
  Future<RecordOutcome> record(LessonResult result) async {
    if (!result.scored) return RecordOutcome.notSaved;
    final id = result.lesson.id;
    final old = loadAll()[id];
    final better =
        old == null ||
        result.accuracy > old.bestAccuracy ||
        (result.accuracy == old.bestAccuracy && result.score > old.bestScore);
    if (!better) return RecordOutcome.notSaved;
    final progress = LessonProgress(
      bestAccuracy: result.accuracy,
      bestScore: result.score,
      stars: result.stars,
    );
    await _prefs.setString('$_prefix$id', jsonEncode(progress.toJson()));
    return old == null ? RecordOutcome.first : RecordOutcome.improved;
  }

  Future<void> clear() async {
    for (final key in _prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      await _prefs.remove(key);
    }
  }
}

/// Which lessons can be played. The first always; each next one once the
/// previous has at least one star (or it was already played before).
List<bool> unlockedFlags(
  List<String> lessonIds,
  Map<String, LessonProgress> progress,
) => [
  for (var i = 0; i < lessonIds.length; i++)
    i == 0 ||
        progress.containsKey(lessonIds[i]) ||
        (progress[lessonIds[i - 1]]?.stars ?? 0) >= 1,
];

final progressRepositoryProvider = FutureProvider<ProgressRepository>(
  (ref) async => ProgressRepository(await SharedPreferences.getInstance()),
);

class ProgressNotifier extends AsyncNotifier<Map<String, LessonProgress>> {
  @override
  Future<Map<String, LessonProgress>> build() async =>
      (await ref.watch(progressRepositoryProvider.future)).loadAll();

  /// Stores the result if it is a new best.
  Future<RecordOutcome> record(LessonResult result) async {
    final repo = await ref.read(progressRepositoryProvider.future);
    final outcome = await repo.record(result);
    if (outcome != RecordOutcome.notSaved) state = AsyncData(repo.loadAll());
    return outcome;
  }
}

final progressProvider =
    AsyncNotifierProvider<ProgressNotifier, Map<String, LessonProgress>>(
      ProgressNotifier.new,
    );
