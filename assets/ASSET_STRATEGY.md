# Asset strategy — getting ~2.8 GB onto a phone

Measured (2026-09-19, `tools/Audit-SVCAssets.ps1`): **1,165 files, 2,810 MB.**

| Bucket | Size | Ship? |
|---|---|---|
| `chars/` | 1,914 MB | roster-dependent (Lite cut) |
| `data/` | 410 MB | yes (system) |
| `stages/` | 172 MB | curated subset + packs |
| `sound/` | 134 MB | yes, compress long BGM later |
| `font/` | 19 MB | yes |
| `video/` | 3 MB | yes if FFmpeg/iOS lands, else skip |
| `external/` | 2 MB | scripts/shaders — yes |
| `lib/*.dll` | 10 MB | NO (Windows-only) |
| `*/backup/*.zip` | ~734 MB | NO (dev leftovers, incl. byte-identical dupes) |
| `Ikemen_GO.exe`, `docs/`, logs | ~15 MB | NO |

Post-strip device payload ≈ **2.0–2.1 GB** — still far too big for a practical
`.ipa` and unhostable on GitHub (100 MB/file cap, 1 GB free LFS).

## Plan

1. **S1 Lite in the `.ipa`** (~300–500 MB): `data/`, `system`/`fight` motif,
   4–8 showcase fighters, 2–3 stages, core `sound/`/`font/`. Proves the port.
2. **Full roster as CDN packs**: private object storage (R2/S3/NAS) with
   `chars/<Fighter>.zip`, `stages/pack-*.zip` + signed URLs + SHA-256 manifest.
3. **In-app downloader** (port ikemen-droid's `AssetExtractor` concept):
   first launch → Lite check → background fetch → unzip into `Documents/`
   (iOS sandbox: app home only). Resume + per-pack delete.
4. This repo tracks ONLY `assets/manifest.txt` (inventory) + pack definitions.
   Raw assets never touch git.
