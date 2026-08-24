import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../astronomy/sky_coordinates.dart';
import '../blocs/sky/sky_state.dart';
import '../models/constellation.dart';
import '../models/device_orientation.dart';
import '../models/sky_star.dart';

class SkyPainter extends CustomPainter {
  final DeviceOrientation orientation;
  final List<SkyStar> stars;
  final List<WorldVector> starVectors;
  final List<Constellation> constellations;
  final bool showHorizon;
  final bool showConstellations;
  final bool objectSelectionEnabled;
  final int? selectedStarId;

  const SkyPainter({
    required this.orientation,
    required this.stars,
    required this.starVectors,
    required this.constellations,
    this.showHorizon = true,
    this.showConstellations = true,
    this.objectSelectionEnabled = false,
    this.selectedStarId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    // Built once per frame and shared between star dots and
    // constellation lines, instead of recomputing world vectors
    // separately for each.
    final starWorldVectors = _starWorldVectorsById();

    final starPositions = _projectStars(
      starWorldVectors,
      center,
      size,
    );

    _drawStars(
      canvas,
      starPositions,
    );

    if (showConstellations) {
      _drawConstellations(
        canvas,
        starWorldVectors,
        size,
        center,
      );
    }

    // The selected star's constellation is always shown, brighter than
    // the normal lines, even if "Stars" (constellations) is toggled off.
    final highlightedConstellation =
        _selectedConstellation();

    if (highlightedConstellation != null) {
      _drawHighlightedConstellation(
        canvas,
        starWorldVectors,
        size,
        center,
        highlightedConstellation,
      );
    }

    if (showHorizon) {
      _drawHorizon(
        canvas,
        size,
      );

      _drawCompassLabels(
        canvas,
        center,
        size,
      );
    }

    // Keep the aiming point above everything else.
    _drawCenterMarker(
      canvas,
      size,
    );
  }

  // World vectors are already computed by SkyBloc whenever `positions`
  // changes (every 30s). This just indexes them by star id — no trig,
  // no per-frame astronomy.
  Map<int, List<double>> _starWorldVectorsById() {
    final result = <int, List<double>>{};

    final count = math.min(
      stars.length,
      starVectors.length,
    );

    for (var i = 0; i < count; i++) {
      result[stars[i].id] = starVectors[i];
    }

    return result;
  }

  // Converts the prepared world vectors into screen coordinates.
  //
  // Astronomy has already been done by SkyBloc. The painter only deals
  // with the camera and the canvas.
  Map<int, Offset> _projectStars(
    Map<int, List<double>> starWorldVectors,
    Offset center,
    Size size,
  ) {
    final result = <int, Offset>{};

    for (final entry in starWorldVectors.entries) {
      final point = _projectStar(
        entry.value,
        center,
        size,
      );

      if (point != null) {
        result[entry.key] = point;
      }
    }

    return result;
  }

  Offset? _projectStar(
    List<double> world,
    Offset center,
    Size size,
  ) {
    final camera = _cameraCoordinates(world);

    // Stars behind the phone cannot be seen.
    if (camera.depth <= 0) {
      return null;
    }

    final focalLength = size.height * 0.5;

    final x = center.dx +
        focalLength *
            camera.x /
            camera.depth;

    final y = center.dy -
        focalLength *
            camera.y /
            camera.depth;

    // Keep a small amount of padding so stars do not pop at the edge.
    if (x < -4 ||
        x > size.width + 4 ||
        y < -4 ||
        y > size.height + 4) {
      return null;
    }

    return Offset(x, y);
  }

  // Draw constellation segments independently.
  //
  // This is important because a constellation should not disappear just
  // because one of its stars has moved outside the screen.
  void _drawConstellations(
    Canvas canvas,
    Map<int, List<double>> starWorldPositions,
    Size size,
    Offset center,
  ) {
    if (constellations.isEmpty) {
      return;
    }

    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.45)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (final constellation in constellations) {
      for (final line in constellation.lines) {
        _drawConstellationLine(
          canvas: canvas,
          paint: paint,
          line: line,
          starWorldPositions: starWorldPositions,
          center: center,
          size: size,
        );
      }
    }
  }

  Constellation? _selectedConstellation() {
    if (selectedStarId == null) {
      return null;
    }

    SkyStar? selectedStar;

    for (final star in stars) {
      if (star.id == selectedStarId) {
        selectedStar = star;
        break;
      }
    }

    final constellationId = selectedStar?.constellation;

    if (constellationId == null) {
      return null;
    }

    for (final constellation in constellations) {
      if (constellation.id == constellationId) {
        return constellation;
      }
    }

    return null;
  }

