enum CelestialObjectType {
  star,
  planet,
  sun,
  moon,
  constellation,
}

class CelestialObject {
  final String id;
  final String name;
  final CelestialObjectType type;
  final String description;
  final List<MapEntry<String, String>> facts;

  const CelestialObject({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    this.facts = const [],
  });
}