import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

import '../engine/note_result.dart';

final _rnd = math.Random();

Color judgementColor(Judgement j) => switch (j) {
  Judgement.hit => const Color(0xFF4CAF50),
  Judgement.early || Judgement.late => const Color(0xFF8BC34A),
  Judgement.octave => const Color(0xFF42A5F5),
  Judgement.wrongPitch => const Color(0xFFE53935),
  Judgement.miss => const Color(0xFF4A3B38),
};

String? judgementLabel(Judgement j) => switch (j) {
  Judgement.early => 'Рано',
  Judgement.late => 'Поздно',
  Judgement.octave => 'Октава',
  Judgement.wrongPitch => 'Не та нота',
  Judgement.hit || Judgement.miss => null,
};

/// Burst of sparks where a note was hit.
ParticleSystemComponent hitBurst(Vector2 at, Color color) {
  final paint = Paint()..color = color;
  return ParticleSystemComponent(
    position: at,
    particle: Particle.generate(
      count: 18,
      lifespan: 0.45,
      generator: (_) {
        final angle = _rnd.nextDouble() * 2 * math.pi;
        final speed = 120 + _rnd.nextDouble() * 220;
        return AcceleratedParticle(
          speed: Vector2(math.cos(angle), math.sin(angle)) * speed,
          acceleration: Vector2(0, 400),
          child: CircleParticle(
            radius: 3 + _rnd.nextDouble() * 2,
            paint: paint,
          ),
        );
      },
    ),
  );
}

/// Short label ("Рано", "Поздно", ...) floating up from the hit line.
class FeedbackText extends TextComponent {
  FeedbackText(String text, Vector2 at, Color color)
    : super(
        text: text,
        position: at,
        anchor: Anchor.bottomCenter,
        textRenderer: TextPaint(
          style: TextStyle(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(blurRadius: 6)],
          ),
        ),
      );

  @override
  Future<void> onLoad() async {
    add(MoveByEffect(Vector2(0, -50), EffectController(duration: 0.6)));
    add(RemoveEffect(delay: 0.7));
  }
}
