# Changelog

All notable changes to OpenedWindow are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions are the app's own `VERSION` in `manifest.ini`.

## [1.1.3] - 2026-10-16

### Fixed
- Tyre attenuation never applied: the code matched the channel key `tires`, but Assetto Corsa's car audio channel is spelled `tyres` — the branch never matched and tyres stayed at generic volume.

## [1.1.2] - 2026-10-16

### Added
- Tyres are 1.75× quieter in INTERIOR mode and ramp back to their default volume as the window opens (blended with the open-window progress).

## [1.1.1] - 2026-10-16

### Changed
- Window animation runs at its own smooth linear tempo inside the 3.5 s window (no 75 %/25 % audio kick curve applied to the animation).
- `cockpitOnly` / camera changes now snap the audio mix instantly (they are a setting, not the toggle); the main toggle keeps the 3.5 s ramp.
- Animation and exterior-mix checkboxes moved to the Extra tab (above wind settings, with a hint).
- "Reset to defaults" also resets the window/wind sounds toggle.
- App window widened so slider labels and values fit inside the border.

### Fixed
- Animation nodes are re-found every frame instead of cached — fixes the animation dying after switching to an exterior camera (scene rebuild invalidated the cached references).

## [1.1.0] - 2026-10-16

### Added
- Window animation integration: when the car ships window open/close `.ksanim` files (validated detection: filename filter + window node names inside the ksanim), the same bound toggle that plays the motor sound also drives the car's own window animation in sync with the audio ramp.
- Animation on/off checkbox, per-car auto-detection with re-detection on car swap, animation status line, and log lines.

### Fixed
- Latent dot-syntax file-handle bugs (`f.write`/`f.close` → `f:write`/`f:close`).

## [1.0.2] - 2026-10-14

### Changed
- Exterior window-motor volume 0.5 → 0.25.
- Long UI texts now wrap so they cannot overflow a narrowed app window.

## [1.0.1] - 2026-10-14

### Changed
- Renamed from WindowAudioSwitch to OpenedWindow; install path is `apps/lua/OpenedWindow/OpenedWindow.lua`.
- Control binding renamed to `OpenedWindow.toggle` (existing key assignments must be redone once).

## [1.0.0] - 2026-10-14 (as WindowAudioSwitch)

### Added
- Initial app: bound toggle switches the car audio mix between interior (cabin) and open-window (exterior) with a 3.5 s motor-like ramp (75 % kick at start/end); window motor one-shot sounds; speed-dependent wind layer (low/high loop crossfade, open-window only); interior/outside-gain/motor/wind volume sliders with middle-click reset; cockpit-only mode; CSP exterior-audio blend; re-baseline; debug overlay + log with clipboard export; settings persistence via CSP `scriptSettings`.
