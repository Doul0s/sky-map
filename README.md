# Sky Map — Technical Reference & Architecture

**A sensor-driven astronomical visualization for Flutter & Android**

---

## Overview

Sky Map turns your phone into a window to the stars. It combines:

- Your GPS location
- A catalog of star positions
- The current time and Earth's rotation
- Your phone's orientation sensors
- Interactive 3D rendering

The core idea is simple: **calculate the sky slowly, update the view fast.**

---

## How It Works — The Big Picture

```
┌─────────────────────────────────────────────────────────────────┐
│                         YOUR PHONE                              │
│                                                                 │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│   │    GPS      │    │    Clock    │    │   Sensors   │         │
│   │  Location   │    │     UTC     │    │  Rotation   │         │
│   └──────┬──────┘    └──────┬──────┘    └──────┬──────┘         │
│          │                  │                  │                │
│          ▼                  ▼                  ▼                │
│   ┌──────────────────────────────────────────────────┐          │
│   │              Sky Engine                          │          │
│   │  • Converts star positions to local sky          │          │
│   │  • Computes horizon & constellations             │          │
│   │  • Projects everything onto your screen          │          │
│   └──────────────────────────────────────────────────┘          │
│                              │                                  │
│                              ▼                                  │
│                    ⭐ You see the stars!                        │
└─────────────────────────────────────────────────────────────────┘
```
