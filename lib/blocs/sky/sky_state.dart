import 'package:equatable/equatable.dart';

import '../../data/celestial_bodies.dart';
import '../../models/celestial_object.dart';
import '../../models/celestial_position.dart';
import '../../models/celestial_runtime.dart';
import '../../models/celestial_trajectory.dart';
import '../../models/constellation.dart';
import '../../models/device_orientation.dart';
import '../../models/observer_location.dart';
import '../../models/sky_star.dart';

enum SkyStatus {
  initial,
  loading,
  loaded,
  error,
}

class SkyState extends Equatable {
  final SkyStatus status;

  final ObserverLocation? location;
  final DeviceOrientation? orientation;

  final List<SkyStar> stars;
  final List<Constellation> constellations;

  /// Current horizontal positions of the stars.
  ///
  /// This list is parallel to [stars].
  final List<CelestialPosition> positions;

  /// World-space unit vectors for each star.
  ///
  /// Parallel to [positions].
  ///
  /// World coordinate system:
  ///
  /// X = North
  /// Y = East
  /// Z = Up
  final List<WorldVector> starVectors;

  /// Live position/vector/trajectory for every registered celestial
  /// body (currently just the Sun), keyed by [CelestialBody.id].
  ///
  /// Kept as one bundled value per id rather than three parallel maps
  /// so a body can never end up with a position but no vector.
  final Map<String, CelestialRuntime> celestialRuntimes;

  final DateTime? lastPositionUpdate;
  final String? errorMessage;

  // Display controls.
  final bool showHorizon;
  final bool showConstellations;
  final bool objectSelectionEnabled;

  /// Which star is currently selected, if any.
  final int? selectedStarId;

  /// Which celestial body is currently selected, if any (by
  /// [CelestialBody.id] — e.g. `"sun"`).
  ///
  /// Kept as a separate field from [selectedStarId] rather than a
  /// shared id space: stars use integer catalog ids, celestial bodies
  /// use string ids, and the two are mutually exclusive by construction
  /// (the bloc clears one whenever the other is set).
  final String? selectedCelestialObjectId;

  const SkyState({
    this.status = SkyStatus.initial,
    this.location,
    this.orientation,
    this.stars = const [],
    this.constellations = const [],
    this.positions = const [],
    this.starVectors = const [],
    this.celestialRuntimes = const {},
    this.lastPositionUpdate,
    this.errorMessage,
    this.showHorizon = true,
    this.showConstellations = true,
    this.objectSelectionEnabled = false,
    this.selectedStarId,
    this.selectedCelestialObjectId,
  });

  SkyStar? get selectedStar {
    if (selectedStarId == null) {
      return null;
    }

    for (final star in stars) {
      if (star.id == selectedStarId) {
        return star;
      }
    }

    return null;
  }

  Constellation? get selectedConstellation {
    final star = selectedStar;

    if (star == null || star.constellation == null) {
      return null;
    }

    for (final constellation in constellations) {
      if (constellation.id == star.constellation) {
        return constellation;
      }
    }

    return null;
  }

  /// Unified info-panel data for whatever is currently selected — a
  /// celestial body (Sun today) or a catalog star. Null when nothing is
  /// selected. [selectedCelestialObjectId] and [selectedStarId] are
  /// kept mutually exclusive by the bloc, so at most one branch here is
  /// ever non-null.
  CelestialObject? get selectedInfo {
    final objectId = selectedCelestialObjectId;

    if (objectId != null) {
      final body = celestialBodyById(objectId);

      if (body == null) {
        return null;
      }

      final runtime = celestialRuntimes[objectId];

      return body.buildInfo(
        ra: runtime?.ra,
        dec: runtime?.dec,
        position: runtime?.position,
        distanceKm: runtime?.distanceKm,
        extraFacts: runtime?.extraFacts ?? const [],
      );
    }

    return selectedStar?.toCelestialObject();
  }

  SkyState copyWith({
    SkyStatus? status,
    ObserverLocation? location,
    DeviceOrientation? orientation,
    List<SkyStar>? stars,
    List<Constellation>? constellations,
    List<CelestialPosition>? positions,
    List<WorldVector>? starVectors,
    Map<String, CelestialRuntime>? celestialRuntimes,
    DateTime? lastPositionUpdate,
    String? errorMessage,
    bool? showHorizon,
    bool? showConstellations,
    bool? objectSelectionEnabled,
    int? selectedStarId,
    String? selectedCelestialObjectId,
    bool clearStarSelection = false,
    bool clearCelestialSelection = false,
    bool clearError = false,
  }) {
    return SkyState(
      status: status ?? this.status,

      location: location ?? this.location,

      orientation: orientation ?? this.orientation,

      stars: stars ?? this.stars,

      constellations: constellations ?? this.constellations,

      positions: positions ?? this.positions,

      starVectors: starVectors ?? this.starVectors,

      celestialRuntimes: celestialRuntimes ?? this.celestialRuntimes,

      lastPositionUpdate: lastPositionUpdate ?? this.lastPositionUpdate,

      // An error can only be cleared explicitly; otherwise any unrelated
      // event (e.g. an orientation update) would silently wipe it.
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),

      showHorizon: showHorizon ?? this.showHorizon,

      showConstellations: showConstellations ?? this.showConstellations,

      objectSelectionEnabled:
          objectSelectionEnabled ?? this.objectSelectionEnabled,

      // clearStarSelection/clearCelestialSelection are the only paths
      // that actually clear these fields — passing `null` alone would
      // NOT clear them, since copyWith can't tell "explicitly clear"
      // apart from "not provided" for an already-nullable field.
      selectedStarId: clearStarSelection
          ? null
          : (selectedStarId ?? this.selectedStarId),

      selectedCelestialObjectId: clearCelestialSelection
          ? null
          : (selectedCelestialObjectId ?? this.selectedCelestialObjectId),
    );
  }

  @override
  List<Object?> get props => [
        status,
        location,
        orientation,
        stars,
        constellations,
        positions,
        starVectors,
        celestialRuntimes,
        lastPositionUpdate,
        errorMessage,
        showHorizon,
        showConstellations,
        objectSelectionEnabled,
        selectedStarId,
        selectedCelestialObjectId,
      ];
}
