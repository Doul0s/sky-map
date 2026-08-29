import 'dart:math' as math;

import 'celestial_calculator.dart';
import 'sun_calculator.dart';

/// Intermediate result shared between [MoonCalculator.calculate] and
/// [MoonCalculator.phaseFacts].
class _MoonPosition {
  final double ra;
  final double dec;
  final double distanceKm;

  /// True geocentric ecliptic longitude of the Moon, degrees [0, 360).
  ///
  /// This is retained because it is useful when determining the lunar
  /// phase direction (waxing versus waning).
  final double eclipticLongitudeDegrees;

  const _MoonPosition({
    required this.ra,
    required this.dec,
    required this.distanceKm,
    required this.eclipticLongitudeDegrees,
  });
}

/// Calculates the Moon's geocentric equatorial position using a reduced
/// lunar periodic-term model.
///
/// The model contains the dominant longitude, latitude and distance terms
/// from the classical lunar theory described by Meeus.
///
/// It is deliberately reduced rather than implementing the complete
/// ELP/DE ephemeris. That provides a good balance between:
///
///   - positional accuracy,
///   - realistic lunar motion,
///   - distance/parallax behaviour,
///   - and mobile-device computation cost.
///
/// The result is intended for a visual sky map, not precision astronomy.
///
/// The calculator returns:
///
///   RA         right ascension in degrees [0, 360)
///   Dec        declination in degrees [-90, +90]
///   distanceKm geocentric Earth-Moon distance
class MoonCalculator implements CelestialCalculator {
  const MoonCalculator();

  /// Moon position at one instant.
  @override
  (double ra, double dec, double? distanceKm) calculate(
    DateTime utc,
  ) {
    final position = _computePosition(utc);

    return (
      position.ra,
      position.dec,
      position.distanceKm,
    );
  }

  /// Returns live lunar phase information.
  ///
  /// Illuminated fraction:
  ///
  ///   k = (1 - cos(E)) / 2
  ///
  /// where E is the geocentric angular separation between the Sun
  /// and Moon.
  ///
  /// Phase direction is determined from:
  ///
  ///   lambdaMoon - lambdaSun
  ///
  /// so that waxing and waning phases are distinguished correctly.
  List<MapEntry<String, String>> phaseFacts(
    DateTime utc,
  ) {
    final moon = _computePosition(utc);

    final (
      sunRa,
      sunDec,
      _,
    ) = const SunCalculator().calculate(utc);

    final moonDec = _radians(moon.dec);
    final sunDecRad = _radians(sunDec);

    final deltaRa = _radians(
      _signedAngleDifference(
        moon.ra,
        sunRa,
      ),
    );

    final cosElongation =
        math.sin(moonDec) * math.sin(sunDecRad) +
        math.cos(moonDec) *
            math.cos(sunDecRad) *
            math.cos(deltaRa);

    final elongation = math.acos(
      cosElongation.clamp(-1.0, 1.0),
    );

    final illuminatedFraction =
        (1.0 - math.cos(elongation)) / 2.0;

    final t = _centuriesSinceJ2000(utc);

    final sunEclipticLongitude =
        _equatorialToEclipticLongitude(
      raDegrees: sunRa,
      decDegrees: sunDec,
      t: t,
    );

    final phaseAngle = _normalize(
      moon.eclipticLongitudeDegrees -
          sunEclipticLongitude,
    );

    return [
      MapEntry(
        'Phase',
        _phaseName(phaseAngle),
      ),
      MapEntry(
        'Illuminated',
        '${(illuminatedFraction * 100.0).toStringAsFixed(1)}%',
      ),
    ];
  }

