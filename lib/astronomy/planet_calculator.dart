import 'dart:math' as math;

import 'celestial_calculator.dart';

/// One AU in kilometres.
const double _auInKm = 149597870.7;

/// A planet's mean orbital elements at J2000 and their rates of change,
/// per JPL/Standish's low-precision planetary theory (valid 1800-2050
/// AD — see "Keplerian Elements for Approximate Positions of the Major
/// Planets", ssd.jpl.nasa.gov/planets/approx_pos.html).
///
/// [a] is in AU; every angle is in degrees. Each "Dot" field is the
/// corresponding rate, per Julian century.
class OrbitalElements {
  final double a, aDot;
  final double e, eDot;
  final double inclination, inclinationDot;
  final double meanLongitude, meanLongitudeDot;
  final double longitudeOfPerihelion, longitudeOfPerihelionDot;
  final double longitudeOfNode, longitudeOfNodeDot;

  const OrbitalElements({
    required this.a,
    required this.aDot,
    required this.e,
    required this.eDot,
    required this.inclination,
    required this.inclinationDot,
    required this.meanLongitude,
    required this.meanLongitudeDot,
    required this.longitudeOfPerihelion,
    required this.longitudeOfPerihelionDot,
    required this.longitudeOfNode,
    required this.longitudeOfNodeDot,
  });
}

/// Computes a planet's apparent geocentric equatorial position from its
/// [OrbitalElements].
///
/// Both the planet's and Earth's heliocentric positions are derived from
/// the same Keplerian model; the geocentric position is their vector
/// difference. This is accurate to arcminute level over 1800-2050, far
/// beyond what a naked-eye sky map needs, and — unlike SunCalculator and
/// MoonCalculator — the same implementation serves every planet, just
/// parameterised by [elements].
class PlanetCalculator implements CelestialCalculator {
  final OrbitalElements elements;

  /// Recommended trajectory step for fast inner planets; defaults to 30.
  final int recommendedStepMinutes;

  const PlanetCalculator(
    this.elements, {
    this.recommendedStepMinutes = 30,
  });

  /// Earth/Moon barycenter elements, used to convert every planet's
  /// heliocentric position into a geocentric one.
  static const OrbitalElements _earth = OrbitalElements(
    a: 1.00000261,
    aDot: 0.00000562,
    e: 0.01671123,
    eDot: -0.00004392,
    inclination: -0.00001531,
    inclinationDot: -0.01294668,
    meanLongitude: 100.46457166,
    meanLongitudeDot: 35999.37244981,
    longitudeOfPerihelion: 102.93768193,
    longitudeOfPerihelionDot: 0.32327364,
    longitudeOfNode: 0.0,
    longitudeOfNodeDot: 0.0,
  );

  @override
  (double ra, double dec, double? distanceKm) calculate(DateTime utc) {
    final t = _centuriesSinceJ2000(utc);

    final planet = _heliocentric(elements, t);
    final earth = _heliocentric(_earth, t);

    final x = planet.x - earth.x;
    final y = planet.y - earth.y;
    final z = planet.z - earth.z;

    final distanceAu = math.sqrt(x * x + y * y + z * z);

    // Ecliptic -> equatorial: rotate about the x-axis by the mean
    // obliquity at the given time (consistent with Sun/Moon calculators).
    final obliquity = _radians(_meanObliquity(t));
    final yEq = y * math.cos(obliquity) - z * math.sin(obliquity);
    final zEq = y * math.sin(obliquity) + z * math.cos(obliquity);

    var ra = math.atan2(yEq, x);
    if (ra < 0) ra += 2 * math.pi;

    final dec = math.asin((zEq / distanceAu).clamp(-1.0, 1.0));

    final raDeg = _degrees(ra);
    final decDeg = _degrees(dec);

    // Uncomment to debug RA/Dec changes over time:
    // print('${utc.toIso8601String()}: RA=$raDeg, Dec=$decDeg');

    return (raDeg, decDeg, distanceAu * _auInKm);
  }

