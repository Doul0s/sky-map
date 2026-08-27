import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../astronomy/coordinate_converter.dart';
import '../../astronomy/sky_coordinates.dart';
import '../../astronomy/sun_calculator.dart';
import '../../models/celestial_position.dart';
import '../../models/celestial_trajectory.dart';
import '../../models/observer_location.dart';
import '../../services/constellation_service.dart';
import '../../services/location_service.dart';
import '../../services/orientation_service.dart';
import '../../services/star_catalog_service.dart';
import 'sky_event.dart';
import 'sky_state.dart';

class SkyBloc extends Bloc<SkyEvent, SkyState> {
  final LocationService locationService;
  final OrientationService orientationService;
  final StarCatalogService starCatalogService;
  final ConstellationService constellationService;
  final SunCalculator sunCalculator;

  StreamSubscription? _orientationSubscription;
  Timer? _positionTimer;

  SkyBloc({
    required this.locationService,
    required this.orientationService,
    required this.starCatalogService,
    required this.constellationService,
    required this.sunCalculator,
  }) : super(const SkyState()) {
    on<SkyLoadRequested>(
      _onLoadRequested,
    );

    on<SkyPositionsUpdateRequested>(
      _onPositionsUpdateRequested,
    );

    on<SkyOrientationChanged>(
      _onOrientationChanged,
    );

    on<SkyHorizonToggled>(
      _onHorizonToggled,
    );

    on<SkyConstellationsToggled>(
      _onConstellationsToggled,
    );

    on<SkyObjectSelectionToggled>(
      _onObjectSelectionToggled,
    );

    on<SkyStarTapped>(
      _onStarTapped,
    );

    on<SkySunTapped>(
      _onSunTapped,
    );

    on<SkyLocationChanged>(
      _onLocationChanged,
    );
  }