  /// Generates the Moon's apparent sky trajectory.
  ///
  /// Important:
  ///
  /// The trajectory is NOT the physical lunar orbit.
  ///
  /// It represents the apparent direction of the Moon in the observer's
  /// sky as time passes.
  ///
  /// The Moon requires finer sampling than the Sun because:
  ///
  ///   1. the Moon moves roughly 13 degrees eastward per day,
  ///   2. its declination can change appreciably,
  ///   3. its distance changes,
  ///   4. and therefore its topocentric parallax changes as well.
  ///
  /// A 30-minute sample is already usable, but internally we refine it
  /// to at most 10 minutes for a smoother apparent path.
  @override
  List<EquatorialTrajectorySample> generateTrajectory({
    required DateTime center,
    double hoursBefore = 12.0,
    double hoursAfter = 12.0,
    int stepMinutes = 30,
  }) {
    if (hoursBefore < 0) {
      throw ArgumentError(
        'hoursBefore cannot be negative.',
      );
    }

    if (hoursAfter < 0) {
      throw ArgumentError(
        'hoursAfter cannot be negative.',
      );
    }

    if (stepMinutes <= 0) {
      throw ArgumentError(
        'stepMinutes must be greater than zero.',
      );
    }

    /*
     * The generic SkyBloc currently requests 30-minute samples for every
     * celestial body.
     *
     * That is perfectly adequate for the Sun, but the Moon benefits from
     * finer sampling because its apparent path is more curved and its
     * topocentric parallax changes with time.
     *
     * We therefore refine the requested interval for the Moon itself.
     */
    final effectiveStepMinutes =
        math.min(stepMinutes, 10);

    final start = center.subtract(
      Duration(
        minutes: (hoursBefore * 60.0).round(),
      ),
    );

    final end = center.add(
      Duration(
        minutes: (hoursAfter * 60.0).round(),
      ),
    );

    final points =
        <EquatorialTrajectorySample>[];

    var current = start;

    while (!current.isAfter(end)) {
      final position =
          _computePosition(current);

      points.add(
        EquatorialTrajectorySample(
          time: current,
          ra: position.ra,
          dec: position.dec,
          distanceKm: position.distanceKm,
        ),
      );

      current = current.add(
        Duration(
          minutes: effectiveStepMinutes,
        ),
      );
    }

    /*
     * Always include the exact end time.
     *
     * This prevents the final segment from ending early when the requested
     * duration is not an exact multiple of the sampling interval.
     */
    if (points.isEmpty ||
        points.last.time != end) {
      final position =
          _computePosition(end);

      points.add(
        EquatorialTrajectorySample(
          time: end,
          ra: position.ra,
          dec: position.dec,
          distanceKm: position.distanceKm,
        ),
      );
    }

    return points;
  }

  _MoonPosition _computePosition(
    DateTime utc,
  ) {
    final t =
        _centuriesSinceJ2000(utc);

    /*
     * Fundamental lunar arguments.
     *
     * L' = Moon's mean longitude
     * D  = Moon's mean elongation
     * M  = Sun's mean anomaly
     * M' = Moon's mean anomaly
     * F  = Moon's argument of latitude
     */
    final meanLongitude = _normalize(
      218.3164477 +
          481267.88123421 * t,
    );

    final meanElongation = _normalize(
      297.8501921 +
          445267.1114034 * t,
    );

    final sunMeanAnomaly = _normalize(
      357.5291092 +
          35999.0502909 * t,
    );

    final moonMeanAnomaly = _normalize(
      134.9633964 +
          477198.8675055 * t,
    );

    final argumentOfLatitude = _normalize(
      93.2720950 +
          483202.0175233 * t,
    );

    final d =
        _radians(meanElongation);

    final m =
        _radians(sunMeanAnomaly);

    final mPrime =
        _radians(moonMeanAnomaly);

    final f =
        _radians(argumentOfLatitude);

    /*
     * Lunar ecliptic longitude correction.
     *
     * The dominant +6.289° sin(M') term is primarily the Moon's
     * equation-of-center contribution.
     *
     * The -1.274° sin(M' - 2D) term is the important evection term.
     */
    final longitudeCorrection =
        6.289 * math.sin(mPrime) -
        1.274 *
            math.sin(
              mPrime - 2.0 * d,
            ) +
        0.658 *
            math.sin(
              2.0 * d,
            ) -
        0.186 *
            math.sin(m) -
        0.059 *
            math.sin(
              2.0 * mPrime - 2.0 * d,
            ) -
        0.057 *
            math.sin(
              mPrime - 2.0 * d + m,
            ) +
        0.053 *
            math.sin(
              mPrime + 2.0 * d,
            ) +
        0.046 *
            math.sin(
              2.0 * d - m,
            ) +
        0.041 *
            math.sin(
              mPrime - m,
            ) -
        0.035 *
            math.sin(d) -
        0.031 *
            math.sin(
              mPrime + m,
            ) -
        0.015 *
            math.sin(
              2.0 * f - 2.0 * d,
            ) +
        0.011 *
            math.sin(
              mPrime - 4.0 * d,
            );

    final eclipticLongitude =
        _normalize(
      meanLongitude +
          longitudeCorrection,
    );

    /*
     * Lunar ecliptic latitude correction.
     */
    final eclipticLatitude =
        5.128 *
            math.sin(f) +
        0.281 *
            math.sin(
              mPrime + f,
            ) +
        0.278 *
            math.sin(
              mPrime - f,
            ) +
        0.173 *
            math.sin(
              2.0 * d - f,
            ) +
        0.055 *
            math.sin(
              2.0 * d -
                  mPrime +
                  f,
            ) +
        0.046 *
            math.sin(
              2.0 * d -
                  mPrime -
                  f,
            ) +
        0.033 *
            math.sin(
              2.0 * d + f,
            ) +
        0.017 *
            math.sin(
              2.0 * mPrime + f,
            );

    /*
     * Geocentric Earth-Moon distance, km.
     *
     * The dominant variation is produced by the Moon's orbital
     * eccentricity and therefore controls the perigee/apogee distance.
     */
    final distanceKm =
        385000.56 -
        20905.355 *
            math.cos(mPrime) -
        3699.111 *
            math.cos(
              2.0 * d - mPrime,
            ) -
        2955.968 *
            math.cos(
              2.0 * d,
            ) -
        569.925 *
            math.cos(
              2.0 * mPrime,
            ) +
        246.158 *
            math.cos(
              2.0 * d -
                  2.0 * mPrime,
            ) -
        204.586 *
            math.cos(
              2.0 * d - m,
            ) -
        170.733 *
            math.cos(
              2.0 * d + mPrime,
            );

    /*
     * Mean obliquity of the ecliptic.
     *
     * Kept consistent with SunCalculator.
     */
    final obliquity =
        _radians(
      23.439291 -
          0.0130042 * t,
    );

    final lambda =
        _radians(eclipticLongitude);

    final beta =
        _radians(eclipticLatitude);

    /*
     * Ecliptic -> equatorial.
     *
     * RA:
     *
     * atan2(
     *   sin(lambda) cos(epsilon)
     *   - tan(beta) sin(epsilon),
     *   cos(lambda)
     * )
     *
     * Dec:
     *
     * asin(
     *   sin(beta) cos(epsilon)
     *   +
     *   cos(beta) sin(epsilon) sin(lambda)
     * )
     */
    var ra = math.atan2(
      math.sin(lambda) *
              math.cos(obliquity) -
          math.tan(beta) *
              math.sin(obliquity),
      math.cos(lambda),
    );

    if (ra < 0.0) {
      ra += 2.0 * math.pi;
    }

    final dec =
        math.asin(
      (
        math.sin(beta) *
                math.cos(obliquity) +
            math.cos(beta) *
                math.sin(obliquity) *
                math.sin(lambda)
      ).clamp(-1.0, 1.0),
    );

    return _MoonPosition(
      ra: _degrees(ra),
      dec: _degrees(dec),
      distanceKm: distanceKm,
      eclipticLongitudeDegrees:
          eclipticLongitude,
    );
  }

