import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../music/tuner_reading.dart';
import 'level_meter.dart';
import 'mic_capture.dart';
import 'pitch_tracker.dart';

/// Microphone level in dBFS while someone is listening.
final micLevelProvider = StreamProvider.autoDispose<double>((ref) async* {
  final mic = MicCapture();
  ref.onDispose(mic.dispose);
  await mic.start();
  yield* mic.samples.map((s) => rmsToDbfs(rms(s)));
});

/// Smoothed tuner reading, or null when nothing pitched is heard.
final tunerProvider = StreamProvider.autoDispose<TunerReading?>((ref) async* {
  final mic = MicCapture();
  ref.onDispose(mic.dispose);
  await mic.start();
  final tracker = PitchTracker(sampleRate: mic.sampleRate);
  await for (final chunk in mic.samples) {
    for (final frequency in tracker.add(chunk)) {
      yield frequency == null ? null : TunerReading(frequency);
    }
  }
});
