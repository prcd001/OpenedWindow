# OpenedWindow v1.1.0 — Manual Test Suite (2026-10-16)

App: `apps/lua/OpenedWindow/` (v1.1.0). New in v1.1.0: the bound toggle key now
**also drives the car's own window animation** (ksanim), in exact sync with the
motor-sound ramp. Plus two latent file-handle bugs fixed (`f.write`/`f.close` → colon syntax).

> **Important:** the separate WindowAnimation app (v0.4) is also installed and drives
> window animation with its own key. If both apps run at once, they fight over the
> animation (last write per frame wins). For this suite, **remove WindowAnimation from
> apps/lua** (or never press its key).

Restart AC before starting. Record PASS/FAIL per test.

## A. New: window animation integration

| # | Test | Steps | Expected | Result |
|---|------|-------|----------|--------|
| A1 | Detection on animation car | Load `dthwsh_nissan_240sx_c_kat`, open app | Header shows `Animation: 2 window ksanim: windowleft.ksanim, windowright.ksanim` | ✓ |
| A2 | Toggle rolls windows | Press bound key on the same car | Windows roll DOWN over ~3.5 s while motor sound plays; press again → roll UP | ✓ |
| A3 | Sync sound↔visual | Watch closely on toggle | Windows fully open at the same moment the sound ramp ends; the 75% kick (first 150 ms) is visible in both sound and window motion | ✓ |
| A4 | Mid-roll reversal | Press key again while windows are rolling | Animation reverses smoothly from current position, matching the sound reversal | ✓ |
| A5 | Animation checkbox OFF | Sounds tab → untick "Animate car windows with the toggle" → press key | Motor sound plays, windows do NOT move. Restart AC → checkbox stays unticked | ✓ |
| A6 | Animation checkbox ON again | Tick it → press key | Windows roll again | ✓ |
| A7 | Car without animation | Load any car with no window ksanim (e.g. a vanilla car) | Header shows `Animation: no window ksanim in <car folder>`; toggle still does the full audio behavior; no errors in AC debug app | ✓ |
| A8 | Car swap resets | On animation car, toggle to OPEN (windows open) → swap to another car | App resets to INTERIOR, blend 0; new car's windows closed; header shows new car's animation status | ✓ |
| A9 | Session restart | Toggle to OPEN, quit AC, start AC, load animation car | Mode INTERIOR, windows closed (mode never persisted) | ✓ |
| A10 | Camera independence | Windows rolling, switch camera exterior↔interior | Animation keeps rolling uninterrupted; audio mix behaves as before | ✓ |

## B. Regression: v1.0.2 audio features must still work

| # | Test | Steps | Expected | Result |
|---|------|-------|----------|--------|
| B1 | Mode toggle + mix ramp | Press key, watch debug "Window blend" | INTERIOR ↔ OPEN WINDOW, blend ramps 0→1 over 3.5 s (75% kick first 150 ms opening; 75% lands last 150 ms closing) | ✓ |
| B2 | Motor sounds | Toggle open / close | window_open sound on opening, window_close on closing (if file present) | ✓ |
| B3 | Wind layer | Drive 0→150 km/h in OPEN mode | Wind fades in 40→120 km/h, crossfade low→high; silent in INTERIOR | n/a — wind recordings not available yet |
| B4 | Sliders + middle-click reset | Volume tab: interior, outside gain, motor volume; middle-click each | Values change live; middle-click restores default | ✓ |
| B5 | Motor volume test loop | Volume tab → "Motor volume test" → move slider | Loop volume follows slider live; button stops it | ✓ |
| B6 | Settings persistence | Change sliders, restart AC | All values restored from settings.ini | ✓ |
| B7 | Keybind with app closed | Close app window, press bound key in-game | Toggle works (audio + animation) | ✓ |
| B8 | cockpitOnly | Tick/untick "Only apply when camera is inside the car" | Mix changes apply only to interior camera when ticked | ✓ |
| B9 | exteriorMix | Tick/untick "Blend real exterior game audio" | Open mode blends CSP exterior audio when ticked | ✓ |
| B10 | Debug + clipboard | Tick "Show debug info" → Copy all debug info | Debug includes new `Animation: ...` line; clipboard paste contains it | ✓ |
| B11 | Re-baseline | Debug tab → Re-baseline | Channel list re-read; mix returns to normal at blend 0 | ✓ |
| B12 | Reset to defaults | Volume tab → Reset to defaults | All sliders + checkboxes (incl. animation ON) return to defaults | ✓ |
| B13 | No Lua errors | Play ~10 min, watch AC debug app | Zero WindowAnimation/OpenedWindow error lines | ✓ |

## C. Log file

| # | Test | Steps | Expected | Result |
|---|------|-------|----------|--------|
| C1 | Animation detection logged | Load 2 cars, open `OpenedWindow.log` (next to settings.ini) | `anim: 2 window ksanim: ...` / `anim: no window ksanim in ...` lines with timestamps | ✓ |
| C2 | Errors logged | Trigger a missing-sound state (rename sounds folder) | Error line appended to log, app keeps working | ✓ |

## Known limitations (by design)
- Cars WITHOUT window ksanim files cannot get animation — geometry is car-specific.
- Mode/window state is per-session, never saved.
- Car swap resets to INTERIOR/closed (window is a per-car physical object).

## v1.1.1 re-test (2026-10-16)

Fixes: animation now runs at its own SMOOTH linear tempo inside the 3.5 s (no 75%/25% kick);
animation nodes re-found every frame (exterior-camera toggle now animates);
cockpitOnly/camera changes snap the mix instantly; animation + exterior-mix checkboxes
moved to Extra tab (top, above wind settings, with hint); Reset now also resets the
sounds toggle; window widened to 420 px for slider labels; Re-baseline now has a hint.

| # | Test | Expected |
|---|------|----------|
| R1 | A2/A3/A4 redo | Window rolls smooth at constant speed, full roll in 3.5 s, mid-roll reversal smooth |
| R2 | A10 redo | Toggle on EXTERIOR camera -> windows animate; toggle on interior then switch to exterior -> keeps animating |
| R3 | B8 redo | cockpitOnly tick / camera switch: mix changes INSTANTLY (no 3.5 s ramp); main toggle still ramps |
| R4 | B9 redo | exteriorMix checkbox now in Extra tab under animation tick |
| R5 | B12 redo | Reset to defaults also resets "Enable window/wind sounds" |
| R6 | Overflow | Slider labels/values fit inside window border (420 px) |
| R7 | B1-B7,B10-B11,B13 | Regression spot-check |

C1/C2 (log): PASS by agent - anim: lines with timestamps present in cfg/extension/state/lua/app/OpenedWindow.log
R1-R7: ALL PASS (2026-10-16, user in-game test) - v1.1.1 VERIFIED
Tyre mix: PASS. R1-R7 re-run on v1.1.3: ALL PASS (2026-10-16) - v1.1.3 VERIFIED, app complete pending wind sounds.
