# OpenedWindow

One bound key in [Assetto Corsa](https://store.steampowered.com/app/244210/Assetto_Corsa/) that rolls your car's windows, plays the motor sound, and switches the audio mix between cabin and exterior — all in sync, on the [Custom Shaders Patch](https://github.com/ac-custom-shaders-patch/acc-extension-config) (CSP) Lua apps system.

![version](https://img.shields.io/badge/version-v1.1.3-blue) ![license](https://img.shields.io/badge/license-MIT-green) ![platform](https://img.shields.io/badge/platform-Assetto%20Corsa%20%2B%20CSP-orange)

## Quick start

1. Download `OpenedWindow_v1.1.3.zip` from [Releases](../../releases); unzip the `OpenedWindow` folder into `<Assetto Corsa>\apps\lua\` (the folder **must** be named `OpenedWindow`).
2. Restart Assetto Corsa and open OpenedWindow from the CSP apps bar.
3. Bind `OpenedWindow.toggle` to a key (Content Manager → Settings → Controls) and press it in-game.

Full guide with structure checks and troubleshooting: **[docs/INSTALL.md](docs/INSTALL.md)**.

## What it does

- **Rolls the car's windows visually** — drives the car's own `.ksanim` window animation. **Requires the car to ship a window animation** (e.g. Nissan 240SX, Datsun 510); cars without one keep the full audio behavior and no window animation plays.
- **Plays the window motor sound** — one-shot open/close recordings with volume control.
- **Switches the audio mix** — closed = cabin mix; open = exterior sounds (traffic, opponents, track ambience, tyres) ramp up over a 3.5 s motor-like ramp. Tyres are 1.75× quieter in interior mode and return to default volume fully open.

A wind layer (speed-dependent, crossfading low/high loops, open-window only) is implemented and activates automatically once `wind_low` / `wind_high` loopable recordings are placed in `sounds/`.

## Requirements

- Assetto Corsa (Steam)
- [Custom Shaders Patch](https://github.com/ac-custom-shaders-patch/acc-extension-config) — any recent build; TODO: verify exact minimum CSP version
- [Content Manager](https://www.contentmanager.eu/) recommended (for enabling the app and binding the key)

## Install

Recommended: unzip the **Releases** zip so the app lands at:

```
<Assetto Corsa>\apps\lua\OpenedWindow\OpenedWindow.lua
```

The app folder must be named `OpenedWindow` and contain `OpenedWindow.lua` directly (no double nesting). Restart AC after installing. Step-by-step with structure check: [docs/INSTALL.md](docs/INSTALL.md).

## Usage & key binding

- The app exposes one control: **`OpenedWindow.toggle`** — bind it in Content Manager → Settings → Controls (keyboard, wheel or gamepad). CSP stores the binding; it works in-game even with the app window closed.
- Press once: windows roll down, motor sound plays, mix ramps to "window open" over 3.5 s. Press again: everything reverses. Mid-roll reversal is smooth from the current position.
- Camera in/out and cockpit-only changes snap the mix instantly; the main toggle keeps the 3.5 s ramp.
- The header status line shows the detected window animation for the current car; the app re-detects on car swap.

## Settings

| Setting | Range | Default | What it does |
|---|---|---|---|
| Interior mix volume | 0–150 % | 100 % | Scales the cabin (interior) channels in closed-window mode |
| Outside sounds gain | 1.0–4.0× | 2.0× | Multiplier for exterior sounds (traffic, opponents, track) in open mode |
| Window motor volume | 0–100 % | 80 % | Loudness of the motor one-shots (live test loop available) |
| Wind volume (at high speed) | 0–100 % | 70 % | Loudness of the wind loops at full speed (open window only) |
| Wind starts fading in at | 0–100 km/h | 40 km/h | Speed where wind begins to fade in |
| Full wind reached at | 20–200 km/h | 120 km/h | Speed where wind reaches full volume |
| Only apply when camera is inside the car | on/off | on | Mix applies to interior camera only (snaps instantly on camera switch) |
| Blend real exterior game audio | on/off | on | Blends CSP's built-in exterior audio in open mode |
| Enable window/wind sounds | on/off | on | Master switch for the motor/wind sound layers |
| Animate car windows with the toggle | on/off | on | Drives the car's own window ksanim (Extra tab) |

Transition time is fixed at 3.5 s (matches the motor sound + tail; the slider was removed after testing). All sliders support middle-click reset; a Re-baseline action re-captures the car's current channel volumes as the closed-window baseline; settings persist across restarts.

## Known limitations

- CSP global channel volumes are capped at 1.0 — channels can be attenuated below baseline but not boosted past it.
- Cars **without** window `.ksanim` files get audio only — window geometry is car-specific.
- Wind loop recordings (`wind_low`, `wind_high`) are **not included**; the wind layer activates automatically once you add them to `sounds/`.
- Other apps that also set car audio volumes (e.g. Car Volume Adjuster) can fight this app for the same channels — run one mix app at a time.
- Window state is per-session: car swap and game restart reset to closed/interior.

## Troubleshooting

App not listed, key dead, windows not moving, app conflicts — see the troubleshooting table in **[docs/INSTALL.md](docs/INSTALL.md)**.

<!-- TODO screenshots: add docs/img/screenshot-app.png (app UI) and docs/img/demo.gif (window roll + audio switch in action), then reference them in a Screenshots section below. -->

## Files

| Path | Purpose |
|---|---|
| `OpenedWindow.lua` | the app (v1.1.3) |
| `manifest.ini` | CSP app manifest |
| `icon.png` | app icon |
| `LICENSE` | MIT code license |
| `sounds/` | motor one-shots + [asset credits](sounds/README.md) |
| `docs/INSTALL.md` | full installation & key-binding guide |
| `docs/test_suite.md` | manual in-game test suite (all PASS on v1.1.3) |

## Credits and third-party

- **Made by prcd** with AI assistance — the app was designed, coded and debugged together with an AI agent running the **qwen3.8-flash-next** model (Hermes Agent, Nous Research). All in-game verification was done manually by the author.
- **[Custom Shaders Patch (CSP)](https://github.com/ac-custom-shaders-patch/acc-extension-config)** by the ac-custom-shaders-patch team — the Lua apps system, audio APIs (`ac.setAudioVolume`, `ac.AudioEvent`, `ac.INIConfig.scriptSettings`) and `setAnimation` this app builds on.
- **Assetto Corsa** by Kunos Simulazioni — the game and its per-car `.ksanim` window animations.
- No third-party example apps were copied into this codebase; the CSP audio and app APIs were used directly.
- **Sound files** in `sounds/` are not covered by the MIT code license — see [sounds/README.md](sounds/README.md) for source/license status.
- Code license: **MIT** (see [LICENSE](LICENSE)).