  void _drawHighlightedConstellation(
    Canvas canvas,
    Map<int, List<double>> starWorldPositions,
    Size size,
    Offset center,
    Constellation constellation,
  ) {
    final paint = Paint()
      ..color = AppColors.accentBright
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    for (final line in constellation.lines) {
      _drawConstellationLine(
        canvas: canvas,
        paint: paint,
        line: line,
        starWorldPositions: starWorldPositions,
        center: center,
        size: size,
      );
    }
  }

  void _drawConstellationLine({
    required Canvas canvas,
    required Paint paint,
    required List<int> line,
    required Map<int, List<double>> starWorldPositions,
    required Offset center,
    required Size size,
  }) {
    if (line.length < 2) {
      return;
    }

    for (var i = 0; i < line.length - 1; i++) {
      final first = starWorldPositions[line[i]];
      final second = starWorldPositions[line[i + 1]];

      if (first == null || second == null) {
        continue;
      }

      final segment = _projectConstellationSegment(
        first,
        second,
        center,
        size,
      );

      if (segment == null) {
        continue;
      }

      canvas.drawLine(
        segment.$1,
        segment.$2,
        paint,
      );
    }
  }

  // Allows constellation endpoints to move outside the screen naturally.
  //
  // If a segment crosses behind the camera, it is clipped at the camera
  // plane so perspective does not produce a huge line across the sky.
  (Offset, Offset)? _projectConstellationSegment(
    List<double> first,
    List<double> second,
    Offset center,
    Size size,
  ) {
    final firstCamera =
        _cameraCoordinates(first);

    final secondCamera =
        _cameraCoordinates(second);

    final firstFront =
        firstCamera.depth > 0;

    final secondFront =
        secondCamera.depth > 0;

    if (!firstFront && !secondFront) {
      return null;
    }

    var a = firstCamera;
    var b = secondCamera;

    if (firstFront != secondFront) {
      final clipped =
          _clipAgainstCameraPlane(
        firstCamera,
        secondCamera,
      );

      if (clipped == null) {
        return null;
      }

      if (firstFront) {
        a = firstCamera;
        b = clipped;
      } else {
        a = clipped;
        b = secondCamera;
      }
    }

    final firstPoint = _projectCameraPoint(
      a,
      center,
      size,
    );

    final secondPoint = _projectCameraPoint(
      b,
      center,
      size,
    );

    return (
      firstPoint,
      secondPoint,
    );
  }

  _CameraPoint? _clipAgainstCameraPlane(
    _CameraPoint first,
    _CameraPoint second,
  ) {
    const minimumDepth = 0.001;

    final depthDifference =
        second.depth - first.depth;

    if (depthDifference == 0) {
      return null;
    }

    final t =
        (minimumDepth - first.depth) /
            depthDifference;

    if (t < 0 || t > 1) {
      return null;
    }

    return _CameraPoint(
      x: first.x +
          (second.x - first.x) * t,
      y: first.y +
          (second.y - first.y) * t,
      depth: minimumDepth,
    );
  }

  Offset _projectCameraPoint(
    _CameraPoint point,
    Offset center,
    Size size,
  ) {
    final focalLength =
        size.height * 0.5;

    return Offset(
      center.dx +
          focalLength *
              point.x /
              point.depth,
      center.dy -
          focalLength *
              point.y /
              point.depth,
    );
  }

  _CameraPoint _cameraCoordinates(
    List<double> world,
  ) {
    final worldX = world[0];
    final worldY = world[1];
    final worldZ = world[2];

    final x =
        worldX * orientation.rightX +
            worldY * orientation.rightY +
            worldZ * orientation.rightZ;

    final y =
        worldX * orientation.upX +
            worldY * orientation.upY +
            worldZ * orientation.upZ;

    final depth =
        worldX * orientation.backX +
            worldY * orientation.backY +
            worldZ * orientation.backZ;

    return _CameraPoint(
      x: x,
      y: y,
      depth: depth,
    );
  }

