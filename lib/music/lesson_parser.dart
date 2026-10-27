import 'dart:convert';

import 'lesson.dart';

/// A lesson file is malformed. [path] points at the offending field.
class LessonFormatException implements Exception {
  const LessonFormatException(this.path, this.message, {this.source});

  final String path;
  final String message;

  /// File name or asset key, when known.
  final String? source;

  LessonFormatException withSource(String source) =>
      LessonFormatException(path, message, source: source);

  @override
  String toString() {
    final where = path.isEmpty ? '' : '$path: ';
    final file = source == null ? '' : '$source: ';
    return '$file$where$message';
  }
}

const int maxFret = 24;
const int stringCount = 6;

Lesson parseLessonJson(String text, {String? source}) {
  final Object? data;
  try {
    data = jsonDecode(text);
  } on FormatException catch (e) {
    throw LessonFormatException(
      '',
      'некорректный JSON: ${e.message}',
      source: source,
    );
  }
  try {
    return parseLesson(data);
  } on LessonFormatException catch (e) {
    throw source == null ? e : e.withSource(source);
  }
}

Lesson parseLesson(Object? data) {
  final root = _map(data, '');
  final id = _string(root, 'id');
  final title = _string(root, 'title');
  final description = _optionalString(root, 'description');

  final bpm = _number(root, 'bpm');
  if (bpm < 20 || bpm > 300) {
    throw const LessonFormatException('bpm', 'должен быть от 20 до 300');
  }

  final notesRaw = root['notes'];
  if (notesRaw is! List) {
    throw const LessonFormatException('notes', 'ожидался список нот');
  }
  if (notesRaw.isEmpty) {
    throw const LessonFormatException('notes', 'урок без нот');
  }
  final notes = <TabNote>[];
  for (var i = 0; i < notesRaw.length; i++) {
    final note = _note(notesRaw[i], 'notes[$i]');
    if (notes.isNotEmpty) {
      final prev = notes.last.beat;
      if (note.beat == prev) {
        throw LessonFormatException(
          'notes[$i].beat',
          'две ноты на одной доле ($prev): аккорды пока не поддерживаются',
        );
      }
      if (note.beat < prev) {
        throw LessonFormatException(
          'notes[$i].beat',
          'ноты должны идти по возрастанию beat ($prev, затем ${note.beat})',
        );
      }
    }
    notes.add(note);
  }

  return Lesson(
    id: id,
    title: title,
    description: description,
    bpm: bpm,
    timeSignature: _timeSignature(root['timeSignature']),
    notes: List.unmodifiable(notes),
  );
}

TabNote _note(Object? raw, String path) {
  final m = _map(raw, path);
  final beat = _number(m, 'beat', path);
  if (beat < 0) {
    throw LessonFormatException('$path.beat', 'не может быть отрицательным');
  }
  final string = _int(m, 'string', path);
  if (string < 1 || string > stringCount) {
    throw LessonFormatException('$path.string', 'должна быть от 1 до 6');
  }
  final fret = _int(m, 'fret', path);
  if (fret < 0 || fret > maxFret) {
    throw LessonFormatException('$path.fret', 'должен быть от 0 до $maxFret');
  }
  final duration = _number(m, 'duration', path);
  if (duration <= 0) {
    throw LessonFormatException('$path.duration', 'должна быть больше 0');
  }
  return TabNote(beat: beat, string: string, fret: fret, duration: duration);
}

TimeSignature _timeSignature(Object? raw) {
  const path = 'timeSignature';
  if (raw is! List || raw.length != 2 || raw.any((v) => v is! int)) {
    throw const LessonFormatException(path, 'ожидалось [доли, длительность]');
  }
  final beats = raw[0] as int;
  final unit = raw[1] as int;
  if (beats < 1 || beats > 16) {
    throw const LessonFormatException(path, 'число долей от 1 до 16');
  }
  if (!const [1, 2, 4, 8, 16].contains(unit)) {
    throw const LessonFormatException(path, 'длительность 1, 2, 4, 8 или 16');
  }
  return TimeSignature(beats, unit);
}

Map<String, Object?> _map(Object? raw, String path) {
  if (raw is Map<String, Object?>) return raw;
  throw LessonFormatException(path, 'ожидался объект');
}

String _join(String parent, String key) =>
    parent.isEmpty ? key : '$parent.$key';

String _string(Map<String, Object?> m, String key, [String parent = '']) {
  final v = m[key];
  if (v is String && v.trim().isNotEmpty) return v;
  throw LessonFormatException(
    _join(parent, key),
    v == null ? 'обязательное поле' : 'ожидалась непустая строка',
  );
}

String? _optionalString(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v == null || v is String) return v as String?;
  throw LessonFormatException(key, 'ожидалась строка');
}

double _number(Map<String, Object?> m, String key, [String parent = '']) {
  final v = m[key];
  if (v is num) return v.toDouble();
  throw LessonFormatException(
    _join(parent, key),
    v == null ? 'обязательное поле' : 'ожидалось число',
  );
}

int _int(Map<String, Object?> m, String key, [String parent = '']) {
  final v = m[key];
  if (v is int) return v;
  throw LessonFormatException(
    _join(parent, key),
    v == null ? 'обязательное поле' : 'ожидалось целое число',
  );
}
