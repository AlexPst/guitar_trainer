import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../engine/lesson_playback.dart';
import '../engine/lesson_result.dart';
import '../engine/metronome_scheduler.dart';
import '../engine/note_event.dart';
import '../engine/note_result.dart';
import '../engine/score_keeper.dart';
import '../engine/song_clock.dart';
import '../engine/tempo_scorer.dart';
import '../engine/wait_mode.dart';
import '../music/lesson.dart';
import '../music/pitch.dart';
import 'components.dart';
import 'feedback.dart';
import 'layout.dart';

abstract final class Overlays {
  static const hud = 'hud';
  static const menu = 'menu';
}

enum LessonMode {
  /// Notes move with the metronome; timing is judged.
  tempo,

  /// The song stops on each note until it is played; no score.
  wait,
}

/// Lesson scene. All motion is derived from [playback] time each frame, so
/// pausing and seeking need no special handling in components.
///
/// Heard notes come in through [addNoteEvents]; judging is done by the pure
/// Dart engine ([TempoScorer] or [WaitModeSession]).
class LessonGame extends FlameGame {
  LessonGame({
    required this.lesson,
    this.metronome,
    TimeSource? now,
    this.calibrationOffset = 0,
    this.hitWindow = 0.12,
    this.leftHanded = false,
    LessonMode mode = LessonMode.tempo,
    double speed = 1,
  }) : playback = LessonPlayback(lesson, clock: SongClock(now: now)),
       modeNotifier = ValueNotifier(mode),
       super(
         camera: CameraComponent.withFixedResolution(
           width: SceneLayout.width,
           height: SceneLayout.height,
         ),
       ) {
    playback.speed = speed;
    _scheduler = _newScheduler();
  }

  final Lesson lesson;
  final LessonPlayback playback;
  final MetronomeSink? metronome;

  /// Input latency, seconds; see [TempoScorer.calibrationOffset].
  final double calibrationOffset;

  /// See [TempoScorer.hitWindow].
  final double hitWindow;

  /// Mirrored layout: hit line on the right, notes moving left to right.
  final bool leftHanded;

  /// X of the hit line in the current layout.
  double get hitX =>
      leftHanded ? SceneLayout.width - SceneLayout.hitX : SceneLayout.hitX;

  /// Screen X of something happening at [eventTime] (lesson seconds).
  double xAt(double eventTime) {
    final x = SceneLayout.timeToX(eventTime, playback.time);
    return leftHanded ? SceneLayout.width - x : x;
  }

  /// Analysis delay of heard notes; see [TempoScorer.inputLag].
  double inputLag = 0;

  final ValueNotifier<LessonMode> modeNotifier;
  LessonMode get mode => modeNotifier.value;

  late MetronomeScheduler _scheduler;
  TempoScorer? _scorer;
  WaitModeSession? _wait;
  final scoreKeeper = ScoreKeeper();
  late List<NoteResult?> _noteResults = List.filled(lesson.notes.length, null);

  /// For overlays; updated from [update] and [addNoteEvents].
  final progress = ValueNotifier<double>(0);
  final phase = ValueNotifier<PlaybackPhase>(PlaybackPhase.ready);
  final score = ValueNotifier<int>(0);
  final combo = ValueNotifier<int>(0);

  /// Name of the note currently heard, e.g. "A2", or null.
  final heard = ValueNotifier<String?>(null);
  double _heardAge = 0;

  late final List<NoteComponent> notes;
  late final CountInComponent _countIn;

  /// Notes stay "current" this long after their start, seconds.
  static const currentWindow = 0.12;

  /// How long the heard note stays shown after the last pitched frame.
  static const heardHold = 0.4;

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
          mirrored: leftHanded,
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

  // In wait mode the metronome only counts in.
  MetronomeScheduler _newScheduler() => MetronomeScheduler(
    playback.grid,
    lastIndex: mode == LessonMode.wait ? -1 : playback.lastBeatIndex,
  );

