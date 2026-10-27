import '../music/guitar_tuning.dart';
import '../music/lesson.dart';
import 'note_event.dart';
import 'note_result.dart';
import 'pitch_match.dart';
import 'song_clock.dart';

/// "Wait" mode: the song stops on each note until it is played right.
///
/// Call [update] every frame: it holds [clock] at the current note. Feed
/// heard events to [addEvent]; the right pitch releases the clock.
/// No timing judgement: every accepted note is a [Judgement.hit].
class WaitModeSession {
  WaitModeSession(
    this.lesson,
    this.clock, {
    this.tuning = GuitarTuning.standard,
    this.approachWindow = 0.25,
    this.pitchSettle = 0.1,
  });

  final Lesson lesson;
  final SongClock clock;
  final GuitarTuning tuning;

  /// A note may be played this long (song seconds) before it reaches the line.
  final double approachWindow;

  /// Pitch may arrive this long after the attack, in non-onset events.
  final double pitchSettle;

  int _current = 0;
  bool _holding = false;
  double? _attackTime;
  bool _attackUsed = false;

  int get currentIndex => _current;
  bool get isComplete => _current >= lesson.notes.length;

  /// True while the clock is stopped waiting for the player.
  bool get isHolding => _holding;

  /// Song time the clock stops at, or null when all notes are done.
  double? get holdTime =>
      isComplete ? null : lesson.noteTime(lesson.notes[_current]);

  void update() {
    final h = holdTime;
    if (h == null || !clock.isRunning || clock.time < h) return;
    clock
      ..pause()
      ..seek(h);
    _holding = true;
  }

  /// Returns a hit when [e] plays the current note, otherwise null.
  NoteResult? addEvent(NoteEvent e) {
    if (isComplete) return null;
    if (e.onset) {
      _attackTime = e.time;
      _attackUsed = false;
    }
    // Each attack may complete one note: repeated notes need repeated plucks.
    final attack = _attackTime;
    if (attack == null || _attackUsed || e.time - attack > pitchSettle) {
      return null;
    }
    final f = e.frequency;
    final target = lesson.notes[_current];
    if (f == null || clock.time < holdTime! - approachWindow) return null;
    final m = matchPitch(f, target.midi(tuning));
    if (m.kind != PitchMatchKind.match) return null;

    _attackUsed = true;
    final result = NoteResult(_current, Judgement.hit, cents: m.cents);
    _current++;
    if (_holding) {
      _holding = false;
      clock.resume();
    }
    return result;
  }
}
