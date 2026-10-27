class Beat {
  const Beat(this.index, this.time, {required this.isDownbeat});

  /// Beat number; negative during the count-in.
  final int index;

  /// Song time in seconds.
  final double time;
  final bool isDownbeat;

  @override
  String toString() => 'Beat($index @ ${time.toStringAsFixed(3)})';
}

class BeatGrid {
  const BeatGrid(this.secondsPerBeat, this.beatsPerBar);

  final double secondsPerBeat;
  final int beatsPerBar;

  Beat beat(int index) =>
      Beat(index, index * secondsPerBeat, isDownbeat: index % beatsPerBar == 0);

  /// Index of the first beat at or after [songTime].
  int firstIndexAtOrAfter(double songTime) =>
      (songTime / secondsPerBeat - 1e-9).ceil();
}

/// Receives metronome clicks; implemented by the audio layer.
abstract interface class MetronomeSink {
  /// Song time [songTime] corresponds to "now" from this call on, and song
  /// time advances at [speed]. Called on every start, resume or speed change.
  void anchor(double songTime, double speed);

  void schedule(Beat beat);

  /// Drops clicks scheduled but not yet played (pause, restart).
  void cancelPending();
}

/// Decides which beats to hand to a [MetronomeSink] ahead of time.
///
/// Tracks beat indices rather than times, so a beat is never sent twice and
/// never skipped, however irregular the frame times are.
class MetronomeScheduler {
  MetronomeScheduler(this.grid, {this.lookahead = 0.3, this.lastIndex});

  final BeatGrid grid;

  /// How far ahead of the current song time beats are scheduled, seconds.
  final double lookahead;

  /// Last beat to click, inclusive; null for no limit.
  final int? lastIndex;

  int _next = 0;

  /// Next beat from [songTime] on will be scheduled.
  void reset(double songTime) => _next = grid.firstIndexAtOrAfter(songTime);

  /// Beats that are now within the lookahead window and not yet scheduled.
  List<Beat> due(double songTime) {
    final out = <Beat>[];
    while ((lastIndex == null || _next <= lastIndex!) &&
        grid.beat(_next).time <= songTime + lookahead) {
      out.add(grid.beat(_next++));
    }
    return out;
  }
}
