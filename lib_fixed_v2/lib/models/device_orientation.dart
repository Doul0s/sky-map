class DeviceOrientation {
  /// Direction the BACK of the phone faces.
  ///
  /// World coordinate system:
  /// X = North
  /// Y = East
  /// Z = Up
  final double backX;
  final double backY;
  final double backZ;

  /// Direction toward the TOP of the screen.
  final double upX;
  final double upY;
  final double upZ;

  /// Direction toward the RIGHT side of the screen.
  final double rightX;
  final double rightY;
  final double rightZ;

  final double azimuth;
  final double altitude;

  const DeviceOrientation({
    required this.backX,
    required this.backY,
    required this.backZ,
    required this.upX,
    required this.upY,
    required this.upZ,
    required this.rightX,
    required this.rightY,
    required this.rightZ,
    required this.azimuth,
    required this.altitude,
  });
}