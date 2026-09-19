# Porting plan — Windows Ikemen GO → native iOS

Source of truth for phase status. Update as spikes resolve.

## Phase 0 — Scaffold + CI spike (NOW)

- [x] Asset inventory (`assets/manifest.txt`: 1,165 files, 2.81 GB)
- [x] Dedupe audit: `backup/` zips waste ~734 MB, several byte-identical
      duplicates across `chars/*/backup/` (verified SHA-256)
- [x] Wrapper skeleton → completed shell (bridge, gamepad, downloader+miniz)
- [x] Engine iOS fork: `ZEENEE-MASTER/svc-engine-ios@ios-port`
      (25-line patch set + `src/util_ios.go`; gofmt-clean; BOM/LF verified)
- [x] S1 Lite packs built (`F:\svc-packs`, iOS-safe forward-slash zips)
- [ ] **BLOCKED: GitHub Actions billing** — runs fail in ~10 s with
      "recent account payments have failed or your spending limit needs to be
      increased". Fix: github.com → Settings → Billing and plans → update
      payment method / raise spending limit. Then re-run the `ios-port`
      workflow. No code change needed on our side.
- [ ] First green `spike-engine-ios` run on `macos-15` runner
- [ ] SDL2 xcframework builds on runner

## Phase 1 — Engine on iOS (biggest risks)

1. `GOOS=ios GOARCH=arm64` + `gles2` tag compile of engine + `go-sdl2` cgo
   against the iPhoneOS SDK. gomobile REQUIRES macOS+Xcode — hence cloud runner.
2. **FFmpeg for iOS**: engine dynamically links FFmpeg (LGPL). Android build
   compiles it via `build/ffmpeg-src`; iOS needs an equivalent
   (`ffmpeg-kit`-style or same-script retarget). Spike will say how far the
   existing script stretches.
3. **libxmp for iOS**: same treatment, smaller surface.
4. gomobile `bind` (engine as `.xcframework`) vs `build -buildmode=c-archive`
   + hand-rolled Xcode target. Try bind first (engine already depends on
   `golang.org/x/mobile`).

## Phase 2 — iOS wrapper (modeled on ikemen-droid)

- `SDL_UIKitRunApp(argc, argv, SDL_main)` bootstrap (`main.m`).
- `GamepadView` (UIView): port the *concept* of ikemen-droid's
  `DynamicGamepadView` — touch buttons → engine key events, zero-delay,
  customizable layout. Plus MFi controller via GameController.framework
  (weak-linked for older iOS, per SDL README-ios).
- Asset extractor → app `Documents/` (iOS sandbox: no access outside the
  app home; SDL README-ios confirms layout).
- Video: `.webm` intros via FFmpeg path from Phase 1; fallback: skip.
- Netplay/rollback (ggpo): needs no entitlements for basic sockets; UPnP/port
  forward is a user-network matter (`ListenPort = 7500`).

## Phase 3 — Assets + installability

- Strip: `backup/` (−734 MB), `lib/*.dll` (Windows-only), `docs/`,
  `Ikemen_GO.exe`, logs. Device payload ≈ 2.0–2.1 GB.
- Ship **S1 Lite** in the `.ipa` (system + select roster/stages) and the rest
  as CDN packs fetched by the in-app downloader (see `assets/ASSET_STRATEGY.md`).
- GitHub CANNOT host the assets (100 MB/file cap, 1 GB LFS free) — external
  private storage (R2/S3/NAS) + signed URLs.

## Phase 4 — Device testing + signing

- CI uploads unsigned `.ipa`; re-sign with Sideloadly/AltStore + Apple ID.
- Free Apple ID: 7-day cert, ~3 sideloaded apps — fine for testing.
- Test matrix: 60 fps fight, touch latency, audio (BGMason `.mp3`/`.wav`), 3D
  stages (`.glb` + `EnableModel = 1`), memory (512 explods/afterimages in config
  will need lowering on older phones — see `save/config.ini` tuning section).

## Non-goals

- App Store submission. Windows-only linking (dead end, proven in prior spike:
  stub SDK has no `.tbd`/libc++ headers; Go runtime + SDL main + UIKit
  lifecycle can't be faked with `ld64.lld`).
- UTM/VM execution of the Windows `.exe` on-device (unplayable).
