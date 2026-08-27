import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/observer_location.dart';

class LocationService {
  static const Duration _timeout = Duration(seconds: 15);

  Future<ObserverLocation> getCurrentLocation() async {
    await _checkLocationAvailability();

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(_timeout);

      return _toObserverLocation(position);
    } on TimeoutException {
      return _getLastKnownLocation();
    } on LocationServiceException {
      rethrow;
    } catch (_) {
      return _getLastKnownLocation();
    }
  }

  Future<ObserverLocation> _getLastKnownLocation() async {
    try {
      final position = await Geolocator.getLastKnownPosition();

      if (position == null) {
        throw const LocationServiceException(
          'Unable to determine your location. '
          'Make sure location services are enabled.',
        );
      }

      return _toObserverLocation(position);
    } catch (error) {
      if (error is LocationServiceException) {
        rethrow;
      }

      throw const LocationServiceException(
        'Unable to determine your location.',
      );
    }
  }

  ObserverLocation _toObserverLocation(Position position) {
    return ObserverLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
    );
  }

  Future<void> _checkLocationAvailability() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const LocationServiceException(
        'Location services are disabled. '
        'Please enable GPS and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationServiceException(
        'Location permission was denied.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Location permission was permanently denied. '
        'Enable location permission in Android settings.',
      );
    }
  }
}

class LocationServiceException implements Exception {
  final String message;

  const LocationServiceException(this.message);

  @override
  String toString() => message;
}