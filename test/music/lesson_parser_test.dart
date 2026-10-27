import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/music/lesson_parser.dart';

Map<String, Object?> valid() => {
  'id': 'basics_01',
  'title': 'Открытые струны',
  'bpm': 70,
  'timeSignature': [4, 4],
  'notes': [
    <String, Object?>{'beat': 0, 'string': 6, 'fret': 0, 'duration': 1},
    {'beat': 1, 'string': 5, 'fret': 0, 'duration': 1.5},
  ],
};

/// Expects parsing to fail with an error at [path] whose text contains [text].
void expectError(Object? data, String path, String text) {
  expect(
    () => parseLesson(data),
    throwsA(
      isA<LessonFormatException>()
          .having((e) => e.path, 'path', path)
          .having((e) => e.message, 'message', contains(text)),
    ),
  );
}

Map<String, Object?> withNote(int i, String key, Object? value) {
  final d = valid();
  final notes = (d['notes']! as List).cast<Map<String, Object?>>();
  if (value == null) {
    notes[i].remove(key);
  } else {
    notes[i][key] = value;
  }
  return d;
}

void main() {
  test('parses the format from the spec', () {
    final l = parseLesson(valid());
    expect(l.id, 'basics_01');
    expect(l.title, 'Открытые струны');
    expect(l.description, isNull);
    expect(l.bpm, 70);
    expect(l.timeSignature.beatsPerBar, 4);
    expect(l.notes, hasLength(2));
    expect(l.notes[1].string, 5);
    expect(l.notes[1].duration, 1.5);
  });

  test('optional description', () {
    final l = parseLesson(valid()..['description'] = 'Описание');
    expect(l.description, 'Описание');
    expectError(valid()..['description'] = 5, 'description', 'строка');
  });

  test('missing and wrong top-level fields', () {
    expectError(valid()..remove('id'), 'id', 'обязательное');
    expectError(valid()..['title'] = '  ', 'title', 'непустая строка');
    expectError(valid()..['bpm'] = '70', 'bpm', 'число');
    expectError(valid()..['bpm'] = 5, 'bpm', 'от 20 до 300');
    expectError(valid()..['notes'] = {}, 'notes', 'список');
    expectError(valid()..['notes'] = [], 'notes', 'без нот');
    expectError([1, 2], '', 'объект');
  });

  test('time signature', () {
    expectError(valid()..['timeSignature'] = [4], 'timeSignature', 'доли');
    expectError(
      valid()..['timeSignature'] = [0, 4],
      'timeSignature',
      '1 до 16',
    );
    expectError(valid()..['timeSignature'] = [3, 3], 'timeSignature', '8');
    expect(
      parseLesson(valid()..['timeSignature'] = [6, 8]).timeSignature.beatUnit,
      8,
    );
  });

  test('note fields', () {
    expectError(withNote(1, 'string', 7), 'notes[1].string', 'от 1 до 6');
    expectError(withNote(1, 'string', 0), 'notes[1].string', 'от 1 до 6');
    expectError(withNote(0, 'fret', -1), 'notes[0].fret', 'от 0 до 24');
    expectError(withNote(0, 'fret', 25), 'notes[0].fret', 'от 0 до 24');
    expectError(withNote(0, 'fret', 1.5), 'notes[0].fret', 'целое');
    expectError(withNote(0, 'duration', 0), 'notes[0].duration', 'больше 0');
    expectError(withNote(0, 'beat', -1), 'notes[0].beat', 'отрицательным');
    expectError(withNote(1, 'beat', null), 'notes[1].beat', 'обязательное');
    expectError(valid()..['notes'] = ['x'], 'notes[0]', 'объект');
  });

  test('notes must be in order and not share a beat', () {
    expectError(withNote(1, 'beat', 0), 'notes[1].beat', 'аккорды');
    final d = valid();
    (d['notes']! as List).add({
      'beat': 0.5,
      'string': 1,
      'fret': 0,
      'duration': 1,
    });
    expectError(d, 'notes[2].beat', 'по возрастанию');
  });

  test('json text errors name the file', () {
    expect(
      () => parseLessonJson('{oops', source: 'bad.json'),
      throwsA(
        isA<LessonFormatException>().having(
          (e) => e.toString(),
          'text',
          allOf(contains('bad.json'), contains('некорректный JSON')),
        ),
      ),
    );
    final text = jsonEncode(withNote(0, 'string', 9));
    expect(
      () => parseLessonJson(text, source: 'x.json'),
      throwsA(
        isA<LessonFormatException>().having(
          (e) => e.toString(),
          'text',
          'x.json: notes[0].string: должна быть от 1 до 6',
        ),
      ),
    );
  });

  group('bundled lessons', () {
    final files =
        Directory('assets/lessons')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    test('10 to 20 lessons, as in the spec', () {
      expect(files.length, inInclusiveRange(10, 20));
    });

    final ids = <String>{};
    for (final f in files) {
      test('${f.uri.pathSegments.last} parses', () {
        final l = parseLessonJson(f.readAsStringSync(), source: f.path);
        expect(ids.add(l.id), isTrue, reason: 'duplicate id ${l.id}');
        expect(l.notes, isNotEmpty);
        // Monophonic and playable in first 12 frets.
        expect(l.notes.every((n) => n.fret <= 12), isTrue);
      });
    }
  });
}
