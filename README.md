# Sky Map

**A real-time augmented-reality astronomical visualization for Flutter & Android**

[![Flutter](https://img.shields.io/badge/Flutter-3.12+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12+-0175C4?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Platform-Android-green?logo=android)](https://developer.android.com)
[![License](https://img.shields.io/badge/License-License%20TBD-lightgrey)](#license)

---

## Overview

Sky Map transforms your Android device into a real-time window to the night sky. By fusing GPS location, device orientation sensors, precise astronomical calculations, and a rich star catalog, it renders an interactive star field that updates as you move your phone.

Point your phone at the sky and see stars, constellations, the Sun, and compass directions rendered in their correct positions — as if the screen were transparent glass.

The core design philosophy: **calculate the sky slowly, update the view fast.**

---

## Screenshots

> **TODO:** Add screenshots or screen recordings demonstrating the app in action.
>
> Suggested captures:
> - Star field with constellation lines enabled
> - Sun with trajectory path
> - Star info panel after selecting a named star
> - Bottom dock controls

---

## Key Features

### Celestial Rendering
- **909 stars** from the Yale Bright Star Catalog, rendered with magnitude-based sizing and spectral-type coloring (O/B/A/F/G/K/M — blue-white through orange)
- **88 IAU constellations** drawn as stick-figure line segments with highlight-on-select
- **Sun tracking** with multi-layer glow effect (core, disc, outer glow, selection ring)
- **24-hour Sun trajectory** sampled at 30-minute intervals, rendered as a path across the sky
- **Horizon line** with compass cardinal direction labels (N/E/S/W)

### Sensor Integration
- **Device orientation** via custom native Android `EventChannel` bridge reading `TYPE_ROTATION_VECTOR` at `SENSOR_DELAY_GAME` rate
- **Display rotation compensation** — correct behavior across all four device orientations
- **GPS location** via `geolocator` with permission handling, timeout fallback, and last-known-position recovery

### Astronomical Engine
- **Equatorial-to-horizontal coordinate conversion** — Julian Date → GMST → Local Sidereal Time → Hour Angle → Azimuth/Altitude
- **Sun position calculation** — mean anomaly, equation of center, obliquity of ecliptic, ecliptic-to-equatorial transformation
- **3D camera projection** — world-space basis vectors → camera-space dot product → screen-space focal-length projection with behind-camera clipping

### Interactive UI
- **Tap-to-select stars** — hit-testing with 22px radius, projection math mirroring the renderer
- **Star info panel** — glassmorphism overlay displaying name, catalog ID, constellation, magnitude, spectral type, Bayer designation, RA/Dec, and etymological origin
- **Bottom dock controls** — toggle horizon line, constellation lines, and selection mode with animated glow indicators
- **Immersive mode** — full-screen, no system UI distractions
- **Periodic updates** — celestial positions recalculated every 30 seconds to account for Earth's rotation

---

## Architecture

### High-Level Data Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           ANDROID DEVICE                                 │
│                                                                          │
│   ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐       │
│   │   GPS    │     │  Clock   │     │ Sensors  │     │   Star   │       │
│   │ Location │     │   UTC    │     │ Rotation │     │ Catalog  │       │
│   └────┬─────┘     └────┬─────┘     └────┬─────┘     └────┬─────┘       │
│        │                │                │                │              │
│        ▼                ▼                ▼                ▼              │
│   ┌─────────────────────────────────────────────────────────────────┐    │
│   │                         Sky BLoC                                │    │
│   │  ┌─────────────────┐  ┌──────────────────┐  ┌───────────────┐  │    │
│   │  │  Location       │  │  Orientation     │  │  Star /       │  │    │
│   │  │  Service        │  │  Service         │  │  Constellation│  │    │
│   │  │  (geolocator)   │  │  (EventChannel)  │  │  Services     │  │    │
│   │  └────────┬────────┘  └────────┬─────────┘  └───────┬───────┘  │    │
│   │           │                   │                     │          │    │
│   │           ▼                   ▼                     ▼          │    │
│   │  ┌─────────────────────────────────────────────────────────┐   │    │
│   │  │              Coordinate Converter                       │   │    │
│   │  │  RA/Dec → Az/Alt (using LST, observer location, time)  │   │    │
│   │  └────────────────────────┬────────────────────────────────┘   │    │
│   │                           │                                    │    │
│   │                           ▼                                    │    │
│   │  ┌─────────────────────────────────────────────────────────┐   │    │
│   │  │              3D Projection                               │   │    │
│   │  │  World vectors → Camera basis → Screen coordinates       │   │    │
│   │  └────────────────────────┬────────────────────────────────┘   │    │
│   └───────────────────────────┼────────────────────────────────────┘    │
│                               │                                        │
│                               ▼                                        │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                         SkyPainter                              │   │
│   │  CustomPainter — renders stars, constellations, Sun,           │   │
│   │  horizon, compass labels on a black Canvas                     │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                               │                                        │
│                               ▼                                        │
│                         ★ You see the stars                             │
└──────────────────────────────────────────────────────────────────────────┘
```

### Component Overview

| Layer | Component | Responsibility |
|-------|-----------|----------------|
| **State Management** | `SkyBloc` | Central BLoC; processes sensor events, triggers position updates, manages app state |
| **Services** | `LocationService` | GPS acquisition with permission handling and fallback |
| | `OrientationService` | Bridges native Android sensor data to Flutter via `EventChannel` |
| | `StarCatalogService` | Loads star catalog from bundled JSON asset |
| | `ConstellationService` | Loads constellation stick-figure data from bundled JSON asset |
| **Astronomy** | `CoordinateConverter` | Full equatorial → horizontal coordinate transformation pipeline |
| | `SkyCoordinates` | Horizontal coordinates → unit vectors in the world frame |
| | `SunCalculator` | Apparent Sun position and 24-hour trajectory computation |
| **Models** | `SkyStar`, `Constellation`, `CelestialPosition`, `DeviceOrientation`, `ObserverLocation`, `CelestialTrajectory` | Immutable data models for all domain objects |
| **Rendering** | `SkyPainter` | 1,149-line `CustomPainter` handling all sky rendering passes |
| | `StarHitTester` | Tap detection using projection math that mirrors `SkyPainter` |
| **UI** | `SkyScreen` | Main screen; manages permission flow, loading states, sensor waiting |
| | `StarInfoPanel` | Glassmorphism overlay for selected star details |
| | `SkyDock` | Bottom toggle bar for horizon, constellations, and selection mode |

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
| `equatable` | 2.1.0 | Value equality for BLoC states and events |
| `geolocator` | ^14.0.3 | GPS location services with permission handling |
| `sensors_plus` | ^7.1.0 | Declared dependency (actual sensor reading is custom native code) |
| `cupertino_icons` | ^1.0.8 | iOS-style icon pack |

### Dev Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_test` | (SDK) | Testing framework |
| `flutter_lints` | ^6.0.0 | Static analysis lint rules |

### Native Code

- **Android:** Custom `MainActivity.kt` (261 lines) implementing an `EventChannel` bridge that reads `Sensor.TYPE_ROTATION_VECTOR`, computes the rotation matrix, adjusts for display rotation, and sends 9-axis camera-basis vectors (right/up/back) to Flutter
- **iOS / Desktop / Web:** Boilerplate only — no custom native implementations

---

## Project Structure

```
sky-map/
├── lib/                                # Main Dart source code (3,669 lines)
│   ├── main.dart                       # Entry point
│   ├── app/
│   │   ├── app.dart                    # Root MaterialApp widget
│   │   └── theme/
│   │       ├── app_colors.dart         # Centralized color palette
│   │       └── app_theme.dart          # Dark theme definition
│   ├── astronomy/
│   │   ├── coordinate_converter.dart   # RA/Dec → Az/Alt conversion
│   │   ├── sky_coordinates.dart        # Horizontal → unit vector
│   │   └── sun_calculator.dart         # Apparent Sun position + trajectory
│   ├── blocs/
│   │   └── sky/
│   │       ├── sky_bloc.dart           # Central BLoC (499 lines)
│   │       ├── sky_event.dart          # 8 sealed event types
│   │       └── sky_state.dart          # Immutable state (236 lines)
│   ├── models/
│   │   ├── celestial_object.dart       # Generic celestial object enum + model
│   │   ├── celestial_position.dart     # Az/Alt value object
│   │   ├── celestial_trajectory.dart   # World-vector trajectory
│   │   ├── constellation.dart          # Constellation data model
│   │   ├── device_orientation.dart     # 9-axis orientation + az/alt
│   │   ├── observer_location.dart      # Lat/lon/alt
│   │   └── sky_star.dart               # Star catalog entry model
│   ├── screens/
│   │   └── sky_screen.dart             # Main screen (267 lines)
│   ├── services/
│   │   ├── constellation_service.dart  # Loads constellations from JSON asset
│   │   ├── location_service.dart       # GPS via geolocator
│   │   ├── orientation_service.dart    # EventChannel bridge to native sensors
│   │   └── star_catalog_service.dart   # Loads stars from JSON asset
│   └── widgets/
│       ├── sky_dock.dart               # Bottom toggle bar
│       ├── sky_painter.dart            # CustomPainter star field renderer (1,149 lines)
│       ├── star_hit_tester.dart        # Tap-to-select star detection
│       └── star_info_panel.dart        # Glassmorphism info overlay
├── assets/
│   └── data/
│       ├── stars.json                  # 909 stars — Yale Bright Star Catalog
│       └── constellations.json         # 88 IAU constellation stick figures
├── data/                               # Raw source data for generation scripts
│   ├── catalog.dat.gz                  # Yale Bright Star Catalog (gzipped)
│   ├── constellation_lines_hr.dat      # Constellation line definitions
│   └── iau_proper_stars.csv            # IAU proper star names + metadata
├── scripts/
│   ├── generate_stars.py              # catalog.dat.gz → stars.json
│   └── generate_constellations.py     # HR lines → constellations.json
├── android/                            # Android platform project
│   └── app/src/main/
│       ├── AndroidManifest.xml         # Location permissions
│       └── kotlin/.../MainActivity.kt  # Native sensor bridge (261 lines)
├── ios/                                # iOS platform (boilerplate)
├── web/                                # Web platform (boilerplate)
├── linux/                              # Linux desktop (boilerplate)
├── macos/                              # macOS desktop (boilerplate)
├── windows/                            # Windows desktop (boilerplate)
├── test/                               # Tests (currently empty)
├── pubspec.yaml                        # Flutter project manifest
├── analysis_options.yaml               # Dart linter configuration
└── README.md                           # This file
```

---

## Getting Started

### Prerequisites

- **Flutter SDK** ^3.12.2 (stable channel)
- **Android SDK** with API level 21+ (minSdk 21)
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

- **Source:** Yale Bright Star Catalog (`data/catalog.dat.gz`) — 909 bright stars
- **Supplemental data:** IAU proper star names (`data/iau_proper_stars.csv`)
- **Generator:** `scripts/generate_stars.py`
- **Output:** `assets/data/stars.json` (145,537 lines)

```bash
python3 scripts/generate_stars.py
```

### Constellation Lines

- **Source:** IAU constellation stick-figure definitions (`data/constellation_lines_hr.dat`)
- **Generator:** `scripts/generate_constellations.py`
- **Output:** `assets/data/constellations.json` (2,229 lines)

```bash
python3 scripts/generate_constellations.py
```

### Data Fields

**Stars** include: HR number, common name, IAU name, Bayer designation, constellation, right ascension, declination, apparent magnitude, spectral type, and color index.

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

- [x] Star field rendering (909 stars, magnitude-based sizing, spectral-type coloring)
- [x] Device orientation tracking via custom native Android EventChannel
- [x] GPS location acquisition with permission handling and fallback
- [x] Equatorial-to-horizontal coordinate conversion pipeline
- [x] Sun position calculation and 24-hour trajectory rendering
- [x] Constellation stick-figure rendering (88 IAU constellations) with highlight-on-select
- [x] Star tap-to-select with hit testing
- [x] Star info panel with comprehensive metadata display
- [x] Bottom dock controls (horizon, constellations, selection mode toggles)
- [x] Horizon line with compass labels
- [x] Immersive full-screen mode
- [x] Dark theme
- [x] Data generation pipeline (Python scripts for star/constellation catalogs)
- [x] Performance optimization pass

### Planned / Not Yet Implemented

- [ ] **Unit and widget tests** — `test/widget_test.dart` is currently empty
- [ ] **iOS native sensor bridge** — Core Motion `EventChannel` implementation
- [ ] **Sun tap detection** — `SkySunTapped` event is wired but no UI hit-testing exists
- [ ] **Planets and Moon** — `CelestialObject` model is defined but not integrated
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
- **Rendering:** Single `CustomPainter` (`SkyPainter`) handles all sky rendering in layered passes
- **Native code:** Kotlin for Android sensor bridge; Flutter `EventChannel` for communication
- **Assets:** Star and constellation data loaded from bundled JSON files at startup

### Project Layout

- `lib/astronomy/` — Pure astronomical math (no Flutter dependencies)
- `lib/blocs/` — State management (BLoC pattern)
- `lib/models/` — Immutable data models
- `lib/services/` — Platform service abstractions
- `lib/widgets/` — UI components and custom painters
- `scripts/` — Data pipeline utilities (Python)

---

## License

> **License to be determined.** Please contact the project maintainer for licensing information.

---

<p align="center"><sub>Built with Flutter · Dart · Android · A love for the night sky</sub></p>
