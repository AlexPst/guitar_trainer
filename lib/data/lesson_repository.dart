import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../music/lesson.dart';
import '../music/lesson_parser.dart';

const lessonsDir = 'assets/lessons/';

/// One lesson file: either parsed, or the reason it could not be.
class LessonEntry {
  const LessonEntry.ok(this.asset, Lesson this.lesson) : error = null;
  const LessonEntry.broken(this.asset, Object this.error) : lesson = null;

  final String asset;
  final Lesson? lesson;
  final Object? error;
}

class LessonRepository {
  LessonRepository(this._bundle);

  final AssetBundle _bundle;

  /// All lesson files sorted by asset name.
  Future<List<LessonEntry>> loadAll() async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final assets =
        manifest
            .listAssets()
            .where((a) => a.startsWith(lessonsDir) && a.endsWith('.json'))
            .toList()
          ..sort();
    return [for (final a in assets) await _load(a)];
  }

  Future<LessonEntry> _load(String asset) async {
    final name = asset.substring(lessonsDir.length);
    try {
      final text = await _bundle.loadString(asset);
      return LessonEntry.ok(asset, parseLessonJson(text, source: name));
    } on LessonFormatException catch (e) {
      return LessonEntry.broken(asset, e);
    }
  }
}

final lessonRepositoryProvider = Provider<LessonRepository>(
  (ref) => LessonRepository(rootBundle),
);

final lessonsProvider = FutureProvider<List<LessonEntry>>(
  (ref) => ref.watch(lessonRepositoryProvider).loadAll(),
);
