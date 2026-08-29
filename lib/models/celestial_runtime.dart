import 'package:equatable/equatable.dart';

import 'celestial_position.dart';
import 'celestial_trajectory.dart';

/// Bundles everything computed for one celestial object at the current
/// position-update tick, keyed by body id in SkyState. Kept as a single
/// value (not several parallel maps) so a body can never end up with,
/// say, a position but no vector — they always update together.
class CelestialRuntime extends Equatable {
  final double ra;
  final double dec;
  final CelestialPosition position;
  final WorldVector vector;
  final CelestialTrajectory trajectory;

  /// Distance in km, when the body's calculator provides one (Moon).
  /// Null for bodies where distance is irrelevant (Sun, stars).
  final double? distanceKm;

  /// Per-body facts computed at this tick rather than being fixed
  /// (e.g. the Moon's phase name and illuminated %, which change over
  /// time unlike mass or orbital period). Empty for bodies that don't
  /// need this (Sun).
  final List<MapEntry<String, String>> extraFacts;

  const CelestialRuntime({
    required this.ra,
    required this.dec,
    required this.position,
    required this.vector,
    required this.trajectory,
    this.distanceKm,
    this.extraFacts = const [],
  });

  @override
  List<Object?> get props =>
      [ra, dec, position, vector, trajectory, distanceKm, extraFacts];
}
