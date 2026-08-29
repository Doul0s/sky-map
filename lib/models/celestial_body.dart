import '../astronomy/celestial_calculator.dart';
import 'celestial_object.dart';
import 'celestial_position.dart';

/// Static (non-time-varying) definition of a celestial object that
/// participates in the generic position/trajectory pipeline.
///
/// This is deliberately NOT the same thing as [CelestialObject].
/// [CelestialObject] is a display-ready snapshot for the info panel,
/// built fresh each time one is needed — some of its facts (altitude,
/// azimuth, and for the Moon, phase) change every position update, so
/// it can't be stored as-is. [CelestialBody] is the fixed part: id,
/// type, unchanging facts, and how to calculate the body's position.
class CelestialBody {
  final String id;
  final String displayName;
  final CelestialObjectType type;
  final String description;
  final List<MapEntry<String, String>> staticFacts;
  final CelestialCalculator calculator;

  /// Optional per-tick fact computation for bodies whose display facts
  /// change over time beyond just position (e.g. the Moon's phase and
  /// illuminated %). Null for bodies that don't need this (Sun) —
  /// SkyBloc calls this once per position update and stores the result
  /// on [CelestialRuntime.extraFacts] rather than recomputing it here,
  /// since [buildInfo] is called from the UI layer and shouldn't be
  /// doing astronomical calculation.
  final List<MapEntry<String, String>> Function(DateTime utc)? extraFacts;

  const CelestialBody({
    required this.id,
    required this.displayName,
    required this.type,
    required this.description,
    required this.staticFacts,
    required this.calculator,
    this.extraFacts,
  });

  /// Builds a display-ready [CelestialObject] for the info panel,
  /// merging this body's fixed facts with live data. Everything except
  /// [staticFacts] is omitted when null (e.g. before the first position
  /// update completes).
  CelestialObject buildInfo({
    double? ra,
    double? dec,
    CelestialPosition? position,
    double? distanceKm,
    List<MapEntry<String, String>> extraFacts = const [],
  }) {
    return CelestialObject(
      id: id,
      name: displayName,
      type: type,
      description: description,
      facts: [
        ...staticFacts,
        ...extraFacts,
        if (distanceKm != null)
          MapEntry('Distance', '${_formatWithCommas(distanceKm.round())} km'),
        if (ra != null)
          MapEntry('Right ascension', '${ra.toStringAsFixed(2)}°'),
        if (dec != null)
          MapEntry('Declination', '${dec.toStringAsFixed(2)}°'),
        if (position != null) ...[
          MapEntry('Altitude', '${position.altitude.toStringAsFixed(2)}°'),
          MapEntry('Azimuth', '${position.azimuth.toStringAsFixed(2)}°'),
        ],
      ],
    );
  }

  static String _formatWithCommas(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }

      buffer.write(digits[i]);
    }

    return buffer.toString();
  }
}
