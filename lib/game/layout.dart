/// Geometry of the lesson scene in world units (fixed 1280x720 viewport).
abstract final class SceneLayout {
  static const width = 1280.0;
  static const height = 720.0;

  /// X of the hit line; notes are played when they reach it.
  static const hitX = 220.0;

  /// Horizontal scroll speed in pixels per second of lesson time.
  static const pixelsPerSecond = 260.0;

  static const highwayTop = 170.0;
  static const highwayBottom = 610.0;
  static const stringCount = 6;

  /// Y of [string] 1 (top, thinnest) .. 6 (bottom, thickest), as in tablature.
  static double stringY(int string) {
    const pad = 36.0;
    const span = highwayBottom - highwayTop - 2 * pad;
    return highwayTop + pad + (string - 1) * span / (stringCount - 1);
  }

  /// Screen X of something at [eventTime] when the song is at [songTime].
  static double timeToX(double eventTime, double songTime) =>
      hitX + (eventTime - songTime) * pixelsPerSecond;

  static const noteRadius = 26.0;
}
