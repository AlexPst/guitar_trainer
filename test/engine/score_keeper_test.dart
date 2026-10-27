import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/engine/note_result.dart';
import 'package:guitar_trainer/engine/score_keeper.dart';

void main() {
  test('points, combo and counts', () {
    final s = ScoreKeeper();
    final seq = [
      Judgement.hit,
      Judgement.early,
      Judgement.late,
      Judgement.octave,
      Judgement.hit,
      Judgement.hit,
      Judgement.miss,
      Judgement.wrongPitch,
      Judgement.hit,
    ];
    final combos = <int>[];
    for (var i = 0; i < seq.length; i++) {
      s.add(NoteResult(i, seq[i]));
      combos.add(s.combo);
    }
    expect(combos, [1, 2, 3, 0, 1, 2, 0, 0, 1]);
    expect(s.maxCombo, 3);
    expect(s.score, 100 + 70 + 70 + 30 + 100 + 100 + 0 + 0 + 100);
    expect(s.counts[Judgement.hit], 4);
    expect(s.judged, seq.length);

    s.reset();
    expect((s.score, s.combo, s.maxCombo, s.judged), (0, 0, 0, 0));
  });
}
