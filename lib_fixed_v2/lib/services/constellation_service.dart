import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/constellation.dart';

class ConstellationService {
  static const String _assetPath =
      'assets/data/constellations.json';

  Future<List<Constellation>> loadConstellations() async {
    final jsonString = await rootBundle.loadString(
      _assetPath,
    );

    final decoded = jsonDecode(jsonString);

    if (decoded is! List) {
      throw const FormatException(
        'Constellation catalog must be a JSON array.',
      );
    }

    return decoded
        .map(
          (item) => Constellation.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }
}