  void setMode(LessonMode value) {
    if (playback.phase != PlaybackPhase.ready) return;
    modeNotifier.value = value;
    _refreshOverlays();
  }

  void start() {
    for (final n in notes) {
      n.judgement = null;
    }
    _noteResults = List.filled(lesson.notes.length, null);
    scoreKeeper.reset();
    score.value = 0;
    combo.value = 0;
    _scheduler = _newScheduler();
    playback.start();
    _scorer = mode == LessonMode.tempo
        ? TempoScorer(
            lesson,
            speed: playback.speed,
            calibrationOffset: calibrationOffset,
            inputLag: inputLag,
            hitWindow: hitWindow,
          )
        : null;
    _wait = mode == LessonMode.wait
        ? WaitModeSession(lesson, playback.clock)
        : null;
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
    _scorer?.speed = playback.speed;
    if (_isRunning) _syncMetronome();
    _refreshOverlays();
  }

  bool get _isRunning => switch (playback.phase) {
    PlaybackPhase.countIn || PlaybackPhase.playing => true,
    _ => false,
  };

  void _syncMetronome() {
    final m = metronome;
    if (m == null) return;
    m.cancelPending();
    m.anchor(playback.time, playback.speed);
    _scheduler.reset(playback.time);
    // Beats due right now must not wait for the next frame.
    _scheduler.due(playback.time).forEach(m.schedule);
  }

  /// Heard notes from the microphone, in song time and time order.
  void addNoteEvents(List<NoteEvent> events) {
    for (final e in events) {
      final f = e.frequency;
      if (f != null) {
        heard.value = NoteReading.fromFrequency(f).name;
        _heardAge = 0;
      }
      if (!_isRunning) continue;
      final scorer = _scorer;
      if (scorer != null) {
        scorer.addEvent(e).forEach(_apply);
      }
      final r = _wait?.addEvent(e);
      if (r != null) _apply(r);
    }
  }

  void _apply(NoteResult r) {
    final note = notes[r.noteIndex];
    note.judgement = r.judgement;
    _noteResults[r.noteIndex] = r;
    scoreKeeper.add(r);
    score.value = scoreKeeper.score;
    combo.value = scoreKeeper.combo;

    final at = Vector2(hitX, note.position.y);
    final color = judgementColor(r.judgement);
    if (r.judgement.isPlayed) world.add(hitBurst(at, color));
    final label = judgementLabel(r.judgement);
    if (label != null) {
      world.add(
        FeedbackText(label, at - Vector2(0, SceneLayout.noteRadius), color),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _heardAge += dt;
    if (_heardAge > heardHold) heard.value = null;

    if (_isRunning) {
      _wait?.update();
      _scorer?.advance(playback.time).forEach(_apply);
    }
    if (playback.checkFinished()) {
      metronome?.cancelPending();
      // Notes still open when the song ends were not played.
      _scorer?.advance(double.infinity).forEach(_apply);
      _refreshOverlays();
    }
    if (_isRunning && metronome != null) {
      _scheduler.due(playback.time).forEach(metronome!.schedule);
    }
    _layout();
  }

  /// Positions notes and the count-in from the current song time.
  void _layout() {
    final t = playback.time;
    final waitIndex = _wait?.currentIndex;
    var currentFound = false;
    for (var i = 0; i < notes.length; i++) {
      final n = notes[i];
      n.position.x = xAt(n.time);
      final isCurrent = waitIndex != null
          ? i == waitIndex
          : !currentFound && n.time + currentWindow >= t;
      if (isCurrent) {
        n.state = NoteState.current;
        currentFound = true;
      } else if (n.time + currentWindow < t ||
          (waitIndex != null && i < waitIndex)) {
        n.state = NoteState.passed;
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
  }

  /// Outcome of the current run; meaningful once [phase] is finished.
  LessonResult result() => LessonResult.fromNotes(
    lesson,
    _noteResults,
    scored: mode == LessonMode.tempo,
    maxCombo: scoreKeeper.maxCombo,
  );

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
