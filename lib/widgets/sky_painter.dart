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

  /// Celestial bodies to draw (Sun today; Moon/Mars/Venus later) and
  /// their live positions/trajectories, keyed by CelestialBody.id.
  final List<CelestialBody> celestialBodies;
  final Map<String, CelestialRuntime> celestialRuntimes;

  /// Which celestial body is selected, if any. Its trajectory is drawn;
  /// others are not.
  final String? selectedCelestialObjectId;

  final bool showHorizon;
  final bool showConstellations;
  final bool objectSelectionEnabled;
  final int? selectedStarId;

  // Static colour map for trajectory hues, keyed by celestial body id.
  static const Map<String, Color> _trajectoryColors = {
    'sun': Color(0xFFFFB300),      // warm gold
    'moon': Color(0xFFB0C4DE),     // cool silver‑blue
    'mercury': Color(0xFFB8B0A8),  // pale grey
    'venus': Color(0xFFE6E6A0),    // pale yellow
    'mars': Color(0xFFE27B58),     // rust orange
    'jupiter': Color(0xFFE0C097),  // banded tan
    'saturn': Color(0xFFEAD6A5),   // pale gold
    'uranus': Color(0xFF9FE0E0),   // pale cyan
    'neptune': Color(0xFF6B8FE0),  // deep blue
  };

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

    /*
     * Built once per frame and shared between
     * star dots and constellation lines.
     */
    final starWorldVectors =
        _starWorldVectorsById();

    final starPositions =
        _projectStars(
      starWorldVectors,
      center,
      size,
    );

    /*
     * Draw the selected celestial object's trajectory before the
     * object itself, so the object sits visually on top of its
     * highlighted path. Only the selected object's trajectory is
     * drawn — others stay hidden until selected.
     */
    final selectedRuntime = selectedCelestialObjectId != null
        ? celestialRuntimes[selectedCelestialObjectId]
        : null;

    if (selectedRuntime != null && selectedRuntime.trajectory.isNotEmpty) {
      // Look up the colour for this body; fallback to white.
      final color = _trajectoryColors[selectedCelestialObjectId!] ?? Colors.white;
      _drawTrajectory(
        canvas,
        selectedRuntime.trajectory,
        center,
        size,
        color,
      );
    }

    /*
     * Draw celestial objects before the stars so the star field
     * remains visually rich around them.
     */
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

    /*
     * The selected star's constellation is always
     * shown brighter, even if normal constellation
     * rendering is disabled.
     */
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

    /*
     * Keep the aiming point above everything else.
     */
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

  /// Draws the selected celestial object's apparent sky trajectory.
  ///
  /// This is NOT the physical orbit of the object — it's the sequence
  /// of sky directions it passes through over the sampled time window.
  void _drawTrajectory(
    Canvas canvas,
    CelestialTrajectory trajectory,
    Offset center,
    Size size,
    Color color, // new parameter
  ) {
    if (trajectory.points.length < 2) {
      return;
    }

    /*
     * Soft outer glow – tinted with the object's colour.
     */
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(
        alpha: 0.08,
      );

    /*
     * Main trajectory line.
     */
    final trajectoryPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(
        alpha: 0.70,
      );

    /*
     * Small points sampled along the trajectory.
     */
    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(
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
       * Use the same camera-plane clipping used
       * by constellation lines.
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

    /*
     * Draw the trajectory sample points.
     */
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
  ///
  /// Adding Moon/Mars/Venus later means adding a case here — nothing
  /// about how objects reach this point changes.
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

        case CelestialObjectType.moon:
          _drawMoon(
            canvas,
            runtime.vector,
            center,
            size,
            isSelected: isSelected,
          );
          break;

        default:
          _drawPlanet(
            canvas,
            runtime.vector,
            center,
            size,
            id: body.id,
            color: _trajectoryColors[body.id] ?? Colors.white,
            isSelected: isSelected,
          );
      }
    }
  }

  /// Deliberately a plain circle, not yet an illuminated crescent/gibbous
  /// shape — verify the Moon's *position* tracks correctly first (the
  /// thing that's actually easy to get subtly wrong: parallax, hour
  /// angle, obliquity). Phase-accurate rendering is a separate, purely
  /// cosmetic follow-up once position is confirmed against a real sky
  /// app.
  /// Draws the Moon with a deliberately different visual language from the Sun.
  ///
  /// The Sun is warm, energetic and strongly glowing. The Moon is cool,
  /// quieter and slightly smaller, with a soft halo and subtle surface
  /// detail. The actual illuminated phase is kept out of this method until
  /// the Moon phase fraction is passed into the painter.
  void _drawMoon(
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

    // Cool, restrained halo. This intentionally contrasts with the
    // stronger yellow/orange Sun glow.
    final haloPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(
        0xFFBFD4E6,
      ).withValues(
        alpha: isSelected ? 0.18 : 0.10,
      );

    canvas.drawCircle(
      point,
      isSelected ? 16.0 : 13.0,
      haloPaint,
    );

    // Selection ring.
    if (isSelected) {
      final selectionPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(
          0xFFE8F1F8,
        ).withValues(alpha: 0.9);

      canvas.drawCircle(
        point,
        10.5,
        selectionPaint,
      );
    }

    // Main lunar disk.
    final moonPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(
        0xFFE8ECF1,
      );

    canvas.drawCircle(
      point,
      6.0,
      moonPaint,
    );

    // Very subtle surface shading. This is intentionally not presented as
    // the real lunar phase; the phase geometry will be driven by the
    // calculated illuminated fraction once that value is supplied to the
    // painter.
    final shadePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(
        0xFF8996A3,
      ).withValues(alpha: 0.18);

    canvas.drawCircle(
      Offset(
        point.dx - 1.5,
        point.dy + 0.5,
      ),
      2.2,
      shadePaint,
    );

    // A couple of tiny crater hints keep the Moon visually distinct without
    // turning it into a detailed texture.
    final craterPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(
        0xFF7F8B97,
      ).withValues(alpha: 0.18);

    canvas.drawCircle(
      Offset(
        point.dx + 1.7,
        point.dy - 1.5,
      ),
      0.8,
      craterPaint,
    );

    canvas.drawCircle(
      Offset(
        point.dx + 0.7,
        point.dy + 2.0,
      ),
      0.65,
      craterPaint,
    );
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

    /*
     * When selected, increase the Sun's visual presence.
     *
     * The visual size is deliberately much larger than
     * the real angular size of the Sun. This is a UI marker,
     * not a physical disk.
     */
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

    /*
     * Selected Sun gets a subtle ring.
     */
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

  /// Visual for every planet: a shaded disk rather than a flat dot, so
  /// each body reads as a small sphere instead of a marker pin. Kept
  /// deliberately simple — no textures, just a halo, a base colour, a
  /// darker "terminator" shadow on one side, and a small highlight on
  /// the other. Saturn additionally gets a ring, since that's the one
  /// feature that would otherwise make it unrecognisable at this scale.
  void _drawPlanet(
    Canvas canvas,
    WorldVector world,
    Offset center,
    Size size, {
    required String id,
    required Color color,
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

    final radius = _planetRadius(id);

    // Soft halo, tinted by the planet's own colour.
    final haloPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: isSelected ? 0.20 : 0.12);

    canvas.drawCircle(
      point,
      radius * 2.6,
      haloPaint,
    );

    // Saturn's rings sit behind the disk, so the disk covers their
    // middle third — the classic simple "ringed planet" silhouette.
    if (id == 'saturn') {
      _drawSaturnRing(
        canvas,
        point,
        radius,
        color,
      );
    }

    if (isSelected) {
      final selectionPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.accentBright;

      canvas.drawCircle(
        point,
        radius + 6,
        selectionPaint,
      );
    }

    final basePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    canvas.drawCircle(
      point,
      radius,
      basePaint,
    );

    // Darker "terminator" shading on one side of the disk, hinting at a
    // lit sphere rather than a flat circle. Clipped to the disk itself
    // so it never bleeds past the planet's edge.
    canvas.save();
    canvas.clipPath(
      Path()
        ..addOval(
          Rect.fromCircle(center: point, radius: radius),
        ),
    );

    final shadowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.30);

    canvas.drawCircle(
      point.translate(radius * 0.55, radius * 0.4),
      radius * 1.05,
      shadowPaint,
    );

    canvas.restore();

    // Small highlight, opposite the shadow.
    final highlightPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.35);

    canvas.drawCircle(
      point.translate(-radius * 0.35, -radius * 0.35),
      radius * 0.35,
      highlightPaint,
    );
  }

  /// Base disk radius per planet — enough variation to hint that
  /// Jupiter/Saturn are larger than Mercury/Mars, without turning this
  /// into a scale model.
  double _planetRadius(String id) {
    switch (id) {
      case 'jupiter':
        return 4.4;
      case 'saturn':
        return 4.0;
      case 'venus':
        return 3.4;
      case 'uranus':
      case 'neptune':
        return 3.0;
      case 'mars':
        return 2.8;
      case 'mercury':
        return 2.4;
      default:
        return 3.0;
    }
  }

  /// A simple tilted ring, drawn as a stroked oval behind the planet's
  /// disk so the disk hides its middle section.
  void _drawSaturnRing(
    Canvas canvas,
    Offset point,
    double radius,
    Color color,
  ) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.35
      ..color = color.withValues(alpha: 0.55);

    final ringRect = Rect.fromCenter(
      center: point,
      width: radius * 3.6,
      height: radius * 1.1,
    );

    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.rotate(-0.35);
    canvas.translate(-point.dx, -point.dy);

    canvas.drawOval(ringRect, ringPaint);

    canvas.restore();
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
