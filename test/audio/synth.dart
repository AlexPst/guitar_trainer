import 'dart:math' as math;
import 'dart:typed_data';

import 'package:guitar_trainer/audio/click_sound.dart';

import 'signals.dart';

/// Renders a monophonic "guitar" plus metronome clicks, chunk by chunk.
///
/// Each pluck damps the previous note for [muteMs] (pick touching the string)
/// and then sounds a decaying harmonic tone, so it can be scheduled ahead or
/// added on the fly while rendering.
class Synth {
  Synth({
    this.decay = 0.5,
    this.muteMs = 8,
    this.amp = 0.5,
    this.clickAmp = 0.4,
  });

  final double decay;
  final double muteMs;
  final double amp;
  final double clickAmp;

  /// (start sample of the sound, frequency), sorted.
  final List<(int, double)> _plucks = [];
  final List<int> _clicks = [];
  late final Float32List _clickPcm = () {
    final wav = makeClickWav(frequency: 1175);
    final pcm = Int16List.sublistView(wav, 44);
    return Float32List.fromList([for (final s in pcm) s / 32768 * clickAmp]);
  }();

  int position = 0;

  int _sample(double seconds) => (seconds * sampleRate).round();

  /// Pick hits the string at [seconds]; the note sounds [muteMs] later.
  void pluck(double seconds, double frequency) {
    final start = _sample(seconds + muteMs / 1000);
    _plucks
      ..add((start, frequency))
      ..sort((a, b) => a.$1.compareTo(b.$1));
  }

  void click(double seconds) => _clicks.add(_sample(seconds));

  Float32List render(int n) {
    final out = Float32List(n);
    final mute = _sample(muteMs / 1000);
    for (var k = 0; k < n; k++) {
      final i = position + k;
      // Latest pluck that has started, and whether the next one is muting it.
      var p = -1;
      for (var j = 0; j < _plucks.length && _plucks[j].$1 <= i; j++) {
        p = j;
      }
      final nextStart = p + 1 < _plucks.length ? _plucks[p + 1].$1 : null;
      final muting = nextStart != null && nextStart - i <= mute;
      if (p >= 0 && !muting) {
        final (start, f) = _plucks[p];
        final t = (i - start) / sampleRate;
        out[k] =
            amp *
            math.exp(-t / decay) *
            (math.sin(2 * math.pi * f * t) +
                0.5 * math.sin(4 * math.pi * f * t) +
                0.25 * math.sin(6 * math.pi * f * t)) /
            1.75;
      }
      for (final c in _clicks) {
        final d = i - c;
        if (d >= 0 && d < _clickPcm.length) out[k] += _clickPcm[d];
      }
    }
    position += n;
    return out;
  }
}
