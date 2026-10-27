import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../engine/lesson_playback.dart';
import '../engine/metronome_scheduler.dart';
import '../engine/song_clock.dart';
import '../music/lesson.dart';
import 'components.dart';
import 'layout.dart';

abstract final class Overlays {
  static const hud = 'hud';
  static const menu = 'menu';
  static const finished = 'finished';
}

/// Lesson scene. All motion is derived from [playback] time each frame, so
/// pausing and seeking need no special handling in components.
class LessonGame extends FlameGame {
  LessonGame({required this.lesson, this.metronome, TimeSource? now})
    : playback = LessonPlayback(lesson, clock: SongClock(now: now)),
      super(
        camera: CameraComponent.withFixedResolution(
          width: SceneLayout.width,
          height: SceneLayout.height,
        ),
      ) {
    _scheduler = MetronomeScheduler(
      playback.grid,
      lastIndex: playback.lastBeatIndex,
    );
  }

  final Lesson lesson;
  final LessonPlayback playback;
  final MetronomeSink? metronome;
  late final MetronomeScheduler _scheduler;

  /// For overlays; updated from [update].
  final progress = ValueNotifier<double>(0);
  final phase = ValueNotifier<PlaybackPhase>(PlaybackPhase.ready);

  late final List<NoteComponent> notes;
  late final CountInComponent _countIn;

  /// Notes stay "current" this long after their start, seconds.
  static const currentWindow = 0.12;

  @override
  Color backgroundColor() => const Color(0xFF121010);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    notes = [
      for (final n in lesson.notes)
        NoteComponent(
          note: n,
          time: lesson.noteTime(n),
          length: lesson.noteDuration(n),
        ),
    ];
    _countIn = CountInComponent();
    world.addAll([
      TabHighwayComponent(),
      ...notes.reversed, // earlier notes drawn on top of later tails
      HitLineComponent(),
      _countIn,
      if (kDebugMode)
        FpsTextComponent(
          anchor: Anchor.bottomRight,
          position: Vector2(SceneLayout.width - 12, SceneLayout.height - 8),
        ),
    ]);
    _layout();
  }

  void start() {
    playback.start();
    _syncMetronome();
    _refreshOverlays();
  }

  void pause() {
    playback.pause();
    metronome?.cancelPending();
    _refreshOverlays();
  }

  void resume() {
    playback.resume();
    _syncMetronome();
    _refreshOverlays();
  }

  void setSpeed(double speed) {
    playback.speed = speed;
    if (playback.phase case PlaybackPhase.countIn || PlaybackPhase.playing) {
      _syncMetronome();
    }
    _refreshOverlays();
  }

  void _syncMetronome() {
    final m = metronome;
    if (m == null) return;
    m.cancelPending();
    m.anchor(playback.time, playback.speed);
    _scheduler.reset(playback.time);
    // Beats due right now must not wait for the next frame.
    _scheduler.due(playback.time).forEach(m.schedule);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (playback.checkFinished()) {
      metronome?.cancelPending();
      _refreshOverlays();
    }
    final running = switch (playback.phase) {
      PlaybackPhase.countIn || PlaybackPhase.playing => true,
      _ => false,
    };
    if (running && metronome != null) {
      for (final beat in _scheduler.due(playback.time)) {
        metronome!.schedule(beat);
      }
    }
    _layout();
  }

  /// Positions notes and the count-in from the current song time.
  void _layout() {
    final t = playback.time;
    var currentFound = false;
    for (final n in notes) {
      n.position.x = SceneLayout.timeToX(n.time, t);
      if (n.time + currentWindow < t) {
        n.state = NoteState.passed;
      } else if (!currentFound) {
        n.state = NoteState.current;
        currentFound = true;
      } else {
        n.state = NoteState.upcoming;
      }
    }
    _countIn.show(playback.countInBeat);
    progress.value = playback.progress;
    phase.value = playback.phase;
  }

  void _refreshOverlays() {
    phase.value = playback.phase;
    final showMenu = switch (playback.phase) {
      PlaybackPhase.ready || PlaybackPhase.paused => true,
      _ => false,
    };
    if (showMenu) {
      overlays.add(Overlays.menu);
    } else {
      overlays.remove(Overlays.menu);
    }
    if (playback.phase == PlaybackPhase.finished) {
      overlays.add(Overlays.finished);
    } else {
      overlays.remove(Overlays.finished);
    }
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    super.lifecycleStateChange(state);
    if (state != AppLifecycleState.resumed) pause();
  }

  @override
  void onRemove() {
    metronome?.cancelPending();
    super.onRemove();
  }
}
