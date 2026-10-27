import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/painting.dart';

import '../engine/note_result.dart';
import '../music/lesson.dart';
import 'feedback.dart';
import 'layout.dart';
import 'lesson_game.dart';

/// Six strings, bar lines and beat ticks scrolling with the song.
class TabHighwayComponent extends Component with HasGameReference<LessonGame> {
  final _background = Paint()..color = const Color(0xFF1E1A18);
  final _barLine = Paint()
    ..color = const Color(0x66FFFFFF)
    ..strokeWidth = 2;
  final _beatLine = Paint()
    ..color = const Color(0x22FFFFFF)
    ..strokeWidth = 1;
  late final List<Paint> _strings = [
    for (var s = 1; s <= SceneLayout.stringCount; s++)
      Paint()
        ..color = const Color(0xFFB8A99A)
        ..strokeWidth = 1 + s * 0.5,
  ];

  @override
  void render(Canvas canvas) {
    const top = SceneLayout.highwayTop;
    const bottom = SceneLayout.highwayBottom;
    canvas.drawRect(
      const Rect.fromLTRB(0, top, SceneLayout.width, bottom),
      _background,
    );

    final grid = game.playback.grid;
    final t = game.playback.time;
    // Whole screen width either side covers both normal and mirrored layout.
    const span = SceneLayout.width / SceneLayout.pixelsPerSecond;
    final first = ((t - span) / grid.secondsPerBeat).floor();
    final last = ((t + span) / grid.secondsPerBeat).ceil();
    for (var i = first; i <= last; i++) {
      if (i < 0) continue; // no grid during the count-in
      final x = game.xAt(i * grid.secondsPerBeat);
      final isBar = i % grid.beatsPerBar == 0;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        isBar ? _barLine : _beatLine,
      );
    }

    for (var s = 1; s <= SceneLayout.stringCount; s++) {
      final y = SceneLayout.stringY(s);
      canvas.drawLine(
        Offset(0, y),
        Offset(SceneLayout.width, y),
        _strings[s - 1],
      );
    }
  }
}

class HitLineComponent extends Component with HasGameReference<LessonGame> {
  final _glow = Paint()
    ..color = const Color(0x33FFC107)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  final _line = Paint()
    ..color = Colors.amber
    ..strokeWidth = 4;

  @override
  void render(Canvas canvas) {
    final x = game.hitX;
    canvas.drawRect(
      Rect.fromLTRB(
        x - 12,
        SceneLayout.highwayTop,
        x + 12,
        SceneLayout.highwayBottom,
      ),
      _glow,
    );
    canvas.drawLine(
      Offset(x, SceneLayout.highwayTop - 10),
      Offset(x, SceneLayout.highwayBottom + 10),
      _line,
    );
  }
}

enum NoteState { upcoming, current, passed }

/// A fret number on a string, with a tail showing its duration.
class NoteComponent extends PositionComponent {
  NoteComponent({
    required this.note,
    required this.time,
    required this.length,
    this.mirrored = false,
  }) : super(
         anchor: Anchor.center,
         size: Vector2.all(SceneLayout.noteRadius * 2),
         position: Vector2(0, SceneLayout.stringY(note.string)),
       );

  final TabNote note;

  /// Start and length in lesson seconds.
  final double time;
  final double length;

  /// Left-handed layout: the duration tail points left.
  final bool mirrored;

  NoteState state = NoteState.upcoming;

  /// Set once the note is judged; overrides [state] colours.
  Judgement? judgement;

  static final _fills = {
    NoteState.upcoming: Paint()..color = const Color(0xFFE5602B),
    NoteState.current: Paint()..color = const Color(0xFFFFC107),
    NoteState.passed: Paint()..color = const Color(0xFF6B625D),
  };
  static final _tails = {
    for (final e in _fills.entries)
      e.key: Paint()..color = e.value.color.withAlpha(90),
  };
  static final _judged = {
    for (final j in Judgement.values) j: Paint()..color = judgementColor(j),
  };
  static final _judgedTails = {
    for (final j in Judgement.values)
      j: Paint()..color = judgementColor(j).withAlpha(90),
  };
  static final _ring = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  late final TextComponent _label;

  @override
  Future<void> onLoad() async {
    _label = TextComponent(
      text: '${note.fret}',
      anchor: Anchor.center,
      position: size / 2,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(_label);
  }

  @override
  void render(Canvas canvas) {
    const r = SceneLayout.noteRadius;
    final tail = length * SceneLayout.pixelsPerSecond;
    canvas.drawRRect(
      mirrored
          ? RRect.fromLTRBR(r - tail, r - 7, r, r + 7, const Radius.circular(7))
          : RRect.fromLTRBR(
              r,
              r - 7,
              r + tail,
              r + 7,
              const Radius.circular(7),
            ),
      judgement == null ? _tails[state]! : _judgedTails[judgement]!,
    );
    canvas.drawCircle(
      const Offset(r, r),
      r,
      judgement == null ? _fills[state]! : _judged[judgement]!,
    );
    if (judgement == null && state == NoteState.current) {
      canvas.drawCircle(const Offset(r, r), r + 3, _ring);
    }
  }
}

/// Big "1 2 3 4" in the middle of the screen during the count-in.
class CountInComponent extends TextComponent {
  CountInComponent()
    : super(
        anchor: Anchor.center,
        position: Vector2(SceneLayout.width / 2, SceneLayout.height / 2),
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 160,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(blurRadius: 24)],
          ),
        ),
      );

  int? _shown;

  void show(int? beat) {
    if (beat == _shown) return;
    _shown = beat;
    text = beat == null ? '' : '$beat';
  }
}
