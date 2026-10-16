# OpenedWindow

An [Assetto Corsa](https://store.steampowered.com/app/244210/Assetto_Corsa/) app for the [Custom Shaders Patch](https://github.com/ac-custom-shaders-patch/acc-extension-config) (CSP) Lua apps system.

One bound key does three things at once, in sync:

1. **Rolls the car's windows visually** — the app auto-detects the car's own window `.ksanim` animation files and drives them. **This requires the car to ship a window animation** (e.g. Nissan 240SX, Datsun 510); cars without one simply keep the audio behavior and no window animation plays;
2. **Plays the window motor sound** (one-shot, with pitch/volume control);
3. **Switches the audio mix** — with the window closed you hear the cabin (interior channels quieter, engine/transmission scaled by the interior slider); with the window open, sounds from outside the car (traffic, opponents, track ambience, tyres) get louder over a 3.5 s motor-like ramp. Tyres are 1.75× quieter in interior mode and return to default volume fully open.

A wind layer (speed-dependent, crossfading low/high loops, open-window only) is implemented and activates automatically once `wind_low` / `wind_high` loopable recordings are placed in `sounds/`.

## Install

Copy the `OpenedWindow` folder to:

```
<Assetto Corsa>\apps\lua\OpenedWindow\
```

(e.g. `D:\SteamLibrary\steamapps\common\assettocorsa\apps\lua\OpenedWindow\`), restart the game, then enable the app in CSP app settings and bind the toggle key.

→ **Full step-by-step guide (requirements, folder-structure check, key binding, verification, wind sounds, uninstall, troubleshooting): [docs/INSTALL.md](docs/INSTALL.md)**

## Features

- 3.5 s motor-like transition ramp (main toggle); setting changes (camera in/out, cockpit-only tick) snap instantly
- Per-car auto-detection of window animations; re-detects on car swap
- Interior/exterior gain sliders, motor volume/pitch, wind volume
- Re-baseline: re-capture the car's current channel volumes as the closed-window baseline
- Debug overlay + scrollable debug log with clipboard export
- Settings persist via CSP `scriptSettings`

## Files

| Path | Purpose |
|---|---|
| `OpenedWindow.lua` | the app (v1.1.3) |
| `manifest.ini` | CSP app manifest |
| `icon.png` | app icon |
| `sounds/window_open.mp3`, `sounds/window_close.mp3` | motor one-shots |
| `sounds/wind_low.*`, `sounds/wind_high.*` | *not included* — loopable wind recordings to be supplied |
| `docs/test_suite.md` | manual in-game test suite (all PASS on v1.1.3) |
| `docs/INSTALL.md` | full installation & key-binding guide |

## Credits and third-party

- **Made by prcd** with AI assistance — the app was designed, coded and debugged together with an AI agent running the **qwen3.8-flash-next** model (Hermes Agent, Nous Research). All in-game verification was done manually by the author.
- **[Custom Shaders Patch (CSP)](https://github.com/ac-custom-shaders-patch/acc-extension-config)** by the ac-custom-shaders-patch team — the Lua apps system, audio APIs (`ac.setAudioVolume`, `ac.AudioEvent`, `ac.INIConfig.scriptSettings`) and `setAnimation` this app builds on.
- **Assetto Corsa** by Kunos Simulazioni — the game and its per-car `.ksanim` window animations.
- No third-party example apps were copied into this codebase; the CSP audio and app APIs were used directly.
- **Sound files** in `sounds/` are not covered by the MIT code license — see [sounds/README.md](sounds/README.md) for source/license status.
- Code license: **MIT** (see [LICENSE](LICENSE)).
