import 'dart:async';

import 'package:flutter/services.dart';

import '../models/device_orientation.dart' as sky;

class OrientationService {
  static const EventChannel _channel =
      EventChannel('skymap/orientation');

  final StreamController<sky.DeviceOrientation>
      _controller =
      StreamController<sky.DeviceOrientation>.broadcast();

  StreamSubscription<dynamic>? _subscription;

  Stream<sky.DeviceOrientation> get orientationStream =>
      _controller.stream;

  void start() {
    if (_subscription != null) {
      return;
    }

    _subscription = _channel
        .receiveBroadcastStream()
        .listen(
          _handleEvent,
          onError: _handleError,
        );
  }

  void _handleEvent(dynamic event) {
    if (event is! Map) {
      return;
    }

    final orientation =
        sky.DeviceOrientation(
      backX: _number(event['backX']),
      backY: _number(event['backY']),
      backZ: _number(event['backZ']),

      upX: _number(event['upX']),
      upY: _number(event['upY']),
      upZ: _number(event['upZ']),

      rightX: _number(event['rightX']),
      rightY: _number(event['rightY']),
      rightZ: _number(event['rightZ']),

      azimuth: _number(event['azimuth']),
      altitude: _number(event['altitude']),
    );

    _controller.add(orientation);
  }

  void _handleError(Object error) {
    // Sensor errors should not crash the application.
  }

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return 0.0;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}