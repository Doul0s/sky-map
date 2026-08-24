import 'package:flutter/material.dart';

import '../models/device_orientation.dart';
import '../models/sky_star.dart';

class StarHitTester {
  static const double _hitRadius = 22.0;

  /// Finds the nearest interactable (named) star under [tapPosition].
  ///
  /// Mirrors SkyPainter's world -> camera -> screen projection, but only
  /// runs on tap (not per frame) and only over named stars, so redoing
  /// the math here instead of caching it is cheap.
  static int? findTappedStar({
    required Offset tapPosition,
    required List<SkyStar> stars,
    required List<List<double>> starVectors,
    required DeviceOrientation orientation,
    required Offset center,
    required Size size,
  }) {
    final focalLength = size.height * 0.5;

    int? bestId;
    var bestDistanceSq = _hitRadius * _hitRadius;

    final count = stars.length < starVectors.length
        ? stars.length
        : starVectors.length;

    for (var i = 0; i < count; i++) {
      final star = stars[i];

      if (!star.isInteractable) {
        continue;
      }

      final world = starVectors[i];

      final worldX = world[0];
      final worldY = world[1];
      final worldZ = world[2];

      final depth = worldX * orientation.backX +
          worldY * orientation.backY +
          worldZ * orientation.backZ;

      if (depth <= 0) {
        continue;
      }

      final cameraX = worldX * orientation.rightX +
          worldY * orientation.rightY +
          worldZ * orientation.rightZ;

      final cameraY = worldX * orientation.upX +
          worldY * orientation.upY +
          worldZ * orientation.upZ;

      final screenX = center.dx + focalLength * cameraX / depth;
      final screenY = center.dy - focalLength * cameraY / depth;

      final dx = screenX - tapPosition.dx;
      final dy = screenY - tapPosition.dy;
      final distanceSq = dx * dx + dy * dy;

      if (distanceSq < bestDistanceSq) {
        bestDistanceSq = distanceSq;
        bestId = star.id;
      }
    }

    return bestId;
  }
}