  void _drawStars(
    Canvas canvas,
    Map<int, Offset> positions,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final star in stars) {
      final position = positions[star.id];

      if (position == null) {
        continue;
      }

      final radius = _starRadius(star.magnitude);

      if (objectSelectionEnabled && star.isInteractable) {
        final isSelected = star.id == selectedStarId;

        highlightPaint.color = isSelected
            ? AppColors.accentBright
            : AppColors.accent.withValues(alpha: 0.55);

        canvas.drawCircle(
          position,
          radius + (isSelected ? 7 : 5),
          highlightPaint,
        );
      }

      paint.color = _starColor(
        star.spectralType,
      );

      canvas.drawCircle(
        position,
        radius,
        paint,
      );
    }
  }

  double _starRadius(double magnitude) {
    // Brighter stars get a little more visual weight.
    final radius =
        2.8 - magnitude * 0.32;

    return radius.clamp(
      0.7,
      2.8,
    );
  }

  Color _starColor(
    String? spectralType,
  ) {
    if (spectralType == null ||
        spectralType.isEmpty) {
      return Colors.white;
    }

    switch (spectralType[0].toUpperCase()) {
      case 'O':
        return const Color(0xFF9BB0FF);

      case 'B':
        return const Color(0xFFAABFFF);

      case 'A':
        return const Color(0xFFCAD8FF);

      case 'F':
        return const Color(0xFFF8F7FF);

      case 'G':
        return const Color(0xFFFFF4EA);

      case 'K':
        return const Color(0xFFFFD2A1);

      case 'M':
        return const Color(0xFFFFCC6F);

      default:
        return Colors.white;
    }
  }

  // Draws the horizon as a series of independently clipped segments
  // (reusing the same camera-plane clipping as constellation lines)
  // instead of one continuous Path. This avoids a stray line being
  // drawn across the screen when part of the ring dips behind the
  // camera.
  void _drawHorizon(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.55)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    List<double>? previous;

    for (var azimuth = 0.0;
        azimuth <= 360.0;
        azimuth += 1.0) {
      final world =
          SkyCoordinates.horizontalToVector(
        azimuth: azimuth,
        altitude: 0,
      );

      if (previous != null) {
        final segment = _projectConstellationSegment(
          previous,
          world,
          center,
          size,
        );

        if (segment != null) {
          canvas.drawLine(
            segment.$1,
            segment.$2,
            paint,
          );
        }
      }

      previous = world;
    }
  }

  // Cardinal letters, positioned right on the horizon ring at their
  // azimuth (N=0, E=90, S=180, W=270), reusing the same star
  // projection so they track device orientation like everything else.
  static const _compassLabels = [
    (0.0, 'N'),
    (90.0, 'E'),
    (180.0, 'S'),
    (270.0, 'W'),
  ];

  void _drawCompassLabels(
    Canvas canvas,
    Offset center,
    Size size,
  ) {
    for (final (azimuth, label) in _compassLabels) {
      final world = SkyCoordinates.horizontalToVector(
        azimuth: azimuth,
        altitude: 0,
      );

      final point = _projectStar(world, center, size);

      if (point == null) {
        continue;
      }

      _drawCompassLabel(canvas, label, point);
    }
  }

  void _drawCompassLabel(
    Canvas canvas,
    String label,
    Offset position,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: AppColors.accentBright,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      position -
          Offset(
            textPainter.width / 2,
            textPainter.height / 2,
          ),
    );
  }

  // Leaves a small gap at the center so the exact point being aimed at
  // isn't covered by the reticle itself.
  void _drawCenterMarker(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.65)
      ..strokeWidth = 1.0;

    const gap = 3.0;
    const length = 8.0;

    canvas.drawLine(
      Offset(center.dx - length, center.dy),
      Offset(center.dx - gap, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + gap, center.dy),
      Offset(center.dx + length, center.dy),
      paint,
    );

    canvas.drawLine(
      Offset(center.dx, center.dy - length),
      Offset(center.dx, center.dy - gap),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + gap),
      Offset(center.dx, center.dy + length),
      paint,
    );
  }

  void _drawBackground(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = Colors.black;

    canvas.drawRect(
      Offset.zero & size,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant SkyPainter oldDelegate,
  ) {
    return oldDelegate.orientation !=
            orientation ||
        oldDelegate.stars != stars ||
        oldDelegate.starVectors != starVectors ||
        oldDelegate.constellations !=
            constellations ||
        oldDelegate.showHorizon !=
            showHorizon ||
        oldDelegate.showConstellations !=
            showConstellations ||
        oldDelegate.objectSelectionEnabled !=
            objectSelectionEnabled ||
        oldDelegate.selectedStarId != selectedStarId;
  }
}

class _CameraPoint {
  const _CameraPoint({
    required this.x,
    required this.y,
    required this.depth,
  });

  final double x;
  final double y;
  final double depth;
}