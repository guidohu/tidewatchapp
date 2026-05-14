# Surf Tracker

Surf Tracker is a premium Garmin application designed for surfers. It combines real-time tide and swell data with a robust activity tracker that automatically detects and records your waves, paddle strokes, and surfing metrics.

![Surf Tracker Screenshot](img/Screenshot%202026-04-03%20at%2012.54.18.png)

If you like this app, please consider supporting its development:

[![Sponsor this Work](https://img.shields.io/badge/Sponsor_this_Work-guidohu-orange?style=for-the-badge&logo=github-sponsors)](https://github.com/sponsors/guidohu)

## Key Features

### 🌊 Surf Activity Tracking
- **Automatic Wave Detection**: Intelligently tracks every wave you catch using speed, distance, and accelerometer-based motion verification.
- **Advanced Metrics**: Records comprehensive session data, including:
  - **Total Waves**: The count of validated wave rides.
  - **Longest Wave**: The single longest distance covered on a wave.
  - **Max Wave Speed**: Your peak speed reached during a ride.
  - **Surf Time**: Total time spent actively riding waves.
  - **Paddle Strokes**: Estimates your paddling effort during the session.
  - **Total Wave Distance**: Cumulative distance covered on waves.
- **Connect IQ Data Integration**: Metrics are synced to Garmin Connect and displayed in a dedicated "Developer Data" section for detailed post-surf analysis.
- **Adaptive GPS (Lull Mode)**: Intelligently manages GPS frequency to conserve battery during long waits between sets, while instantly ramping up for "Take-off" detection.

### 📅 Tide & Swell Intelligence
- **High-Resolution Graphs**: Visualize tide trends and optional swell height layers directly on your wrist.
- **Global Data**: Automatically fetches tide data based on your GPS location.
- **Stormglass.io Integration**: Detailed swell info including height, period, and direction (requires personal API key).

### 🎨 Personalization & Performance
- **Customizable Units**: Toggle between Metric (Meters) and Imperial (Feet) for all metrics.
- **Rich Design System**: Curated color palettes (Petrol, Turquoise, etc.) and modern typography for maximum readability.
- **Efficient Background Sync**: Keeps conditions up-to-date with minimal battery impact.

## Configuration

1.  **Location**: The app uses your GPS location to fetch local tide data. You can also manually set coordinates in the settings.
2.  **Swell Data (Optional)**: To enable swell information, provide an API key from [stormglass.io](https://stormglass.io) in the app settings.
3.  **Units & Appearance**: Personalize unit preferences and UI colors via Garmin Connect IQ.

## Supported Devices

Surf Tracker supports a wide range of modern Garmin wearables, including:

- **Fenix** (5 Plus, 6, 7, 8, E and all Solar/Pro editions)
- **Forerunner** (55, 165, 245, 255, 265, 945, 955, 965, 970)
- **Venu** (Original, 2, 3, 4, Sq, Sq 2)
- **Instinct** (2, 2s, 2x, 3, Crossover)
- **Descent** (G1, G2, Mk2, Mk3)
- **Epix** (Gen 2, Pro editions)
- **Enduro** (Original, 3)
- **MARQ** (Original and Gen 2)
- **Vivoactive** (3m, 4, 5, 6)
- **Approach** (S50, S70)

## License

**Copyright (c) 2026 Surf Tracker Developers**

This software is free to use for personal purposes. You are **strictly prohibited** from forking, modifying, editing, or redistributing the source code or any derivative works of this App.

The software is provided "as is", without warranty of any kind.

