/// One sampled equatorial position along a celestial object's apparent
/// trajectory.
///
/// RA and Dec are expressed in degrees. [distanceKm] is null for bodies
/// far enough that parallax is irrelevant (stars, Sun); when present, it
/// triggers topocentric correction in CoordinateConverter.
class EquatorialTrajectorySample {
  final DateTime time;
  final double ra;
  final double dec;
  final double? distanceKm;

  const EquatorialTrajectorySample({
    required this.time,
    required this.ra,
    required this.dec,
    this.distanceKm,
  });
}

/// Common interface for anything that can compute a celestial body's
/// apparent equatorial position over time.
///
/// Implemented by [SunCalculator] and [MoonCalculator] today. A
/// Mars/Venus calculator implementing the same shape is all that's
/// needed to add those bodies later — nothing in SkyBloc, SkyState, or
/// SkyPainter needs to change per-body once a calculator exists.
abstract class CelestialCalculator {
  /// Equatorial coordinates (RA, Dec, in degrees) at [utc], plus
  /// distance in km when relevant to parallax (null otherwise — see
  /// [EquatorialTrajectorySample.distanceKm]).
  (double ra, double dec, double? distanceKm) calculate(DateTime utc);

  /// Apparent trajectory sampled around [center].
  List<EquatorialTrajectorySample> generateTrajectory({
    required DateTime center,
    double hoursBefore,
    double hoursAfter,
    int stepMinutes,
  });
}
