# Installing OpenedWindow

## Requirements

| Requirement | Notes |
|---|---|
| **Assetto Corsa** (Steam) | the app runs inside the game |
| **[Custom Shaders Patch](https://github.com/ac-custom-shaders-patch/acc-extension-config) (CSP)** | OpenedWindow is a CSP Lua app — it will not appear without CSP installed and enabled |
| **[Content Manager](https://www.contentmanager.eu/)** (recommended) | the easiest way to enable the app and bind its key |

## 1. Copy the app

1. Download **`OpenedWindow_v1.1.3.zip`** from the [latest release](../../releases).
2. Unzip it. You should get a folder named `OpenedWindow`.
3. Copy that folder into your Assetto Corsa **`apps\lua`** directory:

   ```
   D:\SteamLibrary\steamapps\common\assettocorsa\apps\lua\OpenedWindow\
   ```

   (Find the right drive in Content Manager: **Settings → Help → Open Content Manager log folder** hints, or just use the folder where AC is installed.)

4. Check the structure — the `.lua` file must sit **directly inside** the `OpenedWindow` folder, not nested one level deeper:

   ```
   apps\lua\OpenedWindow\
   ├── OpenedWindow.lua     ← must be here
   ├── manifest.ini
   ├── icon.png
   └── sounds\
       ├── window_open.mp3
       └── window_close.mp3
   ```

   A common mistake is unzipping to `apps\lua\OpenedWindow\OpenedWindow\...` — the app will not show up.

## 2. Start the app

1. **Restart Assetto Corsa** (apps are only scanned at startup).
2. Open the app from the CSP **apps bar** at the top of the screen (the row of app icons; look for the OpenedWindow icon).
3. If it is not in the list: Content Manager → **Settings → Custom apps** → find *OpenedWindow* → enable it, then restart AC.

## 3. Bind the toggle key

The app exposes one control: **`OpenedWindow.toggle`**.

- Content Manager: **Settings → Steering wheel & pedals / Controls** → search for `OpenedWindow.toggle` → assign a keyboard key, wheel button or gamepad button.
- The binding is stored by CSP itself — it works in-game **even when the app window is closed**.
- In the app's own UI you can also **Clear / Re-enable binding**.
- Upgrading from v1.0.0? The binding name changed to `OpenedWindow.toggle` in v1.0.1 — assign the key once.

## 4. Verify it works

1. Load a car that ships window animations (e.g. the Nissan 240SX mod) — the app header shows `Animation: 2 window ksanim: ...`.
2. Press your bound key: windows roll down over ~3.5 s with the motor sound, and the audio mix shifts to "window open" (exterior sounds louder, tyres louder). Press again to roll them up.
3. On a car **without** window animations the header shows `Animation: no window ksanim ...` — the audio part still works, windows simply don't move. That is expected: window animation requires the car to ship its own `.ksanim` window animation.

## 5. Optional: wind sounds

The wind layer is built in but silent until you add two **loopable** recordings to `sounds\`:

- `wind_low.*` — low-speed wind loop
- `wind_high.*` — high-speed wind loop

They activate automatically: wind fades in from 40 to 120 km/h, crossfading low→high, only while the window is open.

## Files the app creates

| File | Location |
|---|---|
| Settings | `Documents\Assetto Corsa\cfg\extension\state\lua\app\OpenedWindow\settings.ini` |
| Debug log | `Documents\Assetto Corsa\cfg\extension\state\lua\app\OpenedWindow.log` |

## Uninstall

Delete the `apps\lua\OpenedWindow\` folder (and, optionally, the settings/log files above). Nothing else touches your AC install.

## Troubleshooting

| Symptom | Fix |
|---|---|
| App not in the apps bar | Wrong folder nesting (see step 1.4); CSP not installed/enabled; AC not restarted; app disabled in CM → Custom apps |
| Key does nothing | Key not bound to `OpenedWindow.toggle`; binding cleared (use **Re-enable binding** in the app UI) |
| Windows don't move | The car has no window `.ksanim` — audio-only by design |
| Windows and sound out of sync | Should not happen in v1.1.3 (animation has its own smooth tempo inside the 3.5 s ramp) — report it |
| Two apps fighting over windows | Remove any separate window-animation app (e.g. WindowAnimation) from `apps\lua` |
