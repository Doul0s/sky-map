import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../astronomy/sky_coordinates.dart';
import '../models/celestial_body.dart';
import '../models/celestial_object.dart';
import '../models/celestial_runtime.dart';
import '../models/celestial_trajectory.dart';
import '../models/constellation.dart';
import '../models/device_orientation.dart';
import '../models/sky_star.dart';
import 'camera_projector.dart';

class SkyPainter extends CustomPainter {
  final DeviceOrientation orientation;
  final List<SkyStar> stars;
  final List<WorldVector> starVectors;
  final List<Constellation> constellations;

  /// Celestial bodies to draw and their live
  /// positions/trajectories, keyed by CelestialBody.id.
  final List<CelestialBody> celestialBodies;
  final Map<String, CelestialRuntime> celestialRuntimes;

  /// Which celestial body is selected, if any. Its trajectory is drawn;
  /// others are not.
  final String? selectedCelestialObjectId;

  final bool showHorizon;
  final bool showConstellations;
  final bool objectSelectionEnabled;
  final int? selectedStarId;

  const SkyPainter({
    required this.orientation,
    required this.stars,
    required this.starVectors,
    required this.constellations,
    this.celestialBodies = const [],
    this.celestialRuntimes = const {},
    this.selectedCelestialObjectId,
    this.showHorizon = true,
    this.showConstellations = true,
    this.objectSelectionEnabled = false,
    this.selectedStarId,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    _drawBackground(
      canvas,
      size,
    );

    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final starWorldVectors =
        _starWorldVectorsById();

    final starPositions =
        _projectStars(
      starWorldVectors,
      center,
      size,
    );

    final selectedRuntime = selectedCelestialObjectId != null
        ? celestialRuntimes[selectedCelestialObjectId]
        : null;

    if (selectedRuntime != null && selectedRuntime.trajectory.isNotEmpty) {
      _drawTrajectory(
        canvas,
        selectedRuntime.trajectory,
        center,
        size,
      );
    }

    _drawCelestialObjects(
      canvas,
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

    // The selected star's constellation is always shown brighter,
    // even when normal constellation rendering is disabled.
    final highlightedConstellation =
        _selectedConstellation();

    if (highlightedConstellation !=
        null) {
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

    _drawCenterMarker(
      canvas,
      size,
    );
  }

  Map<int, List<double>>
      _starWorldVectorsById() {
    final result =
        <int, List<double>>{};

    final count = math.min(
      stars.length,
      starVectors.length,
    );

    for (var i = 0; i < count; i++) {
      result[stars[i].id] =
          starVectors[i];
    }

    return result;
  }

  Map<int, Offset> _projectStars(
    Map<int, List<double>>
        starWorldVectors,
    Offset center,
    Size size,
  ) {
    final result =
        <int, Offset>{};

    for (final entry
        in starWorldVectors.entries) {
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
    final focalLength =
        size.height * 0.5;

    final point = CameraProjector.project(
      world,
      orientation,
      center,
      focalLength,
    );

    if (point == null) {
      return null;
    }

    if (point.dx < -4 ||
        point.dx > size.width + 4 ||
        point.dy < -4 ||
        point.dy > size.height + 4) {
      return null;
    }

    return point;
  }

  /// Draws the selected celestial object's apparent sky trajectory —
  /// the sequence of sky directions it passes through over the sampled
  /// time window.
  void _drawTrajectory(
    Canvas canvas,
    CelestialTrajectory trajectory,
    Offset center,
    Size size,
  ) {
    if (trajectory.points.length < 2) {
      return;
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(
        0xFFFFB300,
      ).withValues(
        alpha: 0.08,
      );

    final trajectoryPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(
        0xFFFFD95A,
      ).withValues(
        alpha: 0.70,
      );

    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(
        0xFFFFD95A,
      ).withValues(
        alpha: 0.55,
      );

    for (var i = 0;
        i < trajectory.points.length - 1;
        i++) {
      final first =
          trajectory.points[i];

      final second =
          trajectory.points[i + 1];

      /*
       * Use the same camera-plane clipping as constellation lines:
       * a plain drawLine() between projected points would draw
       * incorrect lines where the trajectory crosses behind the
       * observer.
       */
      final segment =
          _projectConstellationSegment(
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
        glowPaint,
      );

      canvas.drawLine(
        segment.$1,
        segment.$2,
        trajectoryPaint,
      );
    }

    for (final world
        in trajectory.points) {
      final point = _projectStar(
        world,
        center,
        size,
      );

      if (point == null) {
        continue;
      }

      canvas.drawCircle(
        point,
        1.4,
        pointPaint,
      );
    }
  }

  /// Draws every registered celestial body that has a computed runtime
  /// position, dispatching to the appropriate visual by [body.type].
  void _drawCelestialObjects(
    Canvas canvas,
    Offset center,
    Size size,
  ) {
    for (final body in celestialBodies) {
      final runtime = celestialRuntimes[body.id];

      if (runtime == null) {
        continue;
      }

      final isSelected = selectedCelestialObjectId == body.id;

      switch (body.type) {
        case CelestialObjectType.sun:
          _drawSun(
            canvas,
            runtime.vector,
            center,
            size,
            isSelected: isSelected,
          );
          break;

        default:
          _drawGenericCelestialMarker(
            canvas,
            runtime.vector,
            center,
            size,
            isSelected: isSelected,
          );
      }
    }
  }

  void _drawSun(
    Canvas canvas,
    WorldVector world,
    Offset center,
    Size size, {
    required bool isSelected,
  }) {
    final point = _projectStar(
      world,
      center,
      size,
    );

    if (point == null) {
      return;
    }

    // The Sun is drawn much larger than its real angular size —
    // this is a UI marker, not a physical disk.
    final glowRadius =
        isSelected ? 34.0 : 26.0;

    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(
        0xFFFFC857,
      ).withValues(
        alpha: isSelected
            ? 0.16
            : 0.10,
      );

    canvas.drawCircle(
      point,
      glowRadius,
      glowPaint,
    );

    final outerGlowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(
        0xFFFFB300,
      ).withValues(
        alpha: isSelected
            ? 0.12
            : 0.08,
      );

    canvas.drawCircle(
      point,
      isSelected
          ? 23
          : 18,
      outerGlowPaint,
    );

    if (isSelected) {
      final selectionPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(
          0xFFFFE082,
        ).withValues(
          alpha: 0.85,
        );

      canvas.drawCircle(
        point,
        12,
        selectionPaint,
      );
    }

    final sunPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(
        0xFFFFD95A,
      );

    canvas.drawCircle(
      point,
      7,
      sunPaint,
    );

    final corePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(
        0xFFFFF3B0,
      );

    canvas.drawCircle(
      point,
      4,
      corePaint,
    );
  }

  /// Fallback visual for celestial body types without a dedicated
  /// rendering case.
  void _drawGenericCelestialMarker(
    Canvas canvas,
    WorldVector world,
    Offset center,
    Size size, {
    required bool isSelected,
  }) {
    final point = _projectStar(
      world,
      center,
      size,
    );

    if (point == null) {
      return;
    }

    if (isSelected) {
      final selectionPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.accentBright;

      canvas.drawCircle(
        point,
        10,
        selectionPaint,
      );
    }

    final markerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    canvas.drawCircle(
      point,
      4,
      markerPaint,
    );
  }

  void _drawConstellations(
    Canvas canvas,
    Map<int, List<double>>
        starWorldPositions,
    Size size,
    Offset center,
  ) {
    if (constellations.isEmpty) {
      return;
    }

    final paint = Paint()
      ..color = AppColors.accent
          .withValues(alpha: 0.45)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (final constellation
        in constellations) {
      for (final line
          in constellation.lines) {
        _drawConstellationLine(
          canvas: canvas,
          paint: paint,
          line: line,
          starWorldPositions:
              starWorldPositions,
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

    final constellationId =
        selectedStar?.constellation;

    if (constellationId == null) {
      return null;
    }

    for (final constellation
        in constellations) {
      if (constellation.id ==
          constellationId) {
        return constellation;
      }
    }

    return null;
  }

  void _drawHighlightedConstellation(
    Canvas canvas,
    Map<int, List<double>>
        starWorldPositions,
    Size size,
    Offset center,
    Constellation constellation,
  ) {
    final paint = Paint()
      ..color =
          AppColors.accentBright
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    for (final line
        in constellation.lines) {
      _drawConstellationLine(
        canvas: canvas,
        paint: paint,
        line: line,
        starWorldPositions:
            starWorldPositions,
        center: center,
        size: size,
      );
    }
  }

  void _drawConstellationLine({
    required Canvas canvas,
    required Paint paint,
    required List<int> line,
    required Map<int, List<double>>
        starWorldPositions,
    required Offset center,
    required Size size,
  }) {
    if (line.length < 2) {
      return;
    }

    for (var i = 0;
        i < line.length - 1;
        i++) {
      final first =
          starWorldPositions[line[i]];

      final second =
          starWorldPositions[
              line[i + 1]];

      if (first == null ||
          second == null) {
        continue;
      }

      final segment =
          _projectConstellationSegment(
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

  (Offset, Offset)?
      _projectConstellationSegment(
    List<double> first,
    List<double> second,
    Offset center,
    Size size,
  ) {
    final firstCamera =
        CameraProjector.toCameraSpace(first, orientation);

    final secondCamera =
        CameraProjector.toCameraSpace(second, orientation);

    final firstFront =
        firstCamera.depth > 0;

    final secondFront =
        secondCamera.depth > 0;

    if (!firstFront &&
        !secondFront) {
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

    final focalLength =
        size.height * 0.5;

    final firstPoint =
        CameraProjector.projectCameraPoint(
      a,
      center,
      focalLength,
    );

    final secondPoint =
        CameraProjector.projectCameraPoint(
      b,
      center,
      focalLength,
    );

    return (
      firstPoint,
      secondPoint,
    );
  }

  CameraPoint? _clipAgainstCameraPlane(
    CameraPoint first,
    CameraPoint second,
  ) {
    const minimumDepth = 0.001;

    final depthDifference =
        second.depth -
        first.depth;

    if (depthDifference == 0) {
      return null;
    }

    final t =
        (minimumDepth -
                first.depth) /
            depthDifference;

    if (t < 0 || t > 1) {
      return null;
    }

    return CameraPoint(
      x: first.x +
          (second.x - first.x) * t,
      y: first.y +
          (second.y - first.y) * t,
      depth: minimumDepth,
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
      final position =
          positions[star.id];

      if (position == null) {
        continue;
      }

      final radius =
          _starRadius(
        star.magnitude,
      );

      if (objectSelectionEnabled &&
          star.isInteractable) {
        final isSelected =
            star.id == selectedStarId;

        highlightPaint.color =
            isSelected
                ? AppColors
                    .accentBright
                : AppColors.accent
                    .withValues(
                    alpha: 0.55,
                  );

        canvas.drawCircle(
          position,
          radius +
              (isSelected
                  ? 7
                  : 5),
          highlightPaint,
        );
      }

      paint.color =
          _starColor(
        star.spectralType,
      );

      canvas.drawCircle(
        position,
        radius,
        paint,
      );
    }
  }

  double _starRadius(
    double magnitude,
  ) {
    final radius =
        2.8 -
        magnitude * 0.32;

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

    switch (
        spectralType[0]
            .toUpperCase()) {
      case 'O':
        return const Color(
          0xFF9BB0FF,
        );

      case 'B':
        return const Color(
          0xFFAABFFF,
        );

      case 'A':
        return const Color(
          0xFFCAD8FF,
        );

      case 'F':
        return const Color(
          0xFFF8F7FF,
        );

      case 'G':
        return const Color(
          0xFFFFF4EA,
        );

      case 'K':
        return const Color(
          0xFFFFD2A1,
        );

      case 'M':
        return const Color(
          0xFFFFCC6F,
        );

      default:
        return Colors.white;
    }
  }

  static final List<List<double>>
      _horizonWorldVectors = [
    for (var azimuth = 0.0;
        azimuth <= 360.0;
        azimuth += 1.0)
      SkyCoordinates
          .horizontalToVector(
        azimuth: azimuth,
        altitude: 0,
      ),
  ];

  void _drawHorizon(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final paint = Paint()
      ..color = AppColors.accent
          .withValues(alpha: 0.55)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (var i = 0;
        i <
            _horizonWorldVectors
                    .length -
                1;
        i++) {
      final segment =
          _projectConstellationSegment(
        _horizonWorldVectors[i],
        _horizonWorldVectors[
            i + 1],
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
  }

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
    for (final (
      azimuth,
      label
    ) in _compassLabels) {
      final world =
          SkyCoordinates
              .horizontalToVector(
        azimuth: azimuth,
        altitude: 0,
      );

      final point = _projectStar(
        world,
        center,
        size,
      );

      if (point == null) {
        continue;
      }

      _drawCompassLabel(
        canvas,
        label,
        point,
      );
    }
  }

  void _drawCompassLabel(
    Canvas canvas,
    String label,
    Offset position,
  ) {
    final textPainter =
        TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color:
              AppColors.accentBright,
          fontSize: 13,
          fontWeight:
              FontWeight.w700,
          shadows: const [
            Shadow(
              color: Colors.black,
              blurRadius: 4,
            ),
          ],
        ),
      ),
      textDirection:
          TextDirection.ltr,
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

  void _drawCenterMarker(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final paint = Paint()
      ..color = AppColors.accent
          .withValues(alpha: 0.65)
      ..strokeWidth = 1.0;

    const gap = 3.0;
    const length = 8.0;

    canvas.drawLine(
      Offset(
        center.dx - length,
        center.dy,
      ),
      Offset(
        center.dx - gap,
        center.dy,
      ),
      paint,
    );

    canvas.drawLine(
      Offset(
        center.dx + gap,
        center.dy,
      ),
      Offset(
        center.dx + length,
        center.dy,
      ),
      paint,
    );

    canvas.drawLine(
      Offset(
        center.dx,
        center.dy - length,
      ),
      Offset(
        center.dx,
        center.dy - gap,
      ),
      paint,
    );

    canvas.drawLine(
      Offset(
        center.dx,
        center.dy + gap,
      ),
      Offset(
        center.dx,
        center.dy + length,
      ),
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
        oldDelegate.starVectors !=
            starVectors ||
        oldDelegate.constellations !=
            constellations ||
        oldDelegate.celestialBodies !=
            celestialBodies ||
        oldDelegate.celestialRuntimes !=
            celestialRuntimes ||
        oldDelegate.selectedCelestialObjectId !=
            selectedCelestialObjectId ||
        oldDelegate.showHorizon !=
            showHorizon ||
        oldDelegate.showConstellations !=
            showConstellations ||
        oldDelegate.objectSelectionEnabled !=
            objectSelectionEnabled ||
        oldDelegate.selectedStarId !=
            selectedStarId;
  }
}
