#!/usr/bin/env python3
"""collapse-dups.py — collapse accidentally duplicated appended patch blocks."""
VULKAN = '\tif runtime.GOOS == "ios" {\n\t\tcfg.Video.RenderMode = "Vulkan 1.3"\n\t}\n'
ORIENT = '\t\tif runtime.GOOS == "ios" {\n\t\t\tsdl.SetHint(sdl.HINT_ORIENTATIONS, "LandscapeLeft LandscapeRight")\n\t\t}\n'
FULLSCREEN = '\t\tif runtime.GOOS == "ios" {\n\t\t\tfullscreen = true\n\t\t}\n'
BOUNDS = ('\t\tif runtime.GOOS == "ios" && fullscreen {\n'
          '\t\t\tw2, h2 = 0, 0\n'
          '\t\t}\n')

jobs = [
    ('F:/svc-engine/src/main.go', VULKAN),
    ('F:/svc-engine/src/main.go', ORIENT),
    ('F:/svc-engine/src/system_sdl.go', FULLSCREEN),
    ('F:/svc-engine/src/system_sdl.go', BOUNDS),
]

for path, block in jobs:
    t = open(path, newline='').read()
    rounds = 0
    while t.count(block) > 1:
        t = t.replace(block + block, block)
        rounds += 1
    open(path, 'w', newline='').write(t)
    print(path.split('/')[-1], 'rounds:', rounds, 'remaining:', t.count(block))
