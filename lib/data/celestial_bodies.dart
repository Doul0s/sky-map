import '../astronomy/moon_calculator.dart';
import '../astronomy/planet_calculator.dart';
import '../astronomy/sun_calculator.dart';
import '../models/celestial_body.dart';
import '../models/celestial_object.dart';

// ----------------------------------------------------------------------
// Sun
// ----------------------------------------------------------------------
final CelestialBody sunBody = CelestialBody(
  id: 'sun',
  displayName: 'Sun',
  type: CelestialObjectType.sun,
  description: 'G2V main‑sequence star',
  staticFacts: const [
    MapEntry('Apparent magnitude', '-26.74'),
    MapEntry('Distance', '1.00 AU (149.6 million km)'),
  ],
  calculator: const SunCalculator(),
);

// ----------------------------------------------------------------------
// Moon
// ----------------------------------------------------------------------
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

// ----------------------------------------------------------------------
// Mercury
// ----------------------------------------------------------------------
final CelestialBody mercuryBody = CelestialBody(
  id: 'mercury',
  displayName: 'Mercury',
  type: CelestialObjectType.planet,
  description: 'Smallest planet; closest to the Sun',
  staticFacts: const [
    MapEntry('Orbital period', '87.97 days'),
    MapEntry('Diameter', '4,879 km'),
  ],
  calculator: const PlanetCalculator(
    OrbitalElements(
      a: 0.38709927,
      aDot: 0.00000037,
      e: 0.20563593,
      eDot: 0.00001906,
      inclination: 7.00497902,
      inclinationDot: -0.00594749,
      meanLongitude: 252.25032350,
      meanLongitudeDot: 149472.67411175,
      longitudeOfPerihelion: 77.45779628,
      longitudeOfPerihelionDot: 0.16047689,
      longitudeOfNode: 48.33076593,
      longitudeOfNodeDot: -0.12534081,
    ),
    recommendedStepMinutes: 10, // Mercury moves fast
  ),
);

// ----------------------------------------------------------------------
// Venus
// ----------------------------------------------------------------------
final CelestialBody venusBody = CelestialBody(
  id: 'venus',
  displayName: 'Venus',
  type: CelestialObjectType.planet,
  description: 'Hottest planet due to a runaway greenhouse effect',
  staticFacts: const [
    MapEntry('Orbital period', '224.70 days'),
    MapEntry('Diameter', '12,104 km'),
  ],
  calculator: const PlanetCalculator(
    OrbitalElements(
      a: 0.72333566,
      aDot: 0.00000390,
      e: 0.00677672,
      eDot: -0.00004107,
      inclination: 3.39467605,
      inclinationDot: -0.00078890,
      meanLongitude: 181.97909950,
      meanLongitudeDot: 58517.81538729,
      longitudeOfPerihelion: 131.60246718,
      longitudeOfPerihelionDot: 0.00268329,
      longitudeOfNode: 76.67984255,
      longitudeOfNodeDot: -0.27769418,
    ),
    recommendedStepMinutes: 15, // Venus moves moderately
  ),
);

// ----------------------------------------------------------------------
// Mars
// ----------------------------------------------------------------------
final CelestialBody marsBody = CelestialBody(
  id: 'mars',
  displayName: 'Mars',
  type: CelestialObjectType.planet,
  description: 'The Red Planet, coloured by iron oxide on its surface',
  staticFacts: const [
    MapEntry('Orbital period', '686.98 days'),
    MapEntry('Diameter', '6,779 km'),
  ],
  calculator: const PlanetCalculator(
    OrbitalElements(
      a: 1.52371034,
      aDot: 0.00001847,
      e: 0.09339410,
      eDot: 0.00007882,
      inclination: 1.84969142,
      inclinationDot: -0.00813131,
      meanLongitude: -4.55343205,
      meanLongitudeDot: 19140.30268499,
      longitudeOfPerihelion: -23.94362959,
      longitudeOfPerihelionDot: 0.44441088,
      longitudeOfNode: 49.55953891,
      longitudeOfNodeDot: -0.29257343,
    ),
    recommendedStepMinutes: 30,
  ),
);

