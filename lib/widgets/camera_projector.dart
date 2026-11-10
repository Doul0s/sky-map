import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/device_orientation.dart';

/// A world-space unit vector expressed in camera space: [x]/[y] are the
/// point's position on the camera's right/up axes, and [depth] is how
/// far along the camera's forward axis it sits. `depth <= 0` means the
/// point is behind the observer.
class CameraPoint {
  final double x;
  final double y;
  final double depth;

  const CameraPoint({
    required this.x,
    required this.y,
    required this.depth,
  });
}

/// Converts world-space unit vectors (X = North, Y = East, Z = Up) into
/// screen coordinates for the current device orientation.
///
/// This is the one place the world -> camera -> screen transform lives.
/// SkyPainter (rendering, every frame) and StarHitTester (tap detection,
/// on tap) both need the exact same math to stay in sync — previously
/// each reimplemented it independently.
class CameraProjector {
  CameraProjector._();

  static double focalLength(Size size) =>
      math.max(size.width, size.height) * 0.5;

  static CameraPoint toCameraSpace(
    List<double> world,
    DeviceOrientation orientation,
  ) {
    final worldX = world[0];
    final worldY = world[1];
    final worldZ = world[2];

    final x = worldX * orientation.rightX +
        worldY * orientation.rightY +
        worldZ * orientation.rightZ;

    final y = worldX * orientation.upX +
        worldY * orientation.upY +
        worldZ * orientation.upZ;

    final depth = worldX * orientation.backX +
        worldY * orientation.backY +
        worldZ * orientation.backZ;

    return CameraPoint(x: x, y: y, depth: depth);
  }

  static Offset projectCameraPoint(
    CameraPoint point,
    Offset center,
    double focalLength,
  ) {
    return Offset(
      center.dx + focalLength * point.x / point.depth,
      center.dy - focalLength * point.y / point.depth,
    );
  }

  /// World -> screen in one step. Returns null when the point is behind
  /// the observer (`depth <= 0`) — there is no sensible screen position
  /// for it. Callers that need off-screen-bounds culling on top of this
  /// (e.g. SkyPainter skipping stars well outside the canvas) apply that
  /// separately on the returned [Offset].
  static Offset? project(
    List<double> world,
    DeviceOrientation orientation,
    Offset center,
    double focalLength,
  ) {
    final camera = toCameraSpace(world, orientation);

    if (camera.depth <= 0) {
      return null;
    }

    return projectCameraPoint(camera, center, focalLength);
  }
}
