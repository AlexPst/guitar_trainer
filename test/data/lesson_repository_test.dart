import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/data/lesson_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads bundled lessons in file name order', () async {
    final entries = await LessonRepository(rootBundle).loadAll();
    expect(entries, isNotEmpty);
    expect(entries.every((e) => e.lesson != null), isTrue);
    final assets = entries.map((e) => e.asset).toList();
    expect(assets, [...assets]..sort());
    expect(entries.first.lesson!.id, 'basics_01');
  });
}
