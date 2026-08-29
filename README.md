# Sky Map

**A real-time augmented-reality astronomical visualization for Flutter & Android**

[![Flutter](https://img.shields.io/badge/Flutter-3.12+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12+-0175C4?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Platform-Android-green?logo=android)](https://developer.android.com)
[![License](https://img.shields.io/badge/License-License%20TBD-lightgrey)](#license)

---

## Overview

Sky Map transforms your Android device into a real-time window to the night sky. By fusing GPS location, device orientation sensors, precise astronomical calculations, and full star catalog data, it renders an interactive sky that updates as you move your phone.

Point your phone at the sky and see stars, constellations, the Sun, the Moon, and compass directions rendered in their correct positions — as if the screen were transparent glass.

The core design philosophy: **calculate the sky slowly, update the view fast.** Celestial positions are recomputed on a background schedule; the renderer only projects precomputed world vectors to the screen on every frame.

---

## Screenshots

> **TODO:** Add screenshots or screen recordings demonstrating the app in action.
>
> Suggested captures:
> - Star field with constellation lines enabled
> - Sun with trajectory path
> - Moon with trajectory path
> - Info panel after selecting a named star (or the Sun/Moon)
> - Bottom dock controls

---

## Key Features

### Celestial Rendering
- **9,096 stars** from the Yale Bright Star Catalog (HR 1–9110), rendered with magnitude-based sizing and spectral-type coloring (O/B/A/F/G/K/M — blue-white through orange)
- **414 named stars** (IAU proper names) are tappable — stars without a common name are part of the catalog but not individually selectable
- **86 IAU constellation stick figures** drawn as line segments with highlight-on-select
- **Sun rendering** with multi-layer glow effect (core, disc, outer glow, selection ring)
- **Moon rendering** with atmospheric halo, shaded disk, and crater hints
- **24-hour trajectories** rendered as a glowing path across the sky for every registered celestial body (Sun and Moon)
- **Horizon line** with compass cardinal direction labels (N/E/S/W)

### Sensor Integration
- **Device orientation** via a custom native Android `EventChannel` bridge reading `TYPE_ROTATION_VECTOR` at `SENSOR_DELAY_GAME` rate
- **Display rotation compensation** — correct behavior across all four device orientations
- **GPS location** via `geolocator` with permission handling, 15-second timeout fallback, and last-known-position recovery

### Astronomical Engine
- **Equatorial-to-horizontal conversion** — Julian Date → GMST → Local Sidereal Time → Hour Angle → Azimuth/Altitude
- **Topocentric parallax correction** — the Moon's position is adjusted for a WGS84 oblate-Earth observer model (essential: the Moon's parallax can reach ~1°)
- **Sun position calculation** — mean anomaly, equation of center, obliquity of ecliptic, ecliptic-to-equatorial transformation
- **Moon position calculation** — a reduced Meeus periodic-term lunar theory (equation of center, evection, variation, etc.), yielding geocentric RA/Dec and Earth–Moon distance
- **Moon phase facts** — live phase name (8 phases) and illuminated fraction, derived from the Sun–Moon elongation angle
- **3D camera projection** — shared world-space → camera-space → screen-space projector with behind-camera clipping

### Interactive UI
- **Tap-to-select stars** — hit-testing with a 22px radius for named stars and a 30px radius for celestial bodies (Sun/Moon), using the same projection math as the renderer
- **Celestial info panel** — glassmorphism overlay displaying the selected object's identity and live facts (for the Moon: distance, RA/Dec, altitude, azimuth, phase, illumination)
- **Bottom dock controls** — toggle horizon line, constellation lines, and selection mode with animated glow indicators
- **Immersive mode** — full-screen, no system UI distractions
- **Periodic updates** — celestial positions and trajectories recalculated every 30 seconds to account for Earth's rotation

---

## Architecture

### High-Level Data Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           ANDROID DEVICE                                 │
│                                                                          │
│   ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐       │
│   │   GPS    │     │  Clock   │     │ Sensors  │     │ Catalogs │       │
│   │ Location │     │   UTC    │     │ Rotation │     │ Data     │       │
│   └────┬─────┘     └────┬─────┘     └────┬─────┘     └────┬─────┘       │
│        │                │                │                │              │
│        ▼                ▼                ▼                ▼              │
│   ┌─────────────────────────────────────────────────────────────────┐    │
│   │                         Sky BLoC                                │    │
│   │  ┌─────────────────┐  ┌──────────────────┐  ┌───────────────┐  │    │
│   │  │  Location       │  │  Orientation     │  │  Catalog /    │  │    │
│   │  │  Service        │  │  Service         │  │  Body         │  │    │
│   │  │  (geolocator)   │  │  (EventChannel)  │  │  Services     │  │    │
│   │  └────────┬────────┘  └────────┬─────────┘  └───────┬───────┘  │    │
│   │           │                   │                     │          │    │
│   │           ▼                   ▼                     ▼          │    │
│   │  ┌─────────────────────────────────────────────────────────┐   │    │
│   │  │        Celestial Calculators (Sun / Moon)              │   │    │
│   │  │        RA/Dec (+ parallax) + 24-h trajectories         │   │    │
│   │  └────────────────────────┬────────────────────────────────┘   │    │
│   │                           │                                    │    │
│   │                           ▼                                    │    │
│   │  ┌─────────────────────────────────────────────────────────┐   │    │
│   │  │               Coordinate Converter                       │   │    │
│   │  │  RA/Dec → Az/Alt (using LST, observer location, time)  │   │    │
│   │  └────────────────────────┬────────────────────────────────┘   │    │
│   │                           │                                    │    │
│   │                           ▼                                    │    │
│   │  ┌─────────────────────────────────────────────────────────┐   │    │
│   │  │              CameraProjector                             │   │    │
│   │  │  World vectors → Camera basis → Screen coordinates       │   │    │
│   │  └────────────────────────┬────────────────────────────────┘   │    │
│   └───────────────────────────┼────────────────────────────────────┘    │
│                               │                                        │
│                               ▼                                        │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                         SkyPainter                              │   │
│   │  CustomPainter — renders stars, constellations, Sun, Moon,      │   │
│   │  trajectories, horizon, compass labels on a black Canvas        │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                               │                                        │
│                               ▼                                        │
│                         ★ You see the sky                               │
└──────────────────────────────────────────────────────────────────────────┘
```

### Component Overview

| Layer | Component | Responsibility |
|-------|-----------|----------------|
| **State Management** | `SkyBloc` | Central BLoC; processes sensor events, triggers position updates, manages app state (441 lines) |
| **Services** | `LocationService` | GPS acquisition with permission handling, timeout, and last-known-position fallback |
| | `OrientationService` | Bridges native Android sensor data to Flutter via `EventChannel('skymap/orientation')` |
| | `StarCatalogService` | Loads the star catalog from bundled JSON asset (memoized) |
| | `ConstellationService` | Loads constellation stick-figure data from bundled JSON asset |
| **Astronomy** | `CoordinateConverter` | Equatorial → horizontal pipeline with topocentric parallax (WGS84 observer model) (421 lines) |
| | `SkyCoordinates` | Horizontal coordinates → unit vectors in the world frame |
| | `SunCalculator` | Apparent Sun position and 24-hour trajectory |
| | `MoonCalculator` | Meeus reduced lunar theory — position, distance, trajectory (≤10-min samples), phase facts (659 lines) |
| **Data** | `celestial_bodies.dart` | Registry of live celestial bodies (`sun`, `moon`) with their calculators and static facts |
| **Models** | `SkyStar`, `Constellation`, `CelestialBody`, `CelestialObject`, `CelestialRuntime`, `CelestialPosition`, `CelestialTrajectory`, `DeviceOrientation`, `ObserverLocation` | Immutable data models for all domain objects |
| **Rendering** | `SkyPainter` | Single `CustomPainter` handling all sky rendering passes (1,284 lines) |
| | `CameraProjector` | Shared world → camera → screen transform used by both painter and hit tester |
| | `StarHitTester` | Tap detection for stars and celestial bodies, mirroring `CameraProjector` math |
| **UI** | `SkyScreen` | Main screen; manages permission flow, loading states, sensor waiting |
| | `CelestialInfoPanel` | Glassmorphism overlay for selected star or celestial body details |
| | `SkyDock` | Bottom toggle bar for horizon, constellations, and selection mode |

### Key Concepts

- **`CelestialCalculator`** — abstract interface (`calculate`, `generateTrajectory`) implemented by `SunCalculator` and `MoonCalculator`. Each body supplies its own RA/Dec math, optional distance for parallax, and trajectory sampling strategy.
- **`CelestialRuntime`** — bundles everything computed for one body at one update tick (RA/Dec, horizontal position, world vector, trajectory, distance, live facts), so the painter and UI always consume a consistent snapshot.
- **3D projection** — the phone's orientation defines a camera basis (right/up/back); world-space unit vectors are projected onto that basis, then scaled by focal length into screen coordinates, with points behind the camera clipped.

---

## Tech Stack

### Framework & Language

| Technology | Version | Role |
|-----------|---------|------|
| Flutter | ^3.12.2 | UI framework |
| Dart | ^3.12.2 | Application language |
| Kotlin | 2.3.20 | Android native sensor code |

### Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_bloc` | ^9.1.1 | BLoC state management pattern |
| `equatable` | ^2.1.0 | Value equality for BLoC states and events |
| `geolocator` | ^14.0.3 | GPS location services with permission handling |

Declared but unused:

| Package | Version | Why declared |
|---------|---------|--------------|
| `provider` | ^6.1.5+1 | Reserved for state management; `flutter_bloc` is used instead |
| `sensors_plus` | ^7.1.0 | Reserved; actual sensor reading is custom native code |
| `cupertino_icons` | ^1.0.8 | iOS-style icon pack |

### Dev Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_test` | (SDK) | Testing framework |
| `flutter_lints` | ^6.0.0 | Static analysis lint rules |

### Native Code

- **Android:** Custom `MainActivity.kt` (260 lines) implementing an `EventChannel` bridge that reads `Sensor.TYPE_ROTATION_VECTOR`, computes the rotation matrix, remaps it for all four display rotations, converts Android's East/North convention into the app's North/East/Up world frame, and sends 9-axis camera-basis vectors (right/up/back) plus derived azimuth/altitude to Flutter
- **iOS / Desktop / Web:** Boilerplate only — no custom native implementations

---

## Project Structure

```
sky-map/
├── lib/                                # Main Dart source code (4,985 lines)
│   ├── main.dart                       # Entry point
│   ├── app/
│   │   ├── app.dart                    # Root MaterialApp widget
│   │   └── theme/
│   │       ├── app_colors.dart         # Centralized color palette
│   │       └── app_theme.dart          # Dark theme definition
│   ├── astronomy/
│   │   ├── celestial_calculator.dart   # Abstract celestial math interface
│   │   ├── coordinate_converter.dart   # RA/Dec → Az/Alt (+ parallax)
│   │   ├── moon_calculator.dart        # Meeus lunar theory + phase facts (659 lines)
│   │   ├── sky_coordinates.dart        # Horizontal → unit vector
│   │   └── sun_calculator.dart         # Apparent Sun position + trajectory
│   ├── blocs/
│   │   └── sky/
│   │       ├── sky_bloc.dart           # Central BLoC (441 lines)
│   │       ├── sky_event.dart          # 9 sealed event types
│   │       └── sky_state.dart          # Immutable state (228 lines)
│   ├── data/
│   │   └── celestial_bodies.dart       # Registry of sun/moon bodies
│   ├── models/
│   │   ├── celestial_body.dart         # Static body definition + info builder
│   │   ├── celestial_object.dart       # Enums + info-panel snapshot model
│   │   ├── celestial_position.dart     # Az/Alt value object
│   │   ├── celestial_runtime.dart      # Per-tick bundle of body computations
│   │   ├── celestial_trajectory.dart   # World-vector trajectory
│   │   ├── constellation.dart          # Constellation data model
│   │   ├── device_orientation.dart     # 9-axis orientation + az/alt
│   │   ├── observer_location.dart      # Lat/lon/alt
│   │   └── sky_star.dart               # Star catalog entry model
│   ├── screens/
│   │   └── sky_screen.dart             # Main screen (284 lines)
│   ├── services/
│   │   ├── constellation_service.dart  # Loads constellations from JSON asset
│   │   ├── location_service.dart       # GPS via geolocator
│   │   ├── orientation_service.dart    # EventChannel bridge to native sensors
│   │   └── star_catalog_service.dart   # Loads stars from JSON asset
│   └── widgets/
│       ├── camera_projector.dart       # World → camera → screen projection
│       ├── celestial_info_panel.dart   # Glassmorphism info overlay
│       ├── sky_dock.dart               # Bottom toggle bar
│       ├── sky_painter.dart            # CustomPainter sky renderer (1,284 lines)
│       └── star_hit_tester.dart        # Tap-to-select detection
├── assets/
│   └── data/
│       ├── stars.json                  # 9,096 stars — Yale Bright Star Catalog
│       └── constellations.json         # 86 IAU constellation stick figures
├── data/                               # Raw source data for generation scripts
│   ├── catalog.dat.gz                  # Yale Bright Star Catalog (gzipped)
│   ├── constellation_lines_hr.dat      # Constellation line definitions
│   └── iau_proper_stars.csv            # IAU proper star names + metadata
├── scripts/
│   ├── generate_stars.py               # catalog.dat.gz → stars.json
│   └── generate_constellations.py      # HR lines → constellations.json
├── android/                            # Android platform project
│   └── app/src/main/
│       ├── AndroidManifest.xml         # Location permissions
│       └── kotlin/.../MainActivity.kt  # Native sensor bridge (260 lines)
├── ios/                                # iOS platform (boilerplate)
├── web/                                # Web platform (boilerplate)
├── linux/                              # Linux desktop (boilerplate)
├── macos/                              # macOS desktop (boilerplate)
├── windows/                            # Windows desktop (boilerplate)
├── test/
│   └── widget_test.dart                # Empty placeholder — tests not yet written
├── pubspec.yaml                        # Flutter project manifest
├── analysis_options.yaml               # Dart linter configuration
└── README.md                           # This file
```

---

## Getting Started

### Prerequisites

- **Flutter SDK** ^3.12.2 (stable channel)
- **Android SDK** (minSdk 21+)
- **Android device** with GPS and orientation sensors (required — sensors are unavailable on emulators)
- **Python 3** (optional — only needed for regenerating star/constellation catalogs from raw data)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/<your-username>/sky-map.git
   cd sky-map
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Run on a connected Android device**
   ```bash
   flutter run
   ```

> **Note:** A physical Android device is required. The app relies on GPS and hardware orientation sensors that are not available on emulators or simulators.

### Building

```bash
# Android APK
flutter build apk

# Android App Bundle
flutter build appbundle
```

---

## Data Pipeline

Sky Map ships with pre-generated JSON asset catalogs. The raw astronomical data and Python generation scripts are included for reference and regeneration.

### Star Catalog

- **Source:** Yale Bright Star Catalog (`data/catalog.dat.gz`) — 9,096 stars (HR 1–9110)
- **Supplemental data:** IAU proper star names (`data/iau_proper_stars.csv`) — 597 entries, 415 with HR designations
- **Generator:** `scripts/generate_stars.py`
- **Output:** `assets/data/stars.json` (145,537 lines)

```bash
python3 scripts/generate_stars.py
```

### Constellation Lines

- **Source:** IAU constellation stick-figure definitions (`data/constellation_lines_hr.dat`)
- **Generator:** `scripts/generate_constellations.py`
- **Output:** `assets/data/constellations.json` (2,229 lines, 86 constellations, 240 line segments)

> **Note:** The source file defines 86 of the 88 IAU constellations — Mensa and Sextans have no stick-figure definitions.

```bash
python3 scripts/generate_constellations.py
```

### Data Fields

**Stars** include: HR number, common name, IAU name, Bayer designation, constellation, right ascension, declination, apparent magnitude, spectral type, plus proper-name provenance (origin, language, reference, adoption date) where available.

**Constellations** include: name, abbreviation, and an array of line segments defined by HR star numbers forming the stick figure.

---

## Configuration

### Android Permissions

Declared in `AndroidManifest.xml`:

| Permission | Purpose |
|-----------|---------|
| `ACCESS_FINE_LOCATION` | High-accuracy GPS for observer position |
| `ACCESS_COARSE_LOCATION` | Approximate location fallback |

### Sensor Requirements

The app requires the following hardware sensors:

| Sensor | Purpose | Fallback |
|--------|---------|----------|
| Accelerometer | Device orientation | Shows "Waiting for sensors..." |
| Magnetometer | Device orientation | Shows "Waiting for sensors..." |
| Gyroscope | Rotation vector | Shows "Waiting for sensors..." |
| GPS | Observer location | Error message with last-known position attempt |

The app gracefully handles missing sensors — no crashes, appropriate user feedback.

### Graceful Degradation

- **No GPS:** Displays error message; falls back to last-known position
- **No sensors:** Shows "Waiting for sensors..." message until data arrives
- **Sensor errors:** Silently caught, app continues with available data

---

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **Android** | Fully supported | Custom native sensor bridge, GPS, immersive mode |
| **iOS** | Scaffolded | Platform directory exists; requires Core Motion `EventChannel` implementation |
| **Web** | Scaffolded | Platform directory exists; no sensor/GPS integration |
| **Linux** | Scaffolded | Platform directory exists; no sensor/GPS integration |
| **macOS** | Scaffolded | Platform directory exists; no sensor/GPS integration |
| **Windows** | Scaffolded | Platform directory exists; no sensor/GPS integration |

---

## Current State & Roadmap

### Implemented

- [x] Star field rendering (9,096 stars, magnitude-based sizing, spectral-type coloring)
- [x] Device orientation tracking via custom native Android EventChannel
- [x] GPS location acquisition with permission handling and fallback
- [x] Equatorial-to-horizontal coordinate conversion with topocentric parallax
- [x] Sun position calculation, 24-hour trajectory, and multi-layer glow rendering
- [x] Moon position calculation (Meeus lunar theory), parallax, trajectory, and rendering
- [x] Moon phase and illuminated-fraction data in the info panel
- [x] Constellation stick-figure rendering (86 IAU constellations) with highlight-on-select
- [x] Tap-to-select for named stars and celestial bodies (Sun/Moon)
- [x] Celestial info panel with live metadata for stars and bodies
- [x] Bottom dock controls (horizon, constellations, selection mode toggles)
- [x] Horizon line with compass labels
- [x] Immersive full-screen mode
- [x] Dark theme
- [x] Data generation pipeline (Python scripts for star/constellation catalogs)
- [x] Shared camera projection reused by painter and hit tester

### Planned / Not Yet Implemented

- [ ] **Unit and widget tests** — `test/widget_test.dart` is currently empty
- [ ] **iOS native sensor bridge** — Core Motion `EventChannel` implementation
- [ ] **Phase-accurate Moon disk** — the rendered Moon is not yet shaded by illuminated phase
- [ ] **Planets** — the pipeline supports arbitrary `CelestialBody` entries, but no planetary calculators exist yet
- [ ] **Desktop/Web platform support** — Scaffold directories exist, no custom code
- [ ] **Proper app identity** — Currently uses `com.example.skymap`
- [ ] **Release signing configuration** — Android release builds use debug keys
- [ ] **CI/CD pipeline** — No GitHub Actions or build automation
- [ ] **Localization** — All strings currently hardcoded in English

---

## Development

### Available Commands

```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Run static analysis
flutter analyze

# Run tests
flutter test

# Regenerate star catalog
python3 scripts/generate_stars.py

# Regenerate constellation data
python3 scripts/generate_constellations.py
```

### Code Conventions

- **State management:** BLoC pattern via `flutter_bloc`
- **State immutability:** All state and event classes use `equatable` for value equality
- **Rendering:** Single `CustomPainter` (`SkyPainter`) handles all sky rendering in layered passes; projection math lives in `CameraProjector` and is shared with the hit tester
- **Celestial math:** Each body implements the `CelestialCalculator` interface; pure Dart, no Flutter dependencies in `lib/astronomy/`
- **Native code:** Kotlin for Android sensor bridge; Flutter `EventChannel` for communication
- **Assets:** Star and constellation data loaded from bundled JSON files at startup

### Project Layout

- `lib/astronomy/` — Pure astronomical math (no Flutter dependencies)
- `lib/blocs/` — State management (BLoC pattern)
- `lib/data/` — Static celestial-body registry
- `lib/models/` — Immutable data models
- `lib/services/` — Platform service abstractions
- `lib/widgets/` — UI components, custom painters, and projection helpers
- `scripts/` — Data pipeline utilities (Python)

---

## License

> **License to be determined.** Please contact the project maintainer for licensing information.

---

<p align="center"><sub>Built with Flutter · Dart · Android · A love for the night sky</sub></p>