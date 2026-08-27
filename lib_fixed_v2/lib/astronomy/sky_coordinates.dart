import 'dart:math' as math;

class SkyCoordinates {
  static List<double> horizontalToVector({
    required double azimuth,
    required double altitude,
  }) {
    final az =
        azimuth * math.pi / 180.0;

    final alt =
        altitude * math.pi / 180.0;

    final cosAltitude = math.cos(alt);

    /*
     * World coordinate system:
     *
     * X = North
     * Y = East
     * Z = Up
     */
    return [
      cosAltitude * math.cos(az),
      cosAltitude * math.sin(az),
      math.sin(alt),
    ];
  }
}