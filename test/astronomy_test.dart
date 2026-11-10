import 'package:flutter_test/flutter_test.dart';
import 'package:skymap/astronomy/coordinate_converter.dart';
import 'package:skymap/astronomy/moon_calculator.dart';
import 'package:skymap/astronomy/planet_calculator.dart';
import 'package:skymap/astronomy/sky_coordinates.dart';
import 'package:skymap/astronomy/sun_calculator.dart';
import 'package:skymap/data/celestial_bodies.dart';

double _angularDistanceDegrees(double a, double b) {
  final difference = (a - b) % 360.0;
  final wrapped = difference > 180.0 ? difference - 360.0 : difference;
  return wrapped.abs();
}

void main() {
  group('SkyCoordinates.horizontalToVector', () {
    test('maps the cardinal horizon directions to the world axes', () {
      void expectVector(
        List<double> vector,
        double x,
        double y,
        double z,
      ) {
        expect(vector[0], closeTo(x, 1e-9));
        expect(vector[1], closeTo(y, 1e-9));
        expect(vector[2], closeTo(z, 1e-9));
      }

      expectVector(
        SkyCoordinates.horizontalToVector(azimuth: 0, altitude: 0),
        1,
        0,
        0,
      );
      expectVector(
        SkyCoordinates.horizontalToVector(azimuth: 90, altitude: 0),
        0,
        1,
        0,
      );
      expectVector(
        SkyCoordinates.horizontalToVector(azimuth: 180, altitude: 0),
        -1,
        0,
        0,
      );
    });

    test('zenith points along Up', () {
      final vector = SkyCoordinates.horizontalToVector(
        azimuth: 123,
        altitude: 90,
      );

      expect(vector[0], closeTo(0, 1e-9));
      expect(vector[1], closeTo(0, 1e-9));
      expect(vector[2], closeTo(1, 1e-9));
    });
  });

  group('CoordinateConverter', () {
    test('the celestial pole sits at an altitude equal to the latitude', () {
      for (final latitude in [-60.0, -12.5, 0.0, 33.3, 78.0]) {
        final position = CoordinateConverter.equatorialToHorizontal(
          ra: 42.0,
          dec: 90.0,
          latitude: latitude,
          longitude: 13.0,
          utc: DateTime.utc(2026, 3, 20, 12),
        );

        expect(position.altitude, closeTo(latitude, 1e-6));
      }
    });

    test('a star on the meridian south of the zenith has azimuth 180', () {
      const latitude = 40.0;
      const longitude = 0.0;
      final utc = DateTime.utc(2026, 1, 1);

      final julianDate =
          utc.millisecondsSinceEpoch / 86400000.0 + 2440587.5;
      final localSiderealTime =
          (280.46061837 + 360.98564736629 * (julianDate - 2451545.0) +
                  longitude) %
              360.0;

      final position = CoordinateConverter.equatorialToHorizontal(
        ra: localSiderealTime,
        dec: -10.0,
        latitude: latitude,
        longitude: longitude,
        utc: utc,
      );

      expect(position.azimuth, closeTo(180.0, 1e-6));
      expect(position.altitude, closeTo(90.0 - (latitude + 10.0), 1e-6));
    });
  });

  group('SunCalculator', () {
    test('is near RA 0h / Dec 0 at the March 2026 equinox', () {
      final (ra, dec, distanceKm) =
          const SunCalculator().calculate(DateTime.utc(2026, 3, 20, 14, 46));

      expect(_angularDistanceDegrees(ra, 0.0), lessThan(1.0));
      expect(dec.abs(), lessThan(1.0));
      expect(distanceKm, isNull);
    });

    test('trajectory samples cover the requested window', () {
      final center = DateTime.utc(2026, 6, 1, 12);
      final samples = const SunCalculator().generateTrajectory(
        center: center,
        hoursBefore: 12,
        hoursAfter: 12,
        stepMinutes: 30,
      );

      expect(samples.length, 49);
      expect(samples.first.time, center.subtract(const Duration(hours: 12)));
      expect(samples.last.time, center.add(const Duration(hours: 12)));

      for (var i = 1; i < samples.length; i++) {
        expect(samples[i].time.isAfter(samples[i - 1].time), isTrue);
      }
    });
  });

  group('MoonCalculator', () {
    test('phase facts report a recognised phase and a valid fraction', () {
      final facts =
          const MoonCalculator().phaseFacts(DateTime.utc(2026, 3, 20, 14, 46));

      expect(facts.length, 2);
      expect(facts.first.key, 'Phase');
      expect(
        facts.first.value,
        isIn(const [
          'New Moon',
          'Waxing Crescent',
          'First Quarter',
          'Waxing Gibbous',
          'Full Moon',
          'Waning Gibbous',
          'Last Quarter',
          'Waning Crescent',
        ]),
      );

      final fraction = double.parse(
        facts.last.value.replaceAll('%', ''),
      );

      expect(fraction, inInclusiveRange(0.0, 100.0));
    });
  });

  group('PlanetCalculator', () {
    final utc = DateTime.utc(2026, 3, 20, 14, 46);

    test('every registered planet returns a plausible position', () {
      final planets = registeredCelestialBodies.where(
        (body) => body.calculator is PlanetCalculator,
      );

      expect(planets, isNotEmpty);

      for (final body in planets) {
        final (ra, dec, distanceKm) = body.calculator.calculate(utc);

        expect(ra, inInclusiveRange(0.0, 360.0), reason: body.id);
        expect(dec, inInclusiveRange(-90.0, 90.0), reason: body.id);
        expect(distanceKm, isNotNull, reason: body.id);
        expect(distanceKm! > 0, isTrue, reason: body.id);
      }
    });

    test('reports geocentric distances on the expected scale', () {
      final (_, _, mercuryDistance) = mercuryBody.calculator.calculate(utc);
      final (_, _, neptuneDistance) = neptuneBody.calculator.calculate(utc);

      expect(mercuryDistance, inInclusiveRange(8.0e7, 2.2e8));
      expect(neptuneDistance, inInclusiveRange(4.2e9, 4.8e9));
      expect(mercuryDistance, lessThan(neptuneDistance!));
    });
  });
}
