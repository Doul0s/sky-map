import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skymap/models/celestial_object.dart';
import 'package:skymap/widgets/celestial_info_panel.dart';

void main() {
  testWidgets('CelestialInfoPanel shows the name, description and facts', (
    tester,
  ) async {
    const object = CelestialObject(
      id: 'sun',
      name: 'Sun',
      type: CelestialObjectType.sun,
      description: 'G2V main-sequence star',
      facts: [
        MapEntry('Altitude', '12.34°'),
        MapEntry('Azimuth', '180.00°'),
      ],
    );

    var closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CelestialInfoPanel(
            object: object,
            onClose: () => closed = true,
          ),
        ),
      ),
    );

    expect(find.text('Sun'), findsOneWidget);
    expect(find.text('G2V main-sequence star'), findsOneWidget);
    expect(find.text('ALTITUDE'), findsOneWidget);
    expect(find.text('12.34°'), findsOneWidget);
    expect(find.text('AZIMUTH'), findsOneWidget);
    expect(find.text('180.00°'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(closed, isTrue);
  });
}
