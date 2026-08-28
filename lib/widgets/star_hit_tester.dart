import 'package:flutter/material.dart';

import '../models/device_orientation.dart';
import '../models/sky_star.dart';
import 'camera_projector.dart';

/// What was tapped: a catalog star or a celestial body. Returned by
/// [StarHitTester.findTapped].
sealed class SkyTapResult {
  const SkyTapResult();
}

final class StarTapResult extends SkyTapResult {
  final int starId;

  const StarTapResult(this.starId);
}

final class CelestialObjectTapResult extends SkyTapResult {
  final String objectId;

  const CelestialObjectTapResult(this.objectId);
}

class StarHitTester {
  static const double _hitRadius = 22.0;
  static const double _celestialObjectHitRadius = 30.0;

  /// Finds the nearest interactable object under [tapPosition] — a
  /// named star or a celestial body — across both categories in a
  /// single pass, so the globally nearest hit wins rather than one
  /// category getting implicit priority over the other.
  ///
  /// [celestialVectors] is keyed by CelestialBody.id (e.g. `"sun"`).
  static SkyTapResult? findTapped({
    required Offset tapPosition,
    required List<SkyStar> stars,
    required List<List<double>> starVectors,
    required Map<String, List<double>> celestialVectors,
    required DeviceOrientation orientation,
    required Offset center,
    required Size size,
  }) {
    final focalLength = size.height * 0.5;

    SkyTapResult? best;
    var bestDistanceSq = double.infinity;

    for (final entry in celestialVectors.entries) {
      final projected = CameraProjector.project(
        entry.value,
        orientation,
        center,
        focalLength,
      );

      if (projected == null) {
        continue;
      }

      final dx = projected.dx - tapPosition.dx;
      final dy = projected.dy - tapPosition.dy;
      final distanceSq = dx * dx + dy * dy;

      if (distanceSq < _celestialObjectHitRadius * _celestialObjectHitRadius &&
          distanceSq < bestDistanceSq) {
        bestDistanceSq = distanceSq;
        best = CelestialObjectTapResult(entry.key);
      }
    }

    final count = stars.length < starVectors.length
        ? stars.length
        : starVectors.length;

    for (var i = 0; i < count; i++) {
      final star = stars[i];

      if (!star.isInteractable) {
        continue;
      }

      final projected = CameraProjector.project(
        starVectors[i],
        orientation,
        center,
        focalLength,
      );

      if (projected == null) {
        continue;
      }

      final dx = projected.dx - tapPosition.dx;
      final dy = projected.dy - tapPosition.dy;
      final distanceSq = dx * dx + dy * dy;

      if (distanceSq < _hitRadius * _hitRadius &&
          distanceSq < bestDistanceSq) {
        bestDistanceSq = distanceSq;
        best = StarTapResult(star.id);
      }
    }

    return best;
  }
}
