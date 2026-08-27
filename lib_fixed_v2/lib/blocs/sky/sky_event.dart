import 'package:equatable/equatable.dart';

import '../../models/device_orientation.dart';
import '../../models/observer_location.dart';

sealed class SkyEvent extends Equatable {
  const SkyEvent();

  @override
  List<Object?> get props => [];
}

/// Requests the initial loading of the sky.
final class SkyLoadRequested extends SkyEvent {
  const SkyLoadRequested();
}

/// Requests a recalculation of celestial positions.
final class SkyPositionsUpdateRequested extends SkyEvent {
  const SkyPositionsUpdateRequested();
}

/// Device orientation changed.
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

/// Toggles the horizon line.
final class SkyHorizonToggled extends SkyEvent {
  const SkyHorizonToggled();
}

/// Toggles constellation rendering.
final class SkyConstellationsToggled extends SkyEvent {
  const SkyConstellationsToggled();
}

/// Toggles object selection.
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

/// The Sun was tapped.
///
/// The Sun is kept separate from the star catalogue because
/// it is a dynamically calculated celestial object.
final class SkySunTapped extends SkyEvent {
  const SkySunTapped();
}

/// Updates the observer location.
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