import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/audio/isolate_note_event_source.dart';
import 'package:guitar_trainer/audio/note_event_source.dart';
import 'package:guitar_trainer/engine/note_event.dart';
import 'package:guitar_trainer/music/pitch.dart';

import 'signals.dart';
import 'synth.dart';

void main() {
  test('same events as the synchronous source, in order', () async {
    final synth = Synth();
    for (var i = 0; i < 6; i++) {
      synth.pluck(0.2 + i * 0.3, midiToFrequency(40 + i * 3));
      synth.click(0.1 + i * 0.3);
    }
    final chunks = [
      for (var i = 0; i < 100; i++) Float32List.fromList(synth.render(1024)),
    ];
    double songTimeAt(int i) => (i + 1) * 1024 / sampleRate - 0.5;

    final sync = NoteEventSource(sampleRate: sampleRate);
    final expected = [
      for (var i = 0; i < chunks.length; i++)
        ...sync.add(chunks[i], songTime: songTimeAt(i)),
    ];

    final iso = await IsolateNoteEventSource.spawn(sampleRate: sampleRate);
    addTearDown(iso.dispose);
    expect(iso.delay, sync.delay);
    final got = <NoteEvent>[];
    final sub = iso.events.listen(got.addAll);
    for (var i = 0; i < chunks.length; i++) {
      iso.add(chunks[i], songTime: songTimeAt(i));
    }
    // Wait until the worker has answered everything.
    for (var tries = 0; tries < 200 && got.length < expected.length; tries++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await sub.cancel();

    expect(expected.where((e) => e.onset), hasLength(6));
    expect(got.map((e) => (e.time, e.frequency, e.onset)).toList(), [
      for (final e in expected) (e.time, e.frequency, e.onset),
    ]);
  });
}
