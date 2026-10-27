import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/ui/app_icon.dart';

void main() {
  testWidgets('icon art paints at any size', (tester) async {
    for (final size in [48.0, 192.0]) {
      await tester.pumpWidget(Center(child: AppIconArt(size: size)));
      expect(tester.getSize(find.byType(AppIconArt)), Size.square(size));
    }
  });
}
