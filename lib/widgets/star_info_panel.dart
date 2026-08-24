import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../models/sky_star.dart';

class StarInfoPanel extends StatelessWidget {
  final SkyStar star;
  final VoidCallback onClose;

  const StarInfoPanel({
    super.key,
    required this.star,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Absorbs taps so interacting with the panel doesn't fall through
    // to the "tap anywhere else to close" handler behind it.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 300,
          maxHeight: MediaQuery.of(context).size.height * 0.32,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.glassBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.glassBorder,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(star: star, onClose: onClose),
                    const SizedBox(height: 10),
                    Flexible(
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(right: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _buildRows(star),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static List<Widget> _buildRows(SkyStar star) {
    final entries = <MapEntry<String, String>>[
      if (star.constellation != null)
        MapEntry('Constellation', star.constellation!),
      MapEntry('Magnitude', star.magnitude.toStringAsFixed(2)),
      if (star.spectralType != null && star.spectralType!.isNotEmpty)
        MapEntry('Spectral type', star.spectralType!),
      if (star.bayer != null) MapEntry('Bayer designation', star.bayer!),
      MapEntry('Right ascension', '${star.ra.toStringAsFixed(2)}°'),
      MapEntry('Declination', '${star.dec.toStringAsFixed(2)}°'),
      if (star.origin != null && star.origin!.isNotEmpty)
        MapEntry('Origin', star.origin!),
      if (star.language != null && star.language!.isNotEmpty)
        MapEntry('Language', star.language!),
    ];

    return [
      for (final entry in entries)
        _InfoRow(label: entry.key, value: entry.value),
    ];
  }
}

class _Header extends StatelessWidget {
  final SkyStar star;
  final VoidCallback onClose;

  const _Header({required this.star, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final catalogName = star.name;
    final showCatalogName =
        catalogName != null && catalogName != star.displayName;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                star.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showCatalogName)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    catalogName,
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded, size: 18),
          color: Colors.white54,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.accentBright,
              fontSize: 10,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}