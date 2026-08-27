import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/sky_star.dart';

class StarCatalogService {
  static const String _assetPath =
      'assets/data/stars.json';

  List<SkyStar>? _cache;

  Future<List<SkyStar>> loadStars() async {
    if (_cache != null) {
      return _cache!;
    }

    final jsonString =
        await rootBundle.loadString(_assetPath);

    final decoded =
        jsonDecode(jsonString) as List<dynamic>;

    final stars = decoded
        .map(
          (item) => SkyStar.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();

    _cache = stars;

    return stars;
  }
}