import '../astronomy/moon_calculator.dart';
import '../astronomy/sun_calculator.dart';
import '../models/celestial_body.dart';
import '../models/celestial_object.dart';

final CelestialBody sunBody = CelestialBody(
  id: 'sun',
  displayName: 'Sun',
  type: CelestialObjectType.sun,
  description: 'G2V main-sequence star',
  staticFacts: const [
    MapEntry('Apparent magnitude', '-26.74'),
    MapEntry('Distance', '1.00 AU (149.6 million km)'),
  ],
  calculator: const SunCalculator(),
);

final CelestialBody moonBody = CelestialBody(
  id: 'moon',
  displayName: 'Moon',
  type: CelestialObjectType.moon,
  description: "Earth's natural satellite",
  staticFacts: const [
    MapEntry('Mean distance', '384,400 km'),
    MapEntry('Orbital period', '27.3 days'),
    MapEntry('Diameter', '3,474 km'),
  ],
  calculator: const MoonCalculator(),
  extraFacts: (utc) => const MoonCalculator().phaseFacts(utc),
);

/// Every celestial body SkyBloc computes a position/trajectory for.
final List<CelestialBody> registeredCelestialBodies = [
  sunBody,
  moonBody,
];

CelestialBody? celestialBodyById(String id) {
  for (final body in registeredCelestialBodies) {
    if (body.id == id) {
      return body;
    }
  }

  return null;
}
