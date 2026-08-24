import 'package:flutter/material.dart';

/// Single source of truth for the app's palette. Everything else
/// (dock, painter, info panel) reads from here instead of carrying
/// its own copy of the accent color.
class AppColors {
  AppColors._();

  static const background = Colors.black;

  // Muted purple identity color: horizon ring, dim constellation
  // lines, center marker, unselected interactable-star rings.
  static const accent = Color(0xFF6E5E8B);

  // Brighter variant for anything that needs to stand out against
  // the dim accent: selected star, its constellation, compass labels.
  static const accentBright = Color(0xFFC9BEE8);

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xB3FFFFFF);
  static const textTertiary = Color(0x80FFFFFF);

  static const glassBackground = Color(0x73000000);
  static const glassBorder = Color(0x1AFFFFFF);
}