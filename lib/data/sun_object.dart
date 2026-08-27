import '../models/celestial_object.dart';
import '../models/celestial_position.dart';

CelestialObject buildSunCelestialObject({
  double? ra,
  double? dec,
  CelestialPosition? position,
}) {
  return CelestialObject(
    id: 'sun',
    name: 'Sun',
    type: CelestialObjectType.sun,
    description: 'G2V main-sequence star',
    facts: [
      const MapEntry('Apparent magnitude', '-26.74'),
      const MapEntry('Distance', '1.00 AU (149.6 million km)'),
      if (ra != null) MapEntry('Right ascension', '${ra.toStringAsFixed(2)}°'),
      if (dec != null) MapEntry('Declination', '${dec.toStringAsFixed(2)}°'),
      if (position != null) ...[
        MapEntry('Altitude', '${position.altitude.toStringAsFixed(2)}°'),
        MapEntry('Azimuth', '${position.azimuth.toStringAsFixed(2)}°'),
      ],
      const MapEntry('Info', 'Position updates as the Earth rotates, so the Sun\'s position changes throughout the day. \nThe Sun is the star at the center of our solar system and is responsible for providing light and heat to Earth. It is a G-type main-sequence star (G2V) and is approximately 4.6 billion years old. The Sun\'s energy output drives weather, climate, and supports life on Earth.'),
    ],
  );
}
