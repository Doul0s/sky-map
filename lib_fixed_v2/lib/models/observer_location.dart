class ObserverLocation {
  final double latitude;
  final double longitude;
  final double altitude;

  const ObserverLocation({
    required this.latitude,
    required this.longitude,
    this.altitude = 0,
  });
}