// ----------------------------------------------------------------------
// Jupiter
// ----------------------------------------------------------------------
final CelestialBody jupiterBody = CelestialBody(
  id: 'jupiter',
  displayName: 'Jupiter',
  type: CelestialObjectType.planet,
  description: 'Largest planet; a gas giant with a Great Red Spot storm',
  staticFacts: const [
    MapEntry('Orbital period', '11.86 years'),
    MapEntry('Diameter', '139,820 km'),
  ],
  calculator: const PlanetCalculator(
    OrbitalElements(
      a: 5.20288700,
      aDot: -0.00011607,
      e: 0.04838624,
      eDot: -0.00013253,
      inclination: 1.30439695,
      inclinationDot: -0.00183714,
      meanLongitude: 34.39644051,
      meanLongitudeDot: 3034.74612775,
      longitudeOfPerihelion: 14.72847983,
      longitudeOfPerihelionDot: 0.21252668,
      longitudeOfNode: 100.47390909,
      longitudeOfNodeDot: 0.20469106,
    ),
    recommendedStepMinutes: 30,
  ),
);

// ----------------------------------------------------------------------
// Saturn
// ----------------------------------------------------------------------
final CelestialBody saturnBody = CelestialBody(
  id: 'saturn',
  displayName: 'Saturn',
  type: CelestialObjectType.planet,
  description: 'Famous for its extensive ring system',
  staticFacts: const [
    MapEntry('Orbital period', '29.45 years'),
    MapEntry('Diameter', '116,460 km'),
  ],
  calculator: const PlanetCalculator(
    OrbitalElements(
      a: 9.53667594,
      aDot: -0.00125060,
      e: 0.05386179,
      eDot: -0.00050991,
      inclination: 2.48599187,
      inclinationDot: 0.00193609,
      meanLongitude: 49.95424423,
      meanLongitudeDot: 1222.49362201,
      longitudeOfPerihelion: 92.59887831,
      longitudeOfPerihelionDot: -0.41897216,
      longitudeOfNode: 113.66242448,
      longitudeOfNodeDot: -0.28867794,
    ),
    recommendedStepMinutes: 30,
  ),
);

// ----------------------------------------------------------------------
// Uranus
// ----------------------------------------------------------------------
final CelestialBody uranusBody = CelestialBody(
  id: 'uranus',
  displayName: 'Uranus',
  type: CelestialObjectType.planet,
  description: 'An ice giant that rotates almost on its side',
  staticFacts: const [
    MapEntry('Orbital period', '84.02 years'),
    MapEntry('Diameter', '50,724 km'),
  ],
  calculator: const PlanetCalculator(
    OrbitalElements(
      a: 19.18916464,
      aDot: -0.00196176,
      e: 0.04725744,
      eDot: -0.00004397,
      inclination: 0.77263783,
      inclinationDot: -0.00242939,
      meanLongitude: 313.23810451,
      meanLongitudeDot: 428.48202785,
      longitudeOfPerihelion: 170.95427630,
      longitudeOfPerihelionDot: 0.40805281,
      longitudeOfNode: 74.01692503,
      longitudeOfNodeDot: 0.04240589,
    ),
    recommendedStepMinutes: 30,
  ),
);

// ----------------------------------------------------------------------
// Neptune
// ----------------------------------------------------------------------
final CelestialBody neptuneBody = CelestialBody(
  id: 'neptune',
  displayName: 'Neptune',
  type: CelestialObjectType.planet,
  description: 'The most distant major planet; a windy ice giant',
  staticFacts: const [
    MapEntry('Orbital period', '164.79 years'),
    MapEntry('Diameter', '49,244 km'),
  ],
  calculator: const PlanetCalculator(
    OrbitalElements(
      a: 30.06992276,
      aDot: 0.00026291,
      e: 0.00859048,
      eDot: 0.00005105,
      inclination: 1.77004347,
      inclinationDot: 0.00035372,
      meanLongitude: -55.12002969,
      meanLongitudeDot: 218.45945325,
      longitudeOfPerihelion: 44.96476227,
      longitudeOfPerihelionDot: -0.32241464,
      longitudeOfNode: 131.78422574,
      longitudeOfNodeDot: -0.00508664,
    ),
    recommendedStepMinutes: 30,
  ),
);

// ----------------------------------------------------------------------
// Registry and lookup
// ----------------------------------------------------------------------

/// Every celestial body that SkyBloc computes a position/trajectory for.
final List<CelestialBody> registeredCelestialBodies = [
  sunBody,
  moonBody,
  mercuryBody,
  venusBody,
  marsBody,
  jupiterBody,
  saturnBody,
  uranusBody,
  neptuneBody,
];

CelestialBody? celestialBodyById(String id) {
  for (final body in registeredCelestialBodies) {
    if (body.id == id) return body;
  }
  return null;
}
