import 'dart:math' as math;

/// Calculates the apparent geocentric position of the Sun.
///
/// The calculator provides:
///
/// - Right ascension
/// - Declination
/// - Apparent sky trajectory
///
/// The trajectory is NOT the physical orbit of the Earth around
/// the Sun. It is the apparent path of the Sun across the
/// observer's celestial sphere.
class SunCalculator {
  const SunCalculator();

  /// Calculates the Sun's equatorial coordinates.
  ///
  /// Returns:
  ///
  ///   (right ascension, declination)
  ///
  /// Both values are expressed in degrees.
  (double ra, double dec) calculate(DateTime utc) {
    final jd = _julianDate(utc);

    final t =
        (jd - 2451545.0) / 36525.0;

    /*
     * Geometric mean longitude of the Sun.
     */
    var meanLongitude =
        280.46646 +
        36000.76983 * t +
        0.0003032 * t * t;

    meanLongitude %= 360.0;

    if (meanLongitude < 0) {
      meanLongitude += 360.0;
    }

    /*
     * Mean anomaly of the Sun.
     */
    final meanAnomaly =
        357.52911 +
        35999.05029 * t -
        0.0001537 * t * t;

    final m =
        _radians(meanAnomaly);

    /*
     * Equation of the center.
     */
    final equationOfCenter =
        (1.914602 -
                0.004817 * t -
                0.000014 * t * t) *
            math.sin(m) +
        (0.019993 -
                0.000101 * t) *
            math.sin(2 * m) +
        0.000289 *
            math.sin(3 * m);

    /*
     * True longitude.
     */
    final trueLongitude =
        meanLongitude +
        equationOfCenter;

    /*
     * Apparent longitude correction.
     */
    final omega =
        _radians(
          125.04 -
              1934.136 * t,
        );

    final apparentLongitude =
        trueLongitude -
        0.00569 -
        0.00478 *
            math.sin(omega);

    /*
     * Mean obliquity of the ecliptic.
     */
    final meanObliquity =
        23.439291 -
        0.0130042 * t -
        0.000000164 * t * t +
        0.000000504 *
            t * t * t;

    /*
     * Apparent obliquity.
     */
    final obliquity =
        meanObliquity +
        0.00256 *
            math.cos(omega);

    final lambda =
        _radians(
          apparentLongitude,
        );

    final epsilon =
        _radians(
          obliquity,
        );

    /*
     * Ecliptic -> Equatorial.
     *
     * RA:
     *
     *   α = atan2(
     *       cos(ε) sin(λ),
     *       cos(λ)
     *   )
     *
     * Dec:
     *
     *   δ = asin(
     *       sin(ε) sin(λ)
     *   )
     */

    var ra = math.atan2(
      math.cos(epsilon) *
          math.sin(lambda),
      math.cos(lambda),
    );

    if (ra < 0) {
      ra += 2 * math.pi;
    }

    final sinDeclination =
        math.sin(epsilon) *
        math.sin(lambda);

    final dec = math.asin(
      sinDeclination.clamp(
        -1.0,
        1.0,
      ),
    );

    return (
      _degrees(ra),
      _degrees(dec),
    );
  }

  /// Generates the Sun's apparent trajectory.
  ///
  /// [center] is the instant around which the trajectory is generated.
  ///
  /// [hoursBefore] determines how far into the past the trajectory goes.
  ///
  /// [hoursAfter] determines how far into the future the trajectory goes.
  ///
  /// [stepMinutes] determines the sampling interval.
  ///
  /// Example:
  ///
  ///   generateTrajectory(
  ///     center: DateTime.now().toUtc(),
  ///     hoursBefore: 12,
  ///     hoursAfter: 12,
  ///     stepMinutes: 30,
  ///   );
  ///
  /// produces a 24-hour apparent solar path with a point every 30 minutes.
  ///
  /// The returned points are still equatorial coordinates. They are
  /// converted to horizontal/world coordinates later because the
  /// observer's location belongs to the coordinate-conversion layer.
  List<SunEquatorialPoint> generateTrajectory({
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

    final start = center.subtract(
      Duration(
        minutes:
            (hoursBefore * 60).round(),
      ),
    );

    final end = center.add(
      Duration(
        minutes:
            (hoursAfter * 60).round(),
      ),
    );

    final points =
        <SunEquatorialPoint>[];

    var current = start;

    while (!current.isAfter(end)) {
      final (ra, dec) =
          calculate(current);

      points.add(
        SunEquatorialPoint(
          time: current,
          ra: ra,
          dec: dec,
        ),
      );

      current = current.add(
        Duration(
          minutes: stepMinutes,
        ),
      );
    }

    /*
     * Ensure the exact end point exists even if
     * the requested duration is not divisible by
     * stepMinutes.
     */
    if (points.isEmpty ||
        points.last.time != end) {
      final (ra, dec) =
          calculate(end);

      points.add(
        SunEquatorialPoint(
          time: end,
          ra: ra,
          dec: dec,
        ),
      );
    }

    return points;
  }

  double _julianDate(DateTime utc) {
    return utc.millisecondsSinceEpoch /
            86400000.0 +
        2440587.5;
  }

  double _radians(double degrees) {
    return degrees *
        math.pi /
        180.0;
  }

  double _degrees(double radians) {
    return radians *
        180.0 /
        math.pi;
  }
}

/// One sampled position of the Sun along its apparent trajectory.
///
/// RA and Dec are expressed in degrees.
class SunEquatorialPoint {
  final DateTime time;
  final double ra;
  final double dec;

  const SunEquatorialPoint({
    required this.time,
    required this.ra,
    required this.dec,
  });
}