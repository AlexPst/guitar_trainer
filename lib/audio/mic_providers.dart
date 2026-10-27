import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'level_meter.dart';
import 'mic_capture.dart';

/// Microphone level in dBFS while someone is listening.
final micLevelProvider = StreamProvider.autoDispose<double>((ref) async* {
  final mic = MicCapture();
  ref.onDispose(mic.dispose);
  await mic.start();
  yield* mic.samples.map((s) => rmsToDbfs(rms(s)));
});
