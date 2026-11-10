import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../models/celestial_object.dart';

class CelestialInfoPanel extends StatelessWidget {
  final CelestialObject object;
  final VoidCallback onClose;

  const CelestialInfoPanel({
    super.key,
    required this.object,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
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
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(object: object, onClose: onClose),
                      const SizedBox(height: 10),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final fact in object.facts)
                                _InfoRow(label: fact.key, value: fact.value),
                            ],
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
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final CelestialObject object;
  final VoidCallback onClose;

  const _Header({required this.object, required this.onClose});

  Color get _titleColor {
    switch (object.type) {
      case CelestialObjectType.sun:
        return const Color(0xFFFFD95A);
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showSubtitle = object.description.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                object.name,
                style: TextStyle(
                  color: _titleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showSubtitle)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    object.description,
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
