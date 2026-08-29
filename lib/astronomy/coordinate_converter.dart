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
  ///   observer geodetic latitude in degrees
  ///
  /// Longitude:
  ///   observer longitude in degrees
  ///
  /// [distanceKm] and [altitudeMeters]:
  ///
  /// When [distanceKm] is provided and positive, topocentric parallax
  /// correction is applied before converting to Alt/Az.
  ///
  /// This is especially important for the Moon, whose horizontal
  /// parallax can approach approximately 1 degree.
  ///
  /// The observer is modelled using the WGS84 Earth ellipsoid rather
  /// than treating the Earth as a perfect sphere.
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
    double? distanceKm,
    double altitudeMeters = 0,
  }) {
    final lst = _localSiderealTime(
      longitude: longitude,
      utc: utc,
    );

    var effectiveRa = ra;
    var effectiveDec = dec;

    if (distanceKm != null && distanceKm > 0) {
      /*
       * Topocentric correction must use the GEOCENTRIC hour angle.
       *
       * Do not calculate this using effectiveRa because effectiveRa is
       * the quantity we are trying to determine.
       */
      final geocentricHourAngle = _radians(
        _signedAngleDifference(lst, ra),
      );

      final corrected = _applyTopocentricParallax(
        raDegrees: ra,
        decDegrees: dec,
        distanceKm: distanceKm,
        latitudeDegrees: latitude,
        altitudeMeters: altitudeMeters,
        geocentricHourAngle: geocentricHourAngle,
      );

      effectiveRa = _normalizeDegrees(corrected.$1);
      effectiveDec = corrected.$2;
    }

    /*
     * Hour angle of the topocentric position.
     */
    final hourAngle = _radians(
      _signedAngleDifference(lst, effectiveRa),
    );

    final declination = _radians(effectiveDec);
    final lat = _radians(latitude);

    /*
     * Altitude:
     *
     * sin(h) =
     *   sin(dec) sin(phi)
     *   +
     *   cos(dec) cos(phi) cos(H)
     *
     * where:
     *
     *   h   = altitude
     *   dec = declination
     *   phi = observer latitude
     *   H   = hour angle
     */
    final sinAltitude =
        math.sin(declination) * math.sin(lat) +
        math.cos(declination) *
            math.cos(lat) *
            math.cos(hourAngle);

    final altitude = math.asin(
      sinAltitude.clamp(-1.0, 1.0),
    );

    /*
     * Azimuth:
     *
     * atan2(
     *   sin(H),
     *   cos(H) sin(phi) - tan(dec) cos(phi)
     * )
     *
     * The +180 degree shift converts the mathematical atan2 orientation
     * into the application's convention:
     *
     *   0   = North
     *   90  = East
     *   180 = South
     *   270 = West
     */
    final y = math.sin(hourAngle);

    final x =
        math.cos(hourAngle) * math.sin(lat) -
        math.tan(declination) * math.cos(lat);

    var azimuth = math.atan2(y, x) + math.pi;

    var azimuthDegrees = _degrees(azimuth);
    azimuthDegrees %= 360.0;

    if (azimuthDegrees < 0.0) {
      azimuthDegrees += 360.0;
    }

    return CelestialPosition(
      azimuth: azimuthDegrees,
      altitude: _degrees(altitude),
    );
  }

  /// Applies topocentric parallax correction using the standard
  /// geocentric observer formulation.
  ///
  /// This follows the method commonly presented in Meeus,
  /// Astronomical Algorithms, for converting a geocentric equatorial
  /// position into a topocentric equatorial position.
  ///
  /// The important difference from the previous implementation is that
  /// the observer is no longer treated as if they were simply:
  ///
  ///   EarthRadius + altitude
  ///
  /// from the Earth's centre.
  ///
  /// Earth is oblate, therefore observer distance from the Earth's
  /// rotation axis and equatorial plane depends on latitude.
  ///
  /// We calculate:
  ///
  ///   u = atan(0.99664719 tan(phi))
  ///
  ///   rhoSinPhi' =
  ///       0.99664719 sin(u)
  ///       + (h / a) sin(phi)
  ///
  ///   rhoCosPhi' =
  ///       cos(u)
  ///       + (h / a) cos(phi)
  ///
  /// where:
  ///
  ///   phi = geodetic latitude
  ///   h   = observer altitude
  ///   a   = WGS84 equatorial radius
  ///
  /// The equatorial horizontal parallax is:
  ///
  ///   sin(pi) = a / Delta
  ///
  /// where Delta is the geocentric distance to the object.
  ///
  /// For the Moon this correction is significant because lunar
  /// horizontal parallax is approximately 0.9 degrees on average.
  static (double, double) _applyTopocentricParallax({
    required double raDegrees,
    required double decDegrees,
    required double distanceKm,
    required double latitudeDegrees,
    required double altitudeMeters,
    required double geocentricHourAngle,
  }) {
    /*
     * WGS84 semi-major axis.
     *
     * This is the Earth's equatorial radius.
     */
    const earthEquatorialRadiusKm = 6378.137;

    /*
     * WGS84 flattening.
     *
     * The quantity used by the classical Meeus observer equations is
     * approximately:
     *
     *   f = 1 / 298.257223563
     *
     * and:
     *
     *   1 - f = 0.99664719
     */
    const rhoFactor = 0.99664719;

    final phi = _radians(latitudeDegrees);
    final dec = _radians(decDegrees);
    final h = geocentricHourAngle;

    /*
     * Observer height in kilometres.
     */
    final altitudeKm = altitudeMeters / 1000.0;

    /*
     * Auxiliary geocentric latitude.
     *
     * u = atan(factor * tan(phi))
     */
    final u = math.atan(
      rhoFactor * math.tan(phi),
    );

    /*
     * Observer's normalized geocentric coordinates.
     *
     * These are dimensionless ratios relative to Earth's equatorial
     * radius.
     */
    final rhoSinPhiPrime =
        rhoFactor * math.sin(u) +
        (altitudeKm / earthEquatorialRadiusKm) *
            math.sin(phi);

    final rhoCosPhiPrime =
        math.cos(u) +
        (altitudeKm / earthEquatorialRadiusKm) *
            math.cos(phi);

    /*
     * Equatorial horizontal parallax.
     *
     * sin(pi) = a / Delta
     */
    final sinHorizontalParallax = (
      earthEquatorialRadiusKm / distanceKm
    ).clamp(0.0, 1.0);

    /*
     * Delta-alpha:
     *
     * tan(Delta-alpha) =
     *   -rhoCos(phi') sin(pi) sin(H)
     *
     *   /
     *
     *   cos(dec)
     *   - rhoCos(phi') sin(pi) cos(H)
     */
    final numeratorRa =
        -rhoCosPhiPrime *
        sinHorizontalParallax *
        math.sin(h);

    final denominatorRa =
        math.cos(dec) -
        rhoCosPhiPrime *
            sinHorizontalParallax *
            math.cos(h);

    final deltaRa = math.atan2(
      numeratorRa,
      denominatorRa,
    );

    /*
     * Topocentric declination:
     *
     * tan(dec') =
     *
     * [sin(dec) - rhoSin(phi') sin(pi)]
     * cos(Delta-alpha)
     *
     * /
     *
     * [cos(dec)
     *  - rhoCos(phi') sin(pi) cos(H)]
     */
    final numeratorDec =
        (
          math.sin(dec) -
          rhoSinPhiPrime *
              sinHorizontalParallax
        ) *
        math.cos(deltaRa);

    final denominatorDec =
        math.cos(dec) -
        rhoCosPhiPrime *
            sinHorizontalParallax *
            math.cos(h);

    final correctedDec = math.atan2(
      numeratorDec,
      denominatorDec,
    );

    return (
      _normalizeDegrees(
        raDegrees + _degrees(deltaRa),
      ),
      _degrees(correctedDec),
    );
  }

  /// Returns the signed angular difference a-b in degrees in [-180, 180).
  static double _signedAngleDifference(
    double a,
    double b,
  ) {
    var difference = (a - b) % 360.0;

    if (difference >= 180.0) {
      difference -= 360.0;
    }

    if (difference < -180.0) {
      difference += 360.0;
    }

    return difference;
  }

  static double _normalizeDegrees(double degrees) {
    var value = degrees % 360.0;

    if (value < 0.0) {
      value += 360.0;
    }

    return value;
  }

  /// Computes local sidereal time in degrees.
  ///
  /// Greenwich mean sidereal time is calculated from Julian Date and
  /// longitude is then added to obtain local sidereal time.
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

    if (gmst < 0.0) {
      gmst += 360.0;
    }

    var lst = gmst + longitude;

    lst %= 360.0;

    if (lst < 0.0) {
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
    return degrees * math.pi / 180.0;
  }

  static double _degrees(double radians) {
    return radians * 180.0 / math.pi;
  }
}