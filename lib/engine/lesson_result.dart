import '../music/lesson.dart';
import 'note_result.dart';
import 'score_keeper.dart';

/// Outcome of one finished run of a lesson.
class LessonResult {
  LessonResult({
    required this.lesson,
    required List<NoteResult> results,
    required this.scored,
    required this.maxCombo,
  }) : results = List.unmodifiable(results),
       assert(results.length == lesson.notes.length);

  /// Builds a result from per-note results; notes never judged count as miss.
  factory LessonResult.fromNotes(
    Lesson lesson,
    List<NoteResult?> perNote, {
    required bool scored,
    required int maxCombo,
  }) => LessonResult(
    lesson: lesson,
    results: [
      for (var i = 0; i < lesson.notes.length; i++)
        perNote[i] ?? NoteResult(i, Judgement.miss),
    ],
    scored: scored,
    maxCombo: maxCombo,
  );

  /// Thresholds of accuracy for 1, 2 and 3 stars.
  static const starThresholds = [0.6, 0.8, 0.95];

  static int starsFor(double accuracy) =>
      starThresholds.where((t) => accuracy >= t - 1e-9).length;

  final Lesson lesson;
  final List<NoteResult> results;

  /// False for wait mode: no timing, no stars, no progress.
  final bool scored;
  final int maxCombo;

  int get score =>
      results.fold(0, (s, r) => s + ScoreKeeper.pointsFor(r.judgement));

  /// 0..1: points earned out of the maximum (every note a hit).
  double get accuracy => results.isEmpty ? 0 : score / (100 * results.length);

  int get stars => scored ? starsFor(accuracy) : 0;

  int count(Judgement j) => results.where((r) => r.judgement == j).length;

  int get playedCount => results.where((r) => r.judgement.isPlayed).length;

  /// Mean timing error of played notes, seconds; negative = rushing.
  double? get meanTiming {
    final errors = [
      for (final r in results)
        if (r.judgement.isPlayed && r.timingError != null) r.timingError!,
    ];
    if (errors.isEmpty) return null;
    return errors.reduce((a, b) => a + b) / errors.length;
  }

  /// Every note that was not a clean hit, in lesson order.
  List<NoteResult> get mistakes =>
      results.where((r) => r.judgement != Judgement.hit).toList();
}
