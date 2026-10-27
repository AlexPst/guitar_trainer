// Renders AppIconArt to launcher PNGs. Not part of the normal test run:
//   flutter test tool/generate_icons_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/ui/app_icon.dart';

/// Legacy square icons (Android < 8) and the Linux window icon.
const outputs = {
  'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
  'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
  'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
  'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
  'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  'assets/icon/icon.png': 256,
};

/// Adaptive icon foregrounds (108 dp canvas) for Android 8+.
const foregrounds = {
  'android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png': 108,
  'android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png': 162,
  'android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png': 216,
  'android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png': 324,
  'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png': 432,
};

Future<void> render(
  WidgetTester tester,
  Widget art,
  Map<String, int> files,
) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Center(
      child: RepaintBoundary(key: key, child: art),
    ),
  );
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  for (final MapEntry(key: path, value: px) in files.entries) {
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: px / 256);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
    });
  }
}

void main() {
  testWidgets('generate launcher icons', (tester) async {
    await render(tester, const AppIconArt(size: 256), outputs);
    await render(
      tester,
      const AppIconArt(size: 256, foregroundOnly: true),
      foregrounds,
    );
  });
}