  Future<void> _onLoadRequested(
    SkyLoadRequested event,
    Emitter<SkyState> emit,
  ) async {
    emit(
      state.copyWith(
        status: SkyStatus.loading,
        errorMessage: null,
      ),
    );

    try {
      final stars =
          await starCatalogService.loadStars();

      final constellations =
          await constellationService
              .loadConstellations();

      final location =
          await locationService
              .getCurrentLocation();

      final utc =
          DateTime.now().toUtc();

      final positions =
          _calculatePositions(
        stars: stars,
        location: location,
        utc: utc,
      );

      final (sunRa, sunDec) =
          sunCalculator.calculate(utc);

      final sunPosition =
          _sunHorizontalPosition(
        ra: sunRa,
        dec: sunDec,
        location: location,
        utc: utc,
      );

      final starVectors =
          _calculateWorldVectors(
        positions,
      );

      final sunVector =
          _calculateWorldVector(
        sunPosition,
      );

      final sunTrajectory =
          _calculateSunTrajectory(
        location: location,
        center: utc,
      );

      emit(
        state.copyWith(
          status: SkyStatus.loaded,
          stars: stars,
          constellations: constellations,
          location: location,
          positions: positions,
          sunPosition: sunPosition,
          sunRa: sunRa,
          sunDec: sunDec,
          starVectors: starVectors,
          sunVector: sunVector,
          sunTrajectory: sunTrajectory,
          lastPositionUpdate: utc,
        ),
      );

      _startOrientation();
      _startPositionTimer();
    } catch (error) {
      emit(
        state.copyWith(
          status: SkyStatus.error,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onPositionsUpdateRequested(
    SkyPositionsUpdateRequested event,
    Emitter<SkyState> emit,
  ) async {
    final location = state.location;

    if (state.status != SkyStatus.loaded ||
        location == null) {
      return;
    }

    final utc =
        DateTime.now().toUtc();

    final positions =
        _calculatePositions(
      stars: state.stars,
      location: location,
      utc: utc,
    );

    final (sunRa, sunDec) =
        sunCalculator.calculate(utc);

    final sunPosition =
        _sunHorizontalPosition(
      ra: sunRa,
      dec: sunDec,
      location: location,
      utc: utc,
    );

    final sunTrajectory =
        _calculateSunTrajectory(
      location: location,
      center: utc,
    );

    emit(
      state.copyWith(
        positions: positions,
        sunPosition: sunPosition,
        sunRa: sunRa,
        sunDec: sunDec,
        starVectors:
            _calculateWorldVectors(
          positions,
        ),
        sunVector:
            _calculateWorldVector(
          sunPosition,
        ),
        sunTrajectory:
            sunTrajectory,
        lastPositionUpdate: utc,
      ),
    );
  }

  void _onOrientationChanged(
    SkyOrientationChanged event,
    Emitter<SkyState> emit,
  ) {
    emit(
      state.copyWith(
        orientation: event.orientation,
      ),
    );
  }

  void _onHorizonToggled(
    SkyHorizonToggled event,
    Emitter<SkyState> emit,
  ) {
    emit(
      state.copyWith(
        showHorizon:
            !state.showHorizon,
      ),
    );
  }

  void _onConstellationsToggled(
    SkyConstellationsToggled event,
    Emitter<SkyState> emit,
  ) {
    emit(
      state.copyWith(
        showConstellations:
            !state.showConstellations,
      ),
    );
  }

  void _onObjectSelectionToggled(
    SkyObjectSelectionToggled event,
    Emitter<SkyState> emit,
  ) {
    emit(
      state.copyWith(
        objectSelectionEnabled:
            !state.objectSelectionEnabled,
        clearSelection: true,
      ),
    );
  }

  void _onStarTapped(
    SkyStarTapped event,
    Emitter<SkyState> emit,
  ) {
    final isSameStar =
        event.starId != null &&
        event.starId ==
            state.selectedStarId;

    emit(
      state.copyWith(
        selectedStarId:
            isSameStar
                ? null
                : event.starId,

        // Selecting a star deselects the Sun.
        sunSelected: false,

        clearSelection:
            event.starId == null ||
            isSameStar,
      ),
    );
  }

  void _onSunTapped(
    SkySunTapped event,
    Emitter<SkyState> emit,
  ) {
    emit(
      state.copyWith(
        sunSelected:
            !state.sunSelected,

        // `selectedStarId: null` alone would NOT clear it — copyWith's
        // `selectedStarId ?? this.selectedStarId` can't tell "explicitly
        // clear" apart from "not provided", so the old star selection
        // would silently survive. `clearSelection` is the only path
        // that actually clears it (see copyWith below).
        clearSelection: true,
      ),
    );
  }

  void _onLocationChanged(
    SkyLocationChanged event,
    Emitter<SkyState> emit,
  ) {
    emit(
      state.copyWith(
        location: event.location,
      ),
    );

    /*
     * The position timer will recalculate the astronomical
     * positions using the new observer location.
     */
    add(
      const SkyPositionsUpdateRequested(),
    );
  }

  List<CelestialPosition>
      _calculatePositions({
    required List stars,
    required ObserverLocation location,
    required DateTime utc,
  }) {
    return stars
        .map<CelestialPosition>(
          (star) {
            return CoordinateConverter
                .starToHorizontal(
              star: star,
              latitude:
                  location.latitude,
              longitude:
                  location.longitude,
              utc: utc,
            );
          },
        )
        .toList(
          growable: false,
        );
  }

  CelestialPosition
      _sunHorizontalPosition({
    required double ra,
    required double dec,
    required ObserverLocation location,
    required DateTime utc,
  }) {
    return CoordinateConverter
        .equatorialToHorizontal(
      ra: ra,
      dec: dec,
      latitude:
          location.latitude,
      longitude:
          location.longitude,
      utc: utc,
    );
  }

  CelestialTrajectory
      _calculateSunTrajectory({
    required ObserverLocation location,
    required DateTime center,
  }) {
    final samples =
        sunCalculator.generateTrajectory(
      center: center,
      hoursBefore: 12,
      hoursAfter: 12,
      stepMinutes: 30,
    );

    final points =
        <WorldVector>[];

    for (final sample in samples) {
      final position =
          CoordinateConverter
              .equatorialToHorizontal(
        ra: sample.ra,
        dec: sample.dec,
        latitude:
            location.latitude,
        longitude:
            location.longitude,
        utc: sample.time,
      );

      final vector =
          SkyCoordinates.horizontalToVector(
        azimuth:
            position.azimuth,
        altitude:
            position.altitude,
      );

      points.add(vector);
    }

    return CelestialTrajectory(
      points: points,
    );
  }

  /*
   * Alt/Az -> unit vector.
   *
   * World coordinate system:
   *
   *   X = North
   *   Y = East
   *   Z = Up
   *
   * This conversion is deliberately performed outside
   * SkyPainter because it does not depend on the device
   * orientation.
   */
  List<WorldVector>
      _calculateWorldVectors(
    List<CelestialPosition> positions,
  ) {
    return positions
        .map(
          (position) {
            return SkyCoordinates
                .horizontalToVector(
              azimuth:
                  position.azimuth,
              altitude:
                  position.altitude,
            );
          },
        )
        .toList(
          growable: false,
        );
  }

  WorldVector _calculateWorldVector(
    CelestialPosition position,
  ) {
    return SkyCoordinates
        .horizontalToVector(
      azimuth:
          position.azimuth,
      altitude:
          position.altitude,
    );
  }

  void _startOrientation() {
    _orientationSubscription
        ?.cancel();

    orientationService.start();

    _orientationSubscription =
        orientationService
            .orientationStream
            .listen(
      (orientation) {
        add(
          SkyOrientationChanged(
            orientation,
          ),
        );
      },
    );
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();

    _positionTimer =
        Timer.periodic(
      const Duration(
        seconds: 30,
      ),
      (_) {
        add(
          const SkyPositionsUpdateRequested(),
        );
      },
    );
  }

  @override
  Future<void> close() async {
    _positionTimer?.cancel();

    await _orientationSubscription
        ?.cancel();

    await orientationService.dispose();

    return super.close();
  }
}