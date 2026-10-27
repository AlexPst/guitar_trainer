import 'note_result.dart';

/// Points, combo and counts per judgement for one run of a lesson.
class ScoreKeeper {
  static int pointsFor(Judgement j) => switch (j) {
    Judgement.hit => 100,
    Judgement.early || Judgement.late => 70,
    Judgement.octave => 30,
    Judgement.wrongPitch || Judgement.miss => 0,
  };

  int score = 0;

  /// Played notes in a row; any other result resets it.
  int combo = 0;
  int maxCombo = 0;
  final Map<Judgement, int> counts = {for (final j in Judgement.values) j: 0};

  int get judged => counts.values.fold(0, (a, b) => a + b);

  void add(NoteResult r) {
    counts[r.judgement] = counts[r.judgement]! + 1;
    score += pointsFor(r.judgement);
    if (r.judgement.isPlayed) {
      combo++;
      if (combo > maxCombo) maxCombo = combo;
    } else {
      combo = 0;
    }
  }

  void reset() {
    score = 0;
    combo = 0;
    maxCombo = 0;
    counts.updateAll((_, _) => 0);
  }
}
