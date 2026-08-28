import 'package:equatable/equatable.dart';

import 'celestial_position.dart';
import 'celestial_trajectory.dart';

class CelestialRuntime extends Equatable {
  final double ra;
  final double dec;
  final CelestialPosition position;
  final WorldVector vector;
  final CelestialTrajectory trajectory;

  const CelestialRuntime({
    required this.ra,
    required this.dec,
    required this.position,
    required this.vector,
    required this.trajectory,
  });

  @override
  List<Object?> get props => [ra, dec, position, vector, trajectory];
}
