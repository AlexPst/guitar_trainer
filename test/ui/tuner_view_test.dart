import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_trainer/music/pitch.dart';
import 'package:guitar_trainer/music/tuner_reading.dart';
import 'package:guitar_trainer/ui/tuner_screen.dart';

Widget host(TunerReading? r) => MaterialApp(
  home: Scaffold(body: TunerView(reading: r)),
);

void main() {
  testWidgets('no reading asks to play a string', (tester) async {
    await tester.pumpWidget(host(null));
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Сыграйте открытую струну'), findsOneWidget);
  });

  testWidgets('in-tune A string', (tester) async {
    await tester.pumpWidget(host(TunerReading(midiToFrequency(45.02))));
    expect(find.text('A2'), findsOneWidget);
    expect(find.textContaining('5 струна (A2)'), findsOneWidget);
    expect(find.text('В строю'), findsOneWidget);
  });

  testWidgets('sharp G string shows cents', (tester) async {
    await tester.pumpWidget(host(TunerReading(midiToFrequency(55.2))));
    expect(find.text('G3'), findsOneWidget);
    expect(find.text('+20 центов'), findsOneWidget);
  });
}
