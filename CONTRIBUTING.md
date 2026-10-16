# Contributing

## Reporting bugs

Open a [bug report issue](../../issues/new?template=bug_report.yml). The most useful thing you can provide is the relevant lines from `Documents\Assetto Corsa\logs\custom_shaders_patch.log` (search for `OpenedWindow`) — most problems can be diagnosed from them alone. Include AC version, CSP version, car name, and whether the app header shows a detected window animation for that car.

Before reporting, rule out the two known conflict sources:
- another app that sets car audio volumes (e.g. Car Volume Adjuster),
- a separate window-animation app in `apps\lua` (e.g. WindowAnimation).

## Testing changes

The app is verified with the manual in-game suite: **[docs/test_suite.md](docs/test_suite.md)**. Any code change should be run through the relevant suite sections in-game (audio mix, animation, persistence, no Lua errors) before it is proposed.

## Code style notes

- The app is a single-file CSP Lua app; keep it that way.
- Never cache `ac.findNodes` SceneReferences across frames — the scene is rebuilt on camera switches and cached references silently break (this caused the v1.1.1 animation bug).
- Car audio channel keys use the British spelling (`tyres`, not `tires`).
- Lua patterns have no `|` alternation — loop over a word list instead.
- Patch the file CRLF-safely; the in-game copy is the source of truth for testing.
