import 'lesson_result.dart';
import 'note_result.dart';

/// How much a result counts as a "problem" when looking for hard spots.
double _weight(Judgement j) => switch (j) {
  Judgement.hit => 0,
  Judgement.early || Judgement.late => 0.3,
  Judgement.octave => 0.7,
  Judgement.wrongPitch || Judgement.miss => 1,
};

/// The [span] consecutive bars with the most mistakes, as (fromBar, toBar),
/// 1-based inclusive. Null when there is nothing to practise.
(int, int)? hardestBars(LessonResult result, {int span = 2}) {
  final lesson = result.lesson;
  final bars = lesson.barCount;
  if (bars == 0) return null;
  final perBar = List<double>.filled(bars, 0);
  for (final r in result.results) {
    perBar[lesson.barOf(lesson.notes[r.noteIndex]) - 1] += _weight(r.judgement);
  }
  final width = span.clamp(1, bars);
  (int, int)? best;
  var bestWeight = 0.0;
  for (var from = 0; from + width <= bars; from++) {
    var w = 0.0;
    for (var b = from; b < from + width; b++) {
      w += perBar[b];
    }
    if (w > bestWeight + 1e-9) {
      bestWeight = w;
      best = (from + 1, from + width);
    }
  }
  return best;
}

/// Tempo for the next loop pass: faster after a clean pass, slower after a
/// poor one, in steps of [step], kept within 50..100%.
double nextSpeed(
  double speed,
  double accuracy, {
  double step = 0.1,
  double up = 0.9,
  double down = 0.6,
}) {
  var next = speed;
  if (accuracy >= up) next += step;
  if (accuracy < down) next -= step;
  // Round to whole percent so repeated steps don't drift (0.7000000001).
  return (next.clamp(0.5, 1.0) * 100).roundToDouble() / 100;
}
