# Sky Map

A real-time augmented-reality astronomical visualization for Flutter and Android.

---

## Overview

Sky Map turns your Android device into a live window to the night sky. By fusing GPS location, hardware orientation sensors, precise astronomical calculations, and full star catalog data, it renders an interactive sky that updates as you move your phone.

Point your device at the sky and see stars, constellations, the Sun, the Moon, and compass directions rendered in their correct positions — as if the screen were transparent glass.

**Design philosophy:** calculate the sky slowly, update the view fast. Celestial positions are recomputed on a background schedule (every 30 seconds); the renderer only projects precomputed world vectors to the screen on every frame.

---

## Features

- **9,096 stars** from the Yale Bright Star Catalog (HR 1–9110), rendered with magnitude-based sizing and spectral-type coloring (O/B/A/F/G/K/M)
- **414 named stars** (IAU proper names) are tappable
- **86 IAU constellation stick figures** with highlight-on-select
- **Sun** with multi-layer glow effect and 24-hour trajectory path
- **Moon** with atmospheric halo, 24-hour trajectory, live phase name (8 phases), and illuminated fraction
- **Topocentric parallax correction** using a WGS84 oblate-Earth observer model
- **Tap-to-select** for named stars and celestial bodies with a glassmorphism info panel
- **Bottom dock controls** for horizon line, constellation lines, and selection mode
- **Immersive full-screen mode** with dark theme

---

## How It Works

The application processes sensor and astronomical data in a multi-stage pipeline: raw sensor data and catalog entries are fused into equatorial coordinates, converted to the observer's local sky, and then projected onto the phone screen using perspective math.

### 1. Sensor Input

The native Android layer reads `TYPE_ROTATION_VECTOR` at `SENSOR_DELAY_GAME` rate, computes a rotation matrix, remaps it for all four display orientations, and sends 9-axis camera-basis vectors (right, up, back) plus derived azimuth/altitude to Flutter via an `EventChannel`. GPS coordinates are obtained through the `geolocator` package.

### 2. Astronomical Position Calculation

All celestial positions are computed in the **equatorial coordinate system** (Right Ascension and Declination), independent of the observer's location. Two complete calculators are implemented:

#### Sun Position

The Sun's position is calculated from low-precision solar theory. Given Julian centuries since J2000:

$$t = \frac{JD - 2451545.0}{36525.0}$$

**Geometric mean longitude:**

$$L_0 = 280.46646 + 36000.76983\,t + 0.0003032\,t^2 \pmod{360}$$

**Mean anomaly:**

$$M = 357.52911 + 35999.05029\,t - 0.0001537\,t^2$$

**Equation of the center:**

$$C = \left(1.914602 - 0.004817\,t - 0.000014\,t^2\right)\sin M + \left(0.019993 - 0.000101\,t\right)\sin 2M + 0.000289\sin 3M$$

**True longitude** then **apparent longitude** (with nutation/aberration correction):

$$\lambda = L_0 + C - 0.00569 - 0.00478\sin\Omega$$

where $\Omega = 125.04 - 1934.136\,t$.

**Mean obliquity of the ecliptic:**

$$\varepsilon_0 = 23.439291 - 0.0130042\,t - 0.000000164\,t^2 + 0.000000504\,t^3$$

**Apparent obliquity:**

$$\varepsilon = \varepsilon_0 + 0.00256\cos\Omega$$

**Ecliptic to equatorial conversion:**

$$\alpha = \operatorname{atan2}\!\left(\cos\varepsilon\,\sin\lambda,\;\cos\lambda\right)$$

$$\delta = \arcsin\!\left(\sin\varepsilon\,\sin\lambda\right)$$

#### Moon Position

The Moon's position is calculated from a reduced Meeus periodic-term lunar theory using five fundamental arguments:

| Argument | Symbol | Formula |
|----------|--------|---------|
| Moon's mean longitude | $L'$ | $218.3164477 + 481267.88123421\,t$ |
| Mean elongation | $D$ | $297.8501921 + 445267.1114034\,t$ |
| Sun's mean anomaly | $M$ | $357.5291092 + 35999.0502909\,t$ |
| Moon's mean anomaly | $M'$ | $134.9633964 + 477198.8675055\,t$ |
| Argument of latitude | $F$ | $93.2720950 + 483202.0175233\,t$ |

All reduced modulo 360 degrees.

**Ecliptic longitude** ($\Delta\lambda$ correction terms):

$$\Delta\lambda = 6.289\sin M' - 1.274\sin(M' - 2D) + 0.658\sin 2D - 0.186\sin M - 0.059\sin(2M' - 2D) - 0.057\sin(M' - 2D + M) + 0.053\sin(M' + 2D) + 0.046\sin(2D - M) + 0.041\sin(M' - M) - 0.035\sin D - 0.031\sin(M' + M) - 0.015\sin(2F - 2D) + 0.011\sin(M' - 4D)$$

$$\lambda_{\text{moon}} = L' + \Delta\lambda$$

**Ecliptic latitude** ($\beta$ correction terms):

