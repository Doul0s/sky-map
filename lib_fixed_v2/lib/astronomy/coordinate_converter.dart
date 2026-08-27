import 'dart:math' as math;

import '../models/celestial_position.dart';
import '../models/sky_star.dart';

class CoordinateConverter {
  static CelestialPosition starToHorizontal({
    required SkyStar star,
    required double latitude,
    required double longitude,
    required DateTime utc,
  }) {
    return equatorialToHorizontal(
      ra: star.ra,
      dec: star.dec,
      latitude: latitude,
      longitude: longitude,
      utc: utc,
    );
  }

  /// Converts equatorial coordinates (RA/Dec) to horizontal
  /// coordinates (Azimuth/Altitude) for an observer.
  ///
  /// RA:
  ///   degrees, 0 <= RA < 360
  ///
  /// Dec:
  ///   degrees, -90 <= Dec <= 90
  ///
  /// Latitude:
  ///   observer latitude in degrees
  ///
  /// Longitude:
  ///   observer longitude in degrees
  ///
  /// Azimuth convention:
  ///   0   = North
  ///   90  = East
  ///   180 = South
  ///   270 = West
  static CelestialPosition equatorialToHorizontal({
    required double ra,
    required double dec,
    required double latitude,
    required double longitude,
    required DateTime utc,
  }) {
    final lst = _localSiderealTime(
      longitude: longitude,
      utc: utc,
    );

    var hourAngle = lst - ra;

    while (hourAngle < 0) {
      hourAngle += 360.0;
    }

    while (hourAngle >= 360.0) {
      hourAngle -= 360.0;
    }

    final h = _radians(hourAngle);
    final declination = _radians(dec);
    final lat = _radians(latitude);

    /*
     * Altitude:
     *
     * sin(h_alt) =
     *   sin(dec) sin(lat)
     *   +
     *   cos(dec) cos(lat) cos(H)
     */
    final sinAltitude =
        math.sin(declination) *
            math.sin(lat) +
        math.cos(declination) *
            math.cos(lat) *
            math.cos(h);

    final altitude = math.asin(
      sinAltitude.clamp(-1.0, 1.0),
    );

    /*
     * Azimuth:
     *
     * 0   = North
     * 90  = East
     * 180 = South
     * 270 = West
     */
    final y = math.sin(h);

    final x =
        math.cos(h) *
            math.sin(lat) -
        math.tan(declination) *
            math.cos(lat);

    var azimuth = math.atan2(y, x);

    azimuth += math.pi;

    var azimuthDegrees =
        _degrees(azimuth);

    azimuthDegrees %= 360.0;

    if (azimuthDegrees < 0) {
      azimuthDegrees += 360.0;
    }

    return CelestialPosition(
      azimuth: azimuthDegrees,
      altitude: _degrees(altitude),
    );
  }

  static double _localSiderealTime({
    required double longitude,
    required DateTime utc,
  }) {
    final jd = _julianDate(utc);

    final d = jd - 2451545.0;

    var gmst =
        280.46061837 +
        360.98564736629 * d;

    gmst %= 360.0;

    if (gmst < 0) {
      gmst += 360.0;
    }

    var lst = gmst + longitude;

    lst %= 360.0;

    if (lst < 0) {
      lst += 360.0;
    }

    return lst;
  }

  static double _julianDate(DateTime utc) {
    return utc.millisecondsSinceEpoch /
            86400000.0 +
        2440587.5;
  }

  static double _radians(double degrees) {
    return degrees *
        math.pi /
        180.0;
  }

  static double _degrees(double radians) {
    return radians *
        180.0 /
        math.pi;
  }
}