import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app/theme/app_colors.dart';
import '../blocs/sky/sky_bloc.dart';
import '../blocs/sky/sky_event.dart';
import '../blocs/sky/sky_state.dart';

class SkyDock extends StatelessWidget {
  const SkyDock({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SkyBloc, SkyState, _DockState>(
      selector: (state) => _DockState(
        showHorizon: state.showHorizon,
        showConstellations: state.showConstellations,
        objectSelectionEnabled: state.objectSelectionEnabled,
      ),
      builder: (context, dockState) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.glassBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.glassBorder,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DockToggle(
                      icon: Icons.horizontal_rule_rounded,
                      label: 'Horizon',
                      active: dockState.showHorizon,
                      onTap: () => context
                          .read<SkyBloc>()
                          .add(const SkyHorizonToggled()),
                    ),
                    _DockToggle(
                      icon: Icons.polyline_rounded,
                      label: 'Stars',
                      active: dockState.showConstellations,
                      onTap: () => context
                          .read<SkyBloc>()
                          .add(const SkyConstellationsToggled()),
                    ),
                    _DockToggle(
                      icon: Icons.touch_app_rounded,
                      label: 'Select',
                      active: dockState.objectSelectionEnabled,
                      onTap: () => context
                          .read<SkyBloc>()
                          .add(const SkyObjectSelectionToggled()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DockToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DockToggle({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: active,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: AppColors.accent.withValues(alpha: 0.18),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: active
                  ? AppColors.accent.withValues(alpha: 0.20)
                  : Colors.transparent,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        blurRadius: 14,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: active ? AppColors.textPrimary : Colors.white38,
              ),
              child: Icon(
                icon,
                size: 22,
                color: active ? AppColors.textPrimary : Colors.white38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockState {
  final bool showHorizon;
  final bool showConstellations;
  final bool objectSelectionEnabled;

  const _DockState({
    required this.showHorizon,
    required this.showConstellations,
    required this.objectSelectionEnabled,
  });
}