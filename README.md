# SVC S1 — Native iOS Port

Private port project: **SEGA vs CAPCOM: The Next Level (S1)** — Ikemen GO `v1.0.0-rc.2`
Windows game (`F:\Z E FOLDER\zzzzzzzzzzTEMPS\Sega VS Capcom S1`, 2.81 GB, 1,165 files)
→ native iOS app, sideloaded (Sideloadly/AltStore + Apple ID re-sign).

**Status: Phase 0 — scaffold + cloud-Mac CI spike.** No playable build yet.
See `PORTING.md` for the full plan and `assets/ASSET_STRATEGY.md` for the
2.8 GB → device strategy.

## Layout

- `ios-wrapper/SVCiOS/` — native ObjC shell (programmatic UIKit, no storyboards/XIBs),
  touch gamepad stub, `Info.plist`, `project.yml` (xcodegen).
- `.github/workflows/ios.yml` — macOS CI: Go engine → iOS lib, SDL2 xcframework,
  xcodebuild, unsigned `.ipa` artifact.
- `engine.pin` — pinned upstream engine ref + toolchain versions.
- `tools/Audit-SVCAssets.ps1` — Windows asset audit / manifest generator.
- `assets/manifest.txt` — full file inventory (`relative/path|bytes`).
- `assets/ASSET_STRATEGY.md` — CDN + on-device downloader plan.

## Key insight (why this can work)

Ikemen GO already ships an **OpenGL-ES2 mobile rendering path** for Android
(`build/build.sh android` compiles with `-tags=android,gles2`, `RenderMode =
OpenGL ES 3.2` in `save/config.ini`). iOS has no desktop OpenGL — the port
reuses the GLES2 path under `GOOS=ios`, exactly as `ikemen-droid` reuses the
engine core as `libmain.so` behind a Java wrapper. Here the wrapper is ObjC/UIKit.

## Rules

- Sideload-only. This fan game will not pass App Store review (unlicensed
  Sega/Capcom/SNK roster, 2+ GB payload, Lua/ZSS scripting).
- Ad-hoc/unsigned CI artifacts; re-sign locally before installing.
- Game assets are NEVER committed (see `.gitignore`). They ship via downloader.
- No secrets, certs, or provisioning profiles in this repo — ever.
