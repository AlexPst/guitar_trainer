import 'package:flutter_soloud/flutter_soloud.dart';

import '../engine/metronome_scheduler.dart';
import 'click_sound.dart';

/// Metronome clicks pinned to SoLoud's engine clock with sample accuracy.
///
/// On [anchor] the current engine time is matched to the current song time;
/// each beat is then placed at its exact offset from that anchor, so frame
/// jitter in the caller never reaches the audio.
class SoloudMetronome implements MetronomeSink {
  SoloudMetronome._(this._soloud, this._accent, this._normal);

  static Future<SoloudMetronome> create() async {
    final soloud = SoLoud.instance;
    if (!soloud.isInitialized) {
      await soloud.init(bufferSize: 1024);
    }
    final accent = await soloud.loadMem(
      'click_accent.wav',
      makeClickWav(frequency: 1760),
    );
    final normal = await soloud.loadMem(
      'click.wav',
      makeClickWav(frequency: 1175, amplitude: 0.6),
    );
    return SoloudMetronome._(soloud, accent, normal);
  }

  final SoLoud _soloud;
  final AudioSource _accent;
  final AudioSource _normal;

  double volume = 0.8;

  Duration _engineAnchor = Duration.zero;
  double _songAnchor = 0;
  double _speed = 1;
  final List<(SoundHandle, Duration)> _pending = [];

  @override
  void anchor(double songTime, double speed) {
    _engineAnchor = _soloud.getEngineTime();
    _songAnchor = songTime;
    _speed = speed;
  }

  @override
  void schedule(Beat beat) {
    final offset = (beat.time - _songAnchor) / _speed;
    final at = _engineAnchor + Duration(microseconds: (offset * 1e6).round());
    final handle = _soloud.playScheduled(
      beat.isDownbeat ? _accent : _normal,
      at,
      volume: volume,
    );
    final now = _soloud.getEngineTime();
    _pending
      ..removeWhere((p) => p.$2 < now)
      ..add((handle, at));
  }

  @override
  void cancelPending() {
    final now = _soloud.getEngineTime();
    for (final (handle, at) in _pending) {
      if (at >= now) _soloud.stop(handle);
    }
    _pending.clear();
  }

  Future<void> dispose() async {
    cancelPending();
    await _soloud.disposeSource(_accent);
    await _soloud.disposeSource(_normal);
  }
}
