import 'package:flutter_test/flutter_test.dart';
import 'package:skymap/blocs/sky/sky_state.dart';

void main() {
  group('SkyState.copyWith', () {
    test('keeps a previous error when an unrelated field changes', () {
      final errored = const SkyState(
        status: SkyStatus.error,
        errorMessage: 'GPS unavailable',
      );

      final toggled = errored.copyWith(showHorizon: false);

      expect(toggled.errorMessage, 'GPS unavailable');
    });

    test('clearError explicitly removes the error', () {
      final errored = const SkyState(
        status: SkyStatus.error,
        errorMessage: 'GPS unavailable',
      );

      final loading = errored.copyWith(
        status: SkyStatus.loading,
        clearError: true,
      );

      expect(loading.errorMessage, isNull);
    });

    test('clearStarSelection and clearCelestialSelection reset ids', () {
      const state = SkyState(
        selectedStarId: 42,
        selectedCelestialObjectId: 'sun',
      );

      final cleared = state.copyWith(
        clearStarSelection: true,
        clearCelestialSelection: true,
      );

      expect(cleared.selectedStarId, isNull);
      expect(cleared.selectedCelestialObjectId, isNull);
    });
  });
}
