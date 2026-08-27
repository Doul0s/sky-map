import 'package:equatable/equatable.dart';

import '../../data/sun_object.dart';
import '../../models/celestial_object.dart';
import '../../models/celestial_position.dart';
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

  /// Current horizontal position of the Sun.
  final CelestialPosition? sunPosition;

  /// Current equatorial coordinates of the Sun in degrees.
  final double? sunRa;
  final double? sunDec;

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

  /// World-space unit vector for the current Sun position.
  ///
  /// Derived from [sunPosition].
  final WorldVector? sunVector;

  /// Apparent trajectory of the Sun across the sky.
  ///
  /// This is NOT the physical orbit of the Sun.
  ///
  /// It represents the apparent path of the Sun as seen
  /// by the observer over time.
  final CelestialTrajectory? sunTrajectory;

  final DateTime? lastPositionUpdate;
  final String? errorMessage;

  // Display controls.
  final bool showHorizon;
  final bool showConstellations;
  final bool objectSelectionEnabled;

  /// Which star is currently selected, if any.
  final int? selectedStarId;

  /// Whether the Sun is currently selected.
  ///
  /// Sun selection is kept separate from star selection because
  /// the Sun is not part of the star catalogue.
  final bool sunSelected;

  const SkyState({
    this.status = SkyStatus.initial,
    this.location,
    this.orientation,
    this.stars = const [],
    this.constellations = const [],
    this.positions = const [],
    this.sunPosition,
    this.sunRa,
    this.sunDec,
    this.starVectors = const [],
    this.sunVector,
    this.sunTrajectory,
    this.lastPositionUpdate,
    this.errorMessage,
    this.showHorizon = true,
    this.showConstellations = true,
    this.objectSelectionEnabled = false,
    this.selectedStarId,
    this.sunSelected = false,
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

    if (star == null ||
        star.constellation == null) {
      return null;
    }

    for (final constellation in constellations) {
      if (constellation.id ==
          star.constellation) {
        return constellation;
      }
    }

    return null;
  }

  /// Unified info-panel data for whatever is currently selected — the
  /// Sun or a catalog star. Null when nothing is selected. Since
  /// sunSelected and selectedStarId are kept mutually exclusive by the
  /// bloc, at most one branch here is ever non-null.
  CelestialObject? get selectedInfo {
    if (sunSelected) {
      return buildSunCelestialObject(
        ra: sunRa,
        dec: sunDec,
        position: sunPosition,
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
    CelestialPosition? sunPosition,
    double? sunRa,
    double? sunDec,
    List<WorldVector>? starVectors,
    WorldVector? sunVector,
    CelestialTrajectory? sunTrajectory,
    DateTime? lastPositionUpdate,
    String? errorMessage,
    bool? showHorizon,
    bool? showConstellations,
    bool? objectSelectionEnabled,
    int? selectedStarId,
    bool? sunSelected,
    bool clearSelection = false,
  }) {
    return SkyState(
      status:
          status ?? this.status,

      location:
          location ?? this.location,

      orientation:
          orientation ?? this.orientation,

      stars:
          stars ?? this.stars,

      constellations:
          constellations ??
              this.constellations,

      positions:
          positions ?? this.positions,

      sunPosition:
          sunPosition ??
              this.sunPosition,

      sunRa:
          sunRa ?? this.sunRa,

      sunDec:
          sunDec ?? this.sunDec,

      starVectors:
          starVectors ??
              this.starVectors,

      sunVector:
          sunVector ??
              this.sunVector,

      sunTrajectory:
          sunTrajectory ??
              this.sunTrajectory,

      lastPositionUpdate:
          lastPositionUpdate ??
              this.lastPositionUpdate,

      errorMessage:
          errorMessage,

      showHorizon:
          showHorizon ??
              this.showHorizon,

      showConstellations:
          showConstellations ??
              this.showConstellations,

      objectSelectionEnabled:
          objectSelectionEnabled ??
              this.objectSelectionEnabled,

      selectedStarId:
          clearSelection
              ? null
              : (selectedStarId ??
                  this.selectedStarId),

      sunSelected:
          sunSelected ??
              (clearSelection
                  ? false
                  : this.sunSelected),
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
        sunPosition,
        sunRa,
        sunDec,
        starVectors,
        sunVector,
        sunTrajectory,
        lastPositionUpdate,
        errorMessage,
        showHorizon,
        showConstellations,
        objectSelectionEnabled,
        selectedStarId,
        sunSelected,
      ];
}