  /// Converts equatorial Sun coordinates back into ecliptic longitude.
  ///
  /// Used only for determining the Moon's phase angle.
  double _equatorialToEclipticLongitude({
    required double raDegrees,
    required double decDegrees,
    required double t,
  }) {
    final ra =
        _radians(raDegrees);

    final dec =
        _radians(decDegrees);

    final obliquity =
        _radians(
      23.439291 -
          0.0130042 * t,
    );

    final lambda =
        math.atan2(
      math.sin(ra) *
              math.cos(obliquity) +
          math.tan(dec) *
              math.sin(obliquity),
      math.cos(ra),
    );

    return _normalize(
      _degrees(lambda),
    );
  }

  /// Signed angular difference in degrees.
  ///
  /// Result is in [-180, 180).
  double _signedAngleDifference(
    double a,
    double b,
  ) {
    var difference =
        (a - b) % 360.0;

    if (difference >= 180.0) {
      difference -= 360.0;
    }

    if (difference < -180.0) {
      difference += 360.0;
    }

    return difference;
  }

  /// Converts lunar phase angle into one of the eight conventional
  /// phase names.
  ///
  /// Phase angle:
  ///
  ///   lambdaMoon - lambdaSun
  ///
  /// gives:
  ///
  ///   0°   New Moon
  ///   90°  First Quarter
  ///   180° Full Moon
  ///   270° Last Quarter
  String _phaseName(
    double phaseAngleDegrees,
  ) {
    final angle =
        _normalize(phaseAngleDegrees);

    if (angle < 22.5 ||
        angle >= 337.5) {
      return 'New Moon';
    }

    if (angle < 67.5) {
      return 'Waxing Crescent';
    }

    if (angle < 112.5) {
      return 'First Quarter';
    }

    if (angle < 157.5) {
      return 'Waxing Gibbous';
    }

    if (angle < 202.5) {
      return 'Full Moon';
    }

    if (angle < 247.5) {
      return 'Waning Gibbous';
    }

    if (angle < 292.5) {
      return 'Last Quarter';
    }

    return 'Waning Crescent';
  }

  /// Julian centuries since J2000.0.
  double _centuriesSinceJ2000(
    DateTime utc,
  ) {
    final jd =
        utc.millisecondsSinceEpoch /
                86400000.0 +
            2440587.5;

    return (jd - 2451545.0) /
        36525.0;
  }

  double _normalize(
    double degrees,
  ) {
    var value =
        degrees % 360.0;

    if (value < 0.0) {
      value += 360.0;
    }

    return value;
  }

  double _radians(
    double degrees,
  ) {
    return degrees *
        math.pi /
        180.0;
  }

  double _degrees(
    double radians,
  ) {
    return radians *
        180.0 /
        math.pi;
  }
}
