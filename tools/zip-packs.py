#!/usr/bin/env python3
"""zip-packs.py — deterministic zip with forward-slash entry names (iOS-safe).
Windows Compress-Archive writes backslashes, which extract as literal
filenames on iOS. Usage: zip-packs.py <src-dir> <out.zip>
"""
import os
import sys
import zipfile

src, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for root, _, files in os.walk(src):
        for f in sorted(files):
            full = os.path.join(root, f)
            arc = os.path.relpath(full, src).replace(os.sep, "/")
            z.write(full, arc)
print(f"wrote {out}")
