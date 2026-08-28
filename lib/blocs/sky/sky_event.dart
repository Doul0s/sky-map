import 'package:equatable/equatable.dart';

import '../../models/device_orientation.dart';
import '../../models/observer_location.dart';

sealed class SkyEvent extends Equatable {
  const SkyEvent();

  @override
  List<Object?> get props => [];
}

final class SkyLoadRequested extends SkyEvent {
  const SkyLoadRequested();
}

final class SkyPositionsUpdateRequested extends SkyEvent {
  const SkyPositionsUpdateRequested();
}

final class SkyOrientationChanged extends SkyEvent {
  final DeviceOrientation orientation;

  const SkyOrientationChanged(
    this.orientation,
  );

  @override
  List<Object?> get props => [
        orientation,
      ];
}

final class SkyHorizonToggled extends SkyEvent {
  const SkyHorizonToggled();
}

final class SkyConstellationsToggled extends SkyEvent {
  const SkyConstellationsToggled();
}

final class SkyObjectSelectionToggled extends SkyEvent {
  const SkyObjectSelectionToggled();
}

/// A star was tapped.
///
/// Passing `null` clears the current star selection.
final class SkyStarTapped extends SkyEvent {
  final int? starId;

  const SkyStarTapped(
    this.starId,
  );

  @override
  List<Object?> get props => [
        starId,
      ];
}

/// A celestial object was tapped, identified by its [CelestialBody.id].
///
/// Passing `null` clears the current celestial-object selection.
final class SkyCelestialObjectTapped extends SkyEvent {
  final String? objectId;

  const SkyCelestialObjectTapped(
    this.objectId,
  );

  @override
  List<Object?> get props => [
        objectId,
      ];
}

final class SkyLocationChanged extends SkyEvent {
  final ObserverLocation location;

  const SkyLocationChanged(
    this.location,
  );

  @override
  List<Object?> get props => [
        location,
      ];
}