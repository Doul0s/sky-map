import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../blocs/sky/sky_bloc.dart';
import '../blocs/sky/sky_event.dart';
import '../blocs/sky/sky_state.dart';
import '../data/celestial_bodies.dart';
import '../services/constellation_service.dart';
import '../services/location_service.dart';
import '../services/orientation_service.dart';
import '../services/star_catalog_service.dart';
import '../widgets/sky_dock.dart';
import '../widgets/sky_painter.dart';
import '../widgets/star_hit_tester.dart';
import '../widgets/celestial_info_panel.dart';

class SkyScreen extends StatelessWidget {
  const SkyScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SkyBloc(
        locationService:
            LocationService(),
        orientationService:
            OrientationService(),
        starCatalogService:
            StarCatalogService(),
        constellationService:
            ConstellationService(),
      )..add(
          const SkyLoadRequested(),
        ),
      child: const _SkyView(),
    );
  }
}

class _SkyView extends StatelessWidget {
  const _SkyView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SkyBloc, SkyState>(
      builder: (context, state) {
        switch (state.status) {
          case SkyStatus.initial:
          case SkyStatus.loading:
            return const _LoadingView();

          case SkyStatus.error:
            return _ErrorView(
              message:
                  state.errorMessage ??
                  'Something went wrong.',
              onRetry: () => context
                  .read<SkyBloc>()
                  .add(const SkyLoadRequested()),
            );

          case SkyStatus.loaded:
            return _LoadedView(
              state: state,
            );
        }
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
              TextButton(
                onPressed: Geolocator.openAppSettings,
                child: const Text('Open settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  final SkyState state;

  const _LoadedView({
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final orientation =
        state.orientation;

    if (orientation == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Waiting for sensors...',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder:
                  (context, constraints) {
                final size = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );

                return GestureDetector(
                  behavior:
                      HitTestBehavior.opaque,
                  onTapUp: (details) {
                    _handleTap(
                      context,
                      details.localPosition,
                      size,
                    );
                  },
                  child: CustomPaint(
                    painter: SkyPainter(
                      stars: state.stars,
                      starVectors:
                          state.starVectors,
                      constellations:
                          state.constellations,

                      celestialBodies:
                          registeredCelestialBodies,
                      celestialRuntimes:
                          state.celestialRuntimes,
                      selectedCelestialObjectId:
                          state.selectedCelestialObjectId,

                      orientation:
                          orientation,
                      showHorizon:
                          state.showHorizon,
                      showConstellations:
                          state.showConstellations,
                      objectSelectionEnabled:
                          state.objectSelectionEnabled,
                      selectedStarId:
                          state.selectedStarId,
                    ),
                  ),
                );
              },
            ),

            if (state.selectedInfo != null)
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: CelestialInfoPanel(
                    object: state.selectedInfo!,
                    onClose: () {
                      if (state.selectedCelestialObjectId != null) {
                        context.read<SkyBloc>().add(
                              SkyCelestialObjectTapped(
                                state.selectedCelestialObjectId,
                              ),
                            );
                      } else {
                        context
                            .read<SkyBloc>()
                            .add(const SkyStarTapped(null));
                      }
                    },
                  ),
                ),
              ),

            const Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(
                child: SkyDock(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(
    BuildContext context,
    Offset localPosition,
    Size size,
  ) {
    if (!state.objectSelectionEnabled &&
        state.selectedStarId == null &&
        state.selectedCelestialObjectId == null) {
      return;
    }

    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final result = state.objectSelectionEnabled
        ? StarHitTester.findTapped(
            tapPosition: localPosition,
            stars: state.stars,
            starVectors: state.starVectors,
            celestialVectors: {
              for (final entry in state.celestialRuntimes.entries)
                entry.key: entry.value.vector,
            },
            orientation: state.orientation!,
            center: center,
            size: size,
          )
        : null;

    if (result is StarTapResult) {
      context.read<SkyBloc>().add(SkyStarTapped(result.starId));
      return;
    }

    if (result is CelestialObjectTapResult) {
      context
          .read<SkyBloc>()
          .add(SkyCelestialObjectTapped(result.objectId));
      return;
    }

    // Nothing hit — either the tap genuinely missed, or selection mode
    // is off and this tap is just meant to clear whatever is currently
    // selected.
    if (state.selectedCelestialObjectId != null) {
      context.read<SkyBloc>().add(const SkyCelestialObjectTapped(null));
    } else {
      context.read<SkyBloc>().add(const SkyStarTapped(null));
    }
  }
}
