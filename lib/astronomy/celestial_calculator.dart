/// One sampled equatorial position along a celestial object's apparent
/// trajectory.
///
/// RA and Dec are expressed in degrees.
class EquatorialTrajectorySample {
  final DateTime time;
  final double ra;
  final double dec;

  const EquatorialTrajectorySample({
    required this.time,
    required this.ra,
    required this.dec,
  });
}

/// Common interface for anything that can compute a celestial body's
/// apparent equatorial position over time.
abstract class CelestialCalculator {
  /// Equatorial coordinates (RA, Dec) in degrees at [utc].
  (double ra, double dec) calculate(DateTime utc);

  /// Apparent trajectory sampled around [center].
  List<EquatorialTrajectorySample> generateTrajectory({
    required DateTime center,
    double hoursBefore,
    double hoursAfter,
    int stepMinutes,
  });
}
