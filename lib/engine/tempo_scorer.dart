import '../music/guitar_tuning.dart';
import '../music/lesson.dart';
import 'note_event.dart';
import 'note_result.dart';
import 'pitch_match.dart';

/// "In tempo" mode: judges each note of [lesson] from attacks heard around it.
///
/// Feed events with [addEvent] and the current song time with [advance].
/// Both return results that became final; every note gets exactly one.
///
/// Matching rules:
/// - an attack goes to the nearest note whose window (±[hitWindow]) contains
///   it and that is not played yet;
/// - right pitch finalizes the note at once (hit / early / late);
/// - octave or wrong pitch is kept as a candidate and can be replaced by a
///   better attack until the window closes;
/// - pitch may arrive up to [pitchSettle] after the attack, in non-onset
///   events, and is credited to that attack's time;
/// - attacks with no note in reach count as [extraNotes].
class TempoScorer {
  TempoScorer(
    this.lesson, {
    this.tuning = GuitarTuning.standard,
    this.hitWindow = 0.12,
    this.perfectWindow = 0.05,
    this.pitchSettle = 0.1,
    this.calibrationOffset = 0,
    this.inputLag = 0,
    this.speed = 1,
  }) : _times = [for (final n in lesson.notes) lesson.noteTime(n)],
       _targets = [for (final n in lesson.notes) n.midi(tuning)],
       _results = List.filled(lesson.notes.length, null),
       _candidates = List.filled(lesson.notes.length, null);

  final Lesson lesson;
  final GuitarTuning tuning;

  /// Windows in real seconds; scaled by [speed] to song time.
  final double hitWindow;
  final double perfectWindow;
  final double pitchSettle;

  /// Input latency: event times are shifted back by this many seconds.
  final double calibrationOffset;

  /// How long after a sound its events reach [addEvent] (analysis delay),
  /// real seconds. Windows close this much later so late notes still count.
  final double inputLag;

  /// Playback speed (0.5..1). At half speed a real-time window covers half
  /// as much song time. May change between notes (e.g. in pause).
  double speed;

  final List<double> _times;
  final List<int> _targets;
  final List<NoteResult?> _results;
  final List<NoteResult?> _candidates;

  int _firstOpen = 0;
  int extraNotes = 0;

  /// Last attack: its corrected time and the note it was matched to.
  double? _attackTime;
  int? _attackNote;

  double get _window => hitWindow * speed;
  double get _perfect => perfectWindow * speed;

  /// Final results so far, by note index (null = still open).
  List<NoteResult?> get results => List.unmodifiable(_results);

  bool get isComplete => _firstOpen >= _results.length;

  List<NoteResult> addEvent(NoteEvent e) {
    final t = e.time - calibrationOffset;
    final out = <NoteResult>[];

    if (e.onset) {
      _attackTime = t;
      _attackNote = _nearestOpenNote(t);
      if (_attackNote == null) extraNotes++;
    } else if (_attackTime == null || t - _attackTime! > pitchSettle) {
      return out; // ringing note, nothing new
    }

    final note = _attackNote;
    final f = e.frequency;
    if (note == null || f == null || _results[note] != null) return out;
    _judge(note, _attackTime!, f, out);
    return out;
  }

  /// Closes windows that have passed. [songTime] is the uncorrected clock.
  List<NoteResult> advance(double songTime) {
    final t = songTime - calibrationOffset - inputLag * speed;
    final out = <NoteResult>[];
    for (var i = _firstOpen; i < _times.length; i++) {
      if (_times[i] + _window + pitchSettle >= t) break;
      if (_results[i] == null) {
        final r = _candidates[i] ?? NoteResult(i, Judgement.miss);
        _results[i] = r;
        out.add(r);
      }
    }
    while (_firstOpen < _results.length && _results[_firstOpen] != null) {
      _firstOpen++;
    }
    return out;
  }

  int? _nearestOpenNote(double t) {
    int? best;
    var bestDt = double.infinity;
    for (var i = _firstOpen; i < _times.length; i++) {
      final dt = (t - _times[i]).abs();
      if (_times[i] - t > _window) break; // sorted: the rest are later
      if (_results[i] != null || dt > _window) continue;
      if (dt < bestDt) {
        best = i;
        bestDt = dt;
      }
    }
    return best;
  }

  void _judge(int note, double t, double f, List<NoteResult> out) {
    final dt = t - _times[note];
    final m = matchPitch(f, _targets[note]);
    switch (m.kind) {
      case PitchMatchKind.match:
        final j = dt.abs() <= _perfect
            ? Judgement.hit
            : dt < 0
            ? Judgement.early
            : Judgement.late;
        final r = NoteResult(note, j, timingError: dt, cents: m.cents);
        _results[note] = r;
        out.add(r);
      case PitchMatchKind.octave:
        _candidates[note] = NoteResult(
          note,
          Judgement.octave,
          timingError: dt,
          cents: m.cents,
        );
      case PitchMatchKind.wrong:
        // Keep an octave candidate if there is one: it is closer.
        if (_candidates[note]?.judgement != Judgement.octave) {
          _candidates[note] = NoteResult(
            note,
            Judgement.wrongPitch,
            timingError: dt,
            cents: m.cents,
          );
        }
    }
  }
}
