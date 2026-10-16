#!/usr/bin/env python3
"""Build the OpenedWindow release zip.

Creates dist/OpenedWindow-v<version>.zip with a single root folder
OpenedWindow/ containing exactly:
    manifest.ini, OpenedWindow.lua, icon.png, sounds/, README.md, LICENSE,
    docs/INSTALL.md
Excludes .git, dist/, settings.ini, tools/, __pycache__ and everything else.
Version is read from manifest.ini. Stdlib only.

Usage: python tools/make_release.py   (run from the repo root)
"""
import re
import sys
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ROOT_NAME = "OpenedWindow"

FILES = ["manifest.ini", "OpenedWindow.lua", "icon.png", "README.md", "LICENSE"]
DIRS = ["sounds"]                      # whole sounds/ folder
DOCS = ["docs/INSTALL.md"]             # only INSTALL.md from docs/

EXCLUDED_NAMES = {"settings.ini", ".git", "dist", "tools", "__pycache__"}


def read_version() -> str:
    text = (REPO / "manifest.ini").read_text(encoding="utf-8", errors="replace")
    m = re.search(r"^\s*VERSION\s*=\s*([0-9][0-9.]*)\s*$", text, re.M)
    if not m:
        sys.exit("ERROR: VERSION not found in manifest.ini")
    return m.group(1).strip()


def collect() -> list[tuple[Path, str]]:
    entries: list[tuple[Path, str]] = []
    for rel in FILES + DOCS:
        p = REPO / rel
        if not p.is_file():
            sys.exit(f"ERROR: required file missing: {rel}")
        entries.append((p, rel))
    for d in DIRS:
        base = REPO / d
        if not base.is_dir():
            sys.exit(f"ERROR: required folder missing: {d}")
        for p in sorted(base.rglob("*")):
            if p.is_file() and not any(part in EXCLUDED_NAMES for part in p.parts):
                entries.append((p, str(p.relative_to(REPO)).replace("\\", "/")))
    return entries


def main() -> None:
    version = read_version()
    dist = REPO / "dist"
    dist.mkdir(exist_ok=True)
    zip_path = dist / f"{ROOT_NAME}-v{version}.zip"

    entries = collect()
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for src, rel in entries:
            assert src.name != "settings.ini", "settings.ini must never ship"
            zf.write(src, f"{ROOT_NAME}/{rel}")

    print(f"Built: {zip_path}")
    with zipfile.ZipFile(zip_path) as zf:
        names = zf.namelist()
    print("Zip contents:")
    for n in names:
        print("  ", n)
    roots = {n.split("/")[0] for n in names}
    assert roots == {ROOT_NAME}, f"bad root folder(s): {roots}"
    assert not any(n.endswith("settings.ini") for n in names), "settings.ini leaked!"
    print(f"OK: single root '{ROOT_NAME}/', no settings.ini, version {version}")


if __name__ == "__main__":
    main()
