import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../astronomy/coordinate_converter.dart';
import '../../astronomy/sky_coordinates.dart';
import '../../data/celestial_bodies.dart';
import '../../models/celestial_body.dart';
import '../../models/celestial_position.dart';
import '../../models/celestial_runtime.dart';
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

  /// The celestial bodies this bloc computes positions/trajectories for.
  /// Defaults to the app-wide registry; overridable for tests.
  final List<CelestialBody> celestialBodies;

  StreamSubscription? _orientationSubscription;
  Timer? _positionTimer;

  SkyBloc({
    required this.locationService,
    required this.orientationService,
    required this.starCatalogService,
    required this.constellationService,
    List<CelestialBody>? celestialBodies,
  })  : celestialBodies = celestialBodies ?? registeredCelestialBodies,
        super(const SkyState()) {
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

    on<SkyCelestialObjectTapped>(
      _onCelestialObjectTapped,
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
          await constellationService.loadConstellations();

      final location =
          await locationService.getCurrentLocation();

      final utc = DateTime.now().toUtc();

      final positions = _calculatePositions(
        stars: stars,
        location: location,
        utc: utc,
      );

      final celestialRuntimes = _calculateCelestialRuntimes(
        location: location,
        utc: utc,
      );

      emit(
        state.copyWith(
          status: SkyStatus.loaded,
          stars: stars,
          constellations: constellations,
          location: location,
          positions: positions,
          starVectors: _calculateWorldVectors(positions),
          celestialRuntimes: celestialRuntimes,
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

    if (state.status != SkyStatus.loaded || location == null) {
      return;
    }

    final utc = DateTime.now().toUtc();

    final positions = _calculatePositions(
      stars: state.stars,
      location: location,
      utc: utc,
    );

    final celestialRuntimes = _calculateCelestialRuntimes(
      location: location,
      utc: utc,
    );

    emit(
      state.copyWith(
        positions: positions,
        starVectors: _calculateWorldVectors(positions),
        celestialRuntimes: celestialRuntimes,
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
        showHorizon: !state.showHorizon,
      ),
    );
  }

  void _onConstellationsToggled(
    SkyConstellationsToggled event,
    Emitter<SkyState> emit,
  ) {
    emit(
      state.copyWith(
        showConstellations: !state.showConstellations,
      ),
    );
  }

  void _onObjectSelectionToggled(
    SkyObjectSelectionToggled event,
    Emitter<SkyState> emit,
  ) {
    emit(
      state.copyWith(
        objectSelectionEnabled: !state.objectSelectionEnabled,
        clearStarSelection: true,
        clearCelestialSelection: true,
      ),
    );
  }

  void _onStarTapped(
    SkyStarTapped event,
    Emitter<SkyState> emit,
  ) {
    final isSameStar =
        event.starId != null && event.starId == state.selectedStarId;

    emit(
      state.copyWith(
        selectedStarId: isSameStar ? null : event.starId,
        clearStarSelection: event.starId == null || isSameStar,
        clearCelestialSelection: true,
      ),
    );
  }

  void _onCelestialObjectTapped(
    SkyCelestialObjectTapped event,
    Emitter<SkyState> emit,
  ) {
    final isSameObject = event.objectId != null &&
        event.objectId == state.selectedCelestialObjectId;

    emit(
      state.copyWith(
        selectedCelestialObjectId: isSameObject ? null : event.objectId,
        clearCelestialSelection: event.objectId == null || isSameObject,
        clearStarSelection: true,
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

    add(
      const SkyPositionsUpdateRequested(),
    );
  }

  List<CelestialPosition> _calculatePositions({
    required List stars,
    required ObserverLocation location,
    required DateTime utc,
  }) {
    return stars
        .map<CelestialPosition>(
          (star) {
            return CoordinateConverter.starToHorizontal(
              star: star,
              latitude: location.latitude,
              longitude: location.longitude,
              utc: utc,
            );
          },
        )
        .toList(growable: false);
  }

  /// Computes position/vector/trajectory for every registered celestial
  /// body, keyed by [CelestialBody.id].
  Map<String, CelestialRuntime> _calculateCelestialRuntimes({
    required ObserverLocation location,
    required DateTime utc,
  }) {
    final result = <String, CelestialRuntime>{};

    for (final body in celestialBodies) {
      final (ra, dec) = body.calculator.calculate(utc);

      final position = CoordinateConverter.equatorialToHorizontal(
        ra: ra,
        dec: dec,
        latitude: location.latitude,
        longitude: location.longitude,
        utc: utc,
      );

      final vector = SkyCoordinates.horizontalToVector(
        azimuth: position.azimuth,
        altitude: position.altitude,
      );

      final trajectory = _calculateTrajectory(
        body: body,
        location: location,
        center: utc,
      );

      result[body.id] = CelestialRuntime(
        ra: ra,
        dec: dec,
        position: position,
        vector: vector,
        trajectory: trajectory,
      );
    }

    return result;
  }

  CelestialTrajectory _calculateTrajectory({
    required CelestialBody body,
    required ObserverLocation location,
    required DateTime center,
  }) {
    final samples = body.calculator.generateTrajectory(
      center: center,
      hoursBefore: 12,
      hoursAfter: 12,
      stepMinutes: 30,
    );

    final points = <WorldVector>[];

    for (final sample in samples) {
      final position = CoordinateConverter.equatorialToHorizontal(
        ra: sample.ra,
        dec: sample.dec,
        latitude: location.latitude,
        longitude: location.longitude,
        utc: sample.time,
      );

      points.add(
        SkyCoordinates.horizontalToVector(
          azimuth: position.azimuth,
          altitude: position.altitude,
        ),
      );
    }

    return CelestialTrajectory(points: points);
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
  List<WorldVector> _calculateWorldVectors(
    List<CelestialPosition> positions,
  ) {
    return positions
        .map(
          (position) {
            return SkyCoordinates.horizontalToVector(
              azimuth: position.azimuth,
              altitude: position.altitude,
            );
          },
        )
        .toList(growable: false);
  }

  void _startOrientation() {
    _orientationSubscription?.cancel();

    orientationService.start();

    _orientationSubscription = orientationService.orientationStream.listen(
      (orientation) {
        add(
          SkyOrientationChanged(orientation),
        );
      },
    );
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();

    _positionTimer = Timer.periodic(
      const Duration(seconds: 30),
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

    await _orientationSubscription?.cancel();

    await orientationService.dispose();

    return super.close();
  }
}
