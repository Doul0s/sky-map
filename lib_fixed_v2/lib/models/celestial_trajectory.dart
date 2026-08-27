import 'package:equatable/equatable.dart';

/// A normalized vector representing a direction in the
/// application's world coordinate system.
///
/// World coordinates:
///
///   X = North
///   Y = East
///   Z = Up
typedef WorldVector = List<double>;

/// Represents the apparent path of a celestial object
/// across the observer's sky.
///
/// This is NOT the physical orbit of the object.
/// It is a sequence of sky directions sampled over time.
class CelestialTrajectory extends Equatable {
  final List<WorldVector> points;

  const CelestialTrajectory({
    required this.points,
  });

  bool get isEmpty => points.isEmpty;

  bool get isNotEmpty => points.isNotEmpty;

  @override
  List<Object?> get props => [
        points,
      ];
}