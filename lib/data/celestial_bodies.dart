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
  info: 'The Sun is the star at the center of the Solar System. It is a nearly perfect sphere of hot plasma, with internal convective motion that generates a magnetic field via a dynamo process. It is by far the most important source of energy for life on Earth.',
);

/// Every celestial body SkyBloc computes a position/trajectory for.
final List<CelestialBody> registeredCelestialBodies = [
  sunBody,
];

CelestialBody? celestialBodyById(String id) {
  for (final body in registeredCelestialBodies) {
    if (body.id == id) {
      return body;
    }
  }

  return null;
}
