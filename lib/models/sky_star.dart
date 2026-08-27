import 'celestial_object.dart';

class SkyStar {
  final int id;
  final String? name;
  final String? commonName;

  final double magnitude;
  final String? spectralType;

  final double ra;
  final double dec;

  final int? hip;
  final String? bayer;
  final String? constellation;

  final String? origin;
  final String? language;
  final String? reference;
  final String? dateOfAdoption;

  const SkyStar({
    required this.id,
    this.name,
    this.commonName,
    required this.magnitude,
    this.spectralType,
    required this.ra,
    required this.dec,
    this.hip,
    this.bayer,
    this.constellation,
    this.origin,
    this.language,
    this.reference,
    this.dateOfAdoption,
  });

  factory SkyStar.fromJson(Map<String, dynamic> json) {
    return SkyStar(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String?,
      commonName: json['common_name'] as String?,
      magnitude: (json['magnitude'] as num).toDouble(),
      spectralType: json['spectral_type'] as String?,
      ra: (json['ra'] as num).toDouble(),
      dec: (json['dec'] as num).toDouble(),
      hip: (json['hip'] as num?)?.toInt(),
      bayer: json['bayer'] as String?,
      constellation: json['constellation'] as String?,
      origin: json['origin'] as String?,
      language: json['language'] as String?,
      reference: json['reference'] as String?,
      dateOfAdoption: json['date_of_adoption'] as String?,
    );
  }

  String get displayName {
    final common = commonName?.trim();

    if (common != null && common.isNotEmpty) {
      return common;
    }

    final catalogName = name?.trim();

    if (catalogName != null && catalogName.isNotEmpty) {
      return catalogName;
    }

    return 'HR $id';
  }

  /// Only named stars are interactable.
  ///
  /// Unnamed catalogue stars remain visible in the sky but are
  /// deliberately excluded from object selection.
  bool get isInteractable {
    final name = commonName?.trim();

    return name != null && name.isNotEmpty;
  }

  CelestialObject toCelestialObject() {
    final catalogName = name?.trim();
    final subtitle =
        catalogName != null && catalogName.isNotEmpty && catalogName != displayName
            ? catalogName
            : '';

    return CelestialObject(
      id: 'star-$id',
      name: displayName,
      type: CelestialObjectType.star,
      description: subtitle,
      facts: [
        if (constellation != null) MapEntry('Constellation', constellation!),
        MapEntry('Magnitude', magnitude.toStringAsFixed(2)),
        if (spectralType != null && spectralType!.isNotEmpty)
          MapEntry('Spectral type', spectralType!),
        if (bayer != null) MapEntry('Bayer designation', bayer!),
        MapEntry('Right ascension', '${ra.toStringAsFixed(2)}°'),
        MapEntry('Declination', '${dec.toStringAsFixed(2)}°'),
        if (origin != null && origin!.isNotEmpty) MapEntry('Origin', origin!),
        if (language != null && language!.isNotEmpty)
          MapEntry('Language', language!),
      ],
    );
  }
}