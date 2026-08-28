import '../astronomy/celestial_calculator.dart';
import 'celestial_object.dart';
import 'celestial_position.dart';

/// Static (non-time-varying) definition of a celestial object that
/// participates in the generic position/trajectory pipeline.
///
/// This is deliberately NOT the same thing as [CelestialObject].
/// [CelestialObject] is a display-ready snapshot for the info panel,
/// built fresh each time one is needed — some of its facts (altitude,
/// azimuth) change every position update, so it can't be stored as-is.
/// [CelestialBody] is the fixed part: id, type, unchanging facts, and
/// how to calculate the body's position.
class CelestialBody {
  final String id;
  final String displayName;
  final CelestialObjectType type;
  final String description;
  final List<MapEntry<String, String>> staticFacts;
  final CelestialCalculator calculator;
  final String info;

  const CelestialBody({
    required this.id,
    required this.displayName,
    required this.type,
    required this.description,
    required this.staticFacts,
    required this.calculator,
    required this.info,
  });

  /// Builds a display-ready [CelestialObject] for the info panel,
  /// merging this body's fixed facts with live position data. [ra],
  /// [dec], and [position] are omitted from the facts list when null
  /// (e.g. before the first position update completes).
  CelestialObject buildInfo({
    double? ra,
    double? dec,
    CelestialPosition? position,
  }) {
    return CelestialObject(
      id: id,
      name: displayName,
      type: type,
      description: description,
      facts: [
        ...staticFacts,
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
}