  @override
  List<EquatorialTrajectorySample> generateTrajectory({
    required DateTime center,
    double hoursBefore = 12.0,
    double hoursAfter = 12.0,
    int stepMinutes = 30,
  }) {
    if (hoursBefore < 0) {
      throw ArgumentError('hoursBefore cannot be negative.');
    }

    if (hoursAfter < 0) {
      throw ArgumentError('hoursAfter cannot be negative.');
    }

    if (stepMinutes <= 0) {
      throw ArgumentError('stepMinutes must be greater than zero.');
    }

    // For fast inner planets, use a finer step if the caller requests
    // a coarser one; ensure we don't exceed the recommended step.
    final effectiveStep = math.min(stepMinutes, recommendedStepMinutes);

    final start = center.subtract(
      Duration(minutes: (hoursBefore * 60).round()),
    );
    final end = center.add(
      Duration(minutes: (hoursAfter * 60).round()),
    );

    final points = <EquatorialTrajectorySample>[];
    var current = start;

    while (!current.isAfter(end)) {
      final (ra, dec, distanceKm) = calculate(current);

      points.add(
        EquatorialTrajectorySample(
          time: current,
          ra: ra,
          dec: dec,
          distanceKm: distanceKm,
        ),
      );

      current = current.add(Duration(minutes: effectiveStep));
    }

    if (points.isEmpty || points.last.time != end) {
      final (ra, dec, distanceKm) = calculate(end);

      points.add(
        EquatorialTrajectorySample(
          time: end,
          ra: ra,
          dec: dec,
          distanceKm: distanceKm,
        ),
      );
    }

    return points;
  }

  /// Heliocentric ecliptic (J2000) position in AU: mean anomaly ->
  /// eccentric anomaly (Kepler's equation, solved iteratively) ->
  /// orbital-plane coordinates -> rotated into the ecliptic frame.
  _HeliocentricPosition _heliocentric(OrbitalElements el, double t) {
    final a = el.a + el.aDot * t;
    final e = el.e + el.eDot * t;
    final i = _radians(el.inclination + el.inclinationDot * t);
    final l = el.meanLongitude + el.meanLongitudeDot * t;
    final longPeri =
        el.longitudeOfPerihelion + el.longitudeOfPerihelionDot * t;
    final longNode = el.longitudeOfNode + el.longitudeOfNodeDot * t;

    final argPeri = _radians(longPeri - longNode);
    final node = _radians(longNode);

    final meanAnomaly = _normalizeSigned(l - longPeri);

    // Eccentricity expressed in degrees, as used by Standish's form of
    // Kepler's equation: M = E - e* sin(E) (with e in radians, E in degrees).
    final eStar = e * 180.0 / math.pi;

    var eAnomaly = meanAnomaly + eStar * math.sin(_radians(meanAnomaly));

    for (var iteration = 0; iteration < 10; iteration++) {
      final eRad = _radians(eAnomaly);
      final deltaM = meanAnomaly - (eAnomaly - eStar * math.sin(eRad));
      final deltaE = deltaM / (1 - e * math.cos(eRad));
      eAnomaly += deltaE;

      if (deltaE.abs() < 1e-6) break;
    }

    final eRad = _radians(eAnomaly);
    final xOrbit = a * (math.cos(eRad) - e);
    final yOrbit = a * math.sqrt(1 - e * e) * math.sin(eRad);

    final cosPeri = math.cos(argPeri);
    final sinPeri = math.sin(argPeri);
    final cosNode = math.cos(node);
    final sinNode = math.sin(node);
    final cosI = math.cos(i);
    final sinI = math.sin(i);

    final x = (cosPeri * cosNode - sinPeri * sinNode * cosI) * xOrbit +
        (-sinPeri * cosNode - cosPeri * sinNode * cosI) * yOrbit;
    final y = (cosPeri * sinNode + sinPeri * cosNode * cosI) * xOrbit +
        (-sinPeri * sinNode + cosPeri * cosNode * cosI) * yOrbit;
    final z = (sinPeri * sinI) * xOrbit + (cosPeri * sinI) * yOrbit;

    return _HeliocentricPosition(x, y, z);
  }

  /// Mean obliquity of the ecliptic (degrees) at Julian centuries [t].
  ///
  /// Exactly the same formula used by [SunCalculator] and [MoonCalculator].
  double _meanObliquity(double t) {
    return 23.439291 - 0.0130042 * t - 0.000000164 * t * t + 0.000000504 * t * t * t;
  }

  /// Normalizes [degrees] into [-180, 180).
  double _normalizeSigned(double degrees) {
    var value = degrees % 360.0;
    if (value < -180.0) value += 360.0;
    if (value >= 180.0) value -= 360.0;
    return value;
  }

  double _centuriesSinceJ2000(DateTime utc) {
    final jd = utc.millisecondsSinceEpoch / 86400000.0 + 2440587.5;
    return (jd - 2451545.0) / 36525.0;
  }

  double _radians(double degrees) => degrees * math.pi / 180.0;

  double _degrees(double radians) => radians * 180.0 / math.pi;
}

class _HeliocentricPosition {
  final double x, y, z;

  const _HeliocentricPosition(this.x, this.y, this.z);
}