$$\beta = 5.128\sin F + 0.281\sin(M' + F) + 0.278\sin(M' - F) + 0.173\sin(2D - F) + 0.055\sin(2D - M' + F) + 0.046\sin(2D - M' - F) + 0.033\sin(2D + F) + 0.017\sin(2M' + F)$$

**Geocentric Earth–Moon distance:**

$$r = 385000.56 - 20905.355\cos M' - 3699.111\cos(2D - M') - 2955.968\cos 2D - 569.925\cos 2M' + 246.158\cos(2D - 2M') - 204.586\cos(2D - M) - 170.733\cos(2D + M')$$

where $r$ is in km.

**Ecliptic to equatorial** (with ecliptic latitude $\beta$):

$$\alpha = \operatorname{atan2}\!\left(\sin\lambda\,\cos\varepsilon - \tan\beta\,\sin\varepsilon,\;\cos\lambda\right)$$

$$\delta = \arcsin\!\left(\sin\beta\,\cos\varepsilon + \cos\beta\,\sin\varepsilon\,\sin\lambda\right)$$

#### Moon Phase

The illuminated fraction $k$ is derived from the geocentric elongation $E$ between the Sun and Moon:

$$\cos E = \sin\delta_m\,\sin\delta_s + \cos\delta_m\,\cos\delta_s\,\cos(\alpha_m - \alpha_s)$$

$$k = \frac{1 - \cos E}{2}$$

The phase name is determined from the ecliptic longitude difference $\lambda_{\text{moon}} - \lambda_{\text{sun}}$, mapped to eight conventional phases (New Moon, Waxing Crescent, First Quarter, Waxing Gibbous, Full Moon, Waning Gibbous, Last Quarter, Waning Crescent).

### 3. Equatorial to Horizontal Conversion

Given the observer's latitude $\phi$, longitude, and the current UTC time, positions are converted from equatorial to horizontal (azimuth/altitude) coordinates.

**Julian Date:**

$$JD = \frac{\text{millisecondsSinceEpoch}}{86400000} + 2440587.5$$

**Greenwich Mean Sidereal Time:**

$$\text{GMST} = 280.46061837 + 360.98564736629 \times (JD - 2451545.0) \pmod{360}$$

**Local Sidereal Time:**

$$\text{LST} = \text{GMST} + \lambda_{\text{observer}} \pmod{360}$$

**Hour angle:**

$$H = \text{LST} - \alpha$$

**Altitude:**

$$\sin h = \sin\delta\,\sin\phi + \cos\delta\,\cos\phi\,\cos H$$

$$h = \arcsin(\sin h)$$

**Azimuth** (0 = North, 90 = East, 180 = South, 270 = West):

$$A = \operatorname{atan2}\!\left(\sin H,\;\cos H\,\sin\phi - \tan\delta\,\cos\phi\right) + \pi$$

### 4. Topocentric Parallax Correction

For nearby bodies (the Moon), the observer's position on the surface of the oblate Earth introduces a measurable shift. The WGS84 model is used.

**Auxiliary geocentric latitude:**

$$u = \arctan(0.99664719\,\tan\phi)$$

**Observer's normalized geocentric coordinates:**

$$\rho\sin\phi' = 0.99664719\,\sin u + \frac{h}{a}\sin\phi$$

$$\rho\cos\phi' = \cos u + \frac{h}{a}\cos\phi$$

where $a = 6378.137$ km (WGS84 equatorial radius) and $h$ is the observer altitude in km.

**Equatorial horizontal parallax:**

$$\sin\pi = \frac{a}{\Delta}$$

where $\Delta$ is the geocentric distance to the object.

**Right ascension correction:**

$$\tan\Delta\alpha = \frac{-\rho\cos\phi'\,\sin\pi\,\sin H}{\cos\delta - \rho\cos\phi'\,\sin\pi\,\cos H}$$

**Topocentric declination:**

$$\tan\delta' = \frac{\left(\sin\delta - \rho\sin\phi'\,\sin\pi\right)\cos\Delta\alpha}{\cos\delta - \rho\cos\phi'\,\sin\pi\,\cos H}$$

The corrected RA and Dec replace the geocentric values before the final horizontal conversion.

### 5. Horizontal to World Vector

Horizontal coordinates are converted to a unit vector in the North/East/Up world frame:

$$\vec{v} = \begin{pmatrix} \cos h\,\cos A \\ \cos h\,\sin A \\ \sin h \end{pmatrix}$$

### 6. 3D Camera Projection

The device's orientation defines an orthonormal camera basis $\{\hat{r}, \hat{u}, \hat{b}\}$ (right, up, back). A world-space unit vector $\vec{v}$ is projected into camera space via dot products:

$$x = \vec{v} \cdot \hat{r}, \qquad y = \vec{v} \cdot \hat{u}, \qquad d = \vec{v} \cdot \hat{b}$$

Points with $d \leq 0$ are behind the observer and are clipped.

**Perspective projection** onto screen coordinates (pinhole model):

$$X_{\text{screen}} = X_{\text{center}} + f\,\frac{x}{d}, \qquad Y_{\text{screen}} = Y_{\text{center}} - f\,\frac{y}{d}$$

where $f$ is the focal length (controlling field of view) and the Y-axis sign accounts for the screen's downward-positive convention.

---

## Architecture

```
GPS Location ─┐
               │
Clock (UTC) ───┤──> Sky BLoC ──> Celestial Calculators ──> Coordinate Converter ──> CameraProjector ──> SkyPainter
               │       │                    │
Sensors ───────┘       │                    │
                       │                    └──> Trajectory Samples (24h paths)
                       │
                       └──> Star/Constellation Catalogs (bundled JSON)
```

### Component Summary

| Layer | Component | Responsibility |
|-------|-----------|----------------|
| **State** | `SkyBloc` | Processes sensor events, triggers position updates, manages app state |
| **Services** | `LocationService` | GPS with permission handling, timeout, last-known fallback |
| | `OrientationService` | Native Android `EventChannel` bridge for rotation vectors |
| | `StarCatalogService` | Loads star catalog from bundled JSON |
| | `ConstellationService` | Loads constellation stick figures from bundled JSON |
| **Astronomy** | `CoordinateConverter` | Equatorial to horizontal with WGS84 topocentric parallax |
| | `SunCalculator` | Apparent Sun position and 24-hour trajectory |
| | `MoonCalculator` | Meeus lunar theory, phase facts, trajectory |
| **Rendering** | `SkyPainter` | Single `CustomPainter` handling all layered sky rendering |
| | `CameraProjector` | Shared world-to-screen projection for rendering and hit testing |
| **UI** | `SkyScreen` | Main screen with permission flow and loading states |
| | `CelestialInfoPanel` | Glassmorphism overlay for selected object details |
| | `SkyDock` | Bottom toggle bar |

---

## Tech Stack

| Technology | Version | Role |
|-----------|---------|------|
| Flutter | ^3.12.2 | UI framework |
| Dart | ^3.12.2 | Application language |
| Kotlin | 2.3.20 | Android native sensor bridge |

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_bloc` | ^9.1.1 | BLoC state management |
| `equatable` | ^2.1.0 | Value equality for states and events |
| `geolocator` | ^14.0.3 | GPS location with permission handling |

---

## Project Structure

```
sky-map/
├── lib/
│   ├── main.dart                          # Entry point
│   ├── app/                               # MaterialApp, theme, colors
│   ├── astronomy/                         # Pure astronomical math (no Flutter deps)
│   │   ├── celestial_calculator.dart      # Abstract calculator interface
│   │   ├── coordinate_converter.dart      # RA/Dec → Az/Alt + parallax
│   │   ├── moon_calculator.dart           # Meeus lunar theory
│   │   ├── sky_coordinates.dart           # Az/Alt → world unit vector
│   │   └── sun_calculator.dart            # Solar position + trajectory
│   ├── blocs/sky/                         # BLoC (events, state, bloc)
│   ├── data/                              # Celestial body registry
│   ├── models/                            # Immutable data models
│   ├── screens/                           # Main screen
│   ├── services/                          # Platform service abstractions
│   └── widgets/                           # UI, painters, projection
├── assets/data/                           # Bundled star + constellation JSON
├── data/                                  # Raw source data
├── scripts/                               # Python catalog generators
├── android/                               # Android platform (native sensor bridge)
└── pubspec.yaml
```

---

## Getting Started

### Prerequisites

- **Flutter SDK** ^3.12.2 (stable channel)
- **Android SDK** (minSdk 21+)
- **Physical Android device** with GPS and orientation sensors (required — emulators lack these sensors)
- **Python 3** (optional, only for regenerating catalogs from raw data)

### Installation

```bash
git clone https://github.com/<your-username>/sky-map.git
cd sky-map
flutter pub get
flutter run
```

### Building

```bash
flutter build apk
# or
flutter build appbundle
```

---

## Data Pipeline

Sky Map ships with pre-generated JSON asset catalogs. The raw data and Python generation scripts are included for reference.

**Star Catalog:**
- Source: Yale Bright Star Catalog (`data/catalog.dat.gz`) — 9,096 stars
- Supplemental: IAU proper star names (`data/iau_proper_stars.csv`)
- Generator: `scripts/generate_stars.py`
- Output: `assets/data/stars.json`

```bash
python3 scripts/generate_stars.py
```

**Constellation Lines:**
- Source: IAU stick-figure definitions (`data/constellation_lines_hr.dat`) — 86 of 88 IAU constellations
- Generator: `scripts/generate_constellations.py`
- Output: `assets/data/constellations.json`

```bash
python3 scripts/generate_constellations.py
```

---

## Platform Support

| Platform | Status |
|----------|--------|
| Android | Fully supported (custom native sensor bridge, GPS, immersive mode) |
| iOS | Scaffolded (requires Core Motion `EventChannel` implementation) |
| Web / Linux / macOS / Windows | Scaffolded (no sensor/GPS integration) |

---

## Graceful Degradation

- **No GPS:** Displays error message; falls back to last-known position
- **No sensors:** Shows "Waiting for sensors..." until data arrives
- **Sensor errors:** Silently caught; app continues with available data

---

## License

License to be determined. Please contact the project maintainer for licensing information.
