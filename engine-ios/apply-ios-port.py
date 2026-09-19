#!/usr/bin/env python3
"""apply-ios-port.py — turn a pristine Ikemen-GO checkout into the iOS fork.

Usage:  apply-ios-port.py <engine-dir> <path-to-util_ios.go>
Idempotent: every edit asserts exactly-once replacement (or already applied).

Edits mirror the Android mobile path for GOOS=ios:
  build tags ......................... gl33/vk off, gles32 on, desktop off
  main.go ............................ OSThread lock, mobile branch, GLES force
  system.go / system_sdl.go .......... desktop-only calls excluded on iOS
  render_gles32.go ................... log branch covers iOS
"""
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def patch(path: Path, old: str, new: str) -> None:
    # newline="": byte-exact LF handling on every OS (Go files must stay LF).
    text = path.read_text(encoding="utf-8", newline="")
    if new in text and old not in text:
        print(f"  already applied: {path.name}")
        return
    count = text.count(old)
    assert count == 1, f"{path}: expected 1 match, found {count} for: {old[:70]!r}"
    path.write_text(text.replace(old, new), encoding="utf-8", newline="")
    print(f"  patched: {path.name}")


def main() -> None:
    engine = Path(sys.argv[1])
    util_ios = Path(sys.argv[2])
    src = engine / "src"
    assert (src / "main.go").exists(), f"not an engine checkout: {engine}"

    patch(src / "font_gl33.go", "//go:build !android", "//go:build !android && !ios")
    patch(src / "render_gl33.go", "//go:build !android", "//go:build !android && !ios")
    patch(src / "font_gles32.go", "//go:build android", "//go:build android || ios")
    patch(src / "render_gles32.go", "//go:build android", "//go:build android || ios")
    patch(src / "font_vk.go", "//go:build !kinc && !android", "//go:build !kinc && !android && !ios")
    patch(src / "render_vk.go", "//go:build !kinc && !android", "//go:build !kinc && !android && !ios")
    patch(src / "util_desktop.go", "//go:build !raw && !android", "//go:build !raw && !android && !ios")
    # GOOS=ios also satisfies the `darwin` build tag: keep darwin-only
    # helpers (osPreferredLanguage via /usr/bin/defaults) off iOS.
    patch(src / "util_darwin.go", "//go:build darwin", "//go:build darwin && !ios")

    patch(src / "render_gles32.go",
          'if runtime.GOOS != "android" {',
          'if runtime.GOOS != "android" && runtime.GOOS != "ios" {')

    # iOS EAGL maxes out at GLES 3.0: a 3.2 context can never be created.
    patch(src / "main.go",
          '\t\tsdl.GLSetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, 3)\n\t\tsdl.GLSetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, 2)',
          '\t\tsdl.GLSetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, 3)\n\t\tif runtime.GOOS == "ios" {\n\t\t\tsdl.GLSetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, 0)\n\t\t} else {\n\t\t\tsdl.GLSetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, 2)\n\t\t}')

    # ...and 320 es shaders would never compile on it: inject 300 es on iOS.
    patch(src / "render_gles32.go",
          '\t\t// Anchor to 320 es for best feature compatibility\n\t\theader := "#version 320 es\\n"',
          '\t\t// Anchor to 320 es for best feature compatibility\n\t\theader := "#version 320 es\\n"\n\t\tif runtime.GOOS == "ios" {\n\t\t\theader = "#version 300 es\\n"\n\t\t}')

    # main.go init(): SDL main thread must be locked on iOS too.
    patch(src / "main.go",
          'if runtime.GOOS != "android" {\n\t\truntime.LockOSThread()\n\t}',
          'if runtime.GOOS != "android" && runtime.GOOS != "ios" {\n\t\truntime.LockOSThread()\n\t}')
    # main.go realMain(): iOS takes the mobile branch (baseDir/chdir/GLES/SDL).
    patch(src / "main.go",
          'if runtime.GOOS == "android" {\n\t\tLogcat("Inside realMain...")',
          'if runtime.GOOS == "android" || runtime.GOOS == "ios" {\n\t\tLogcat("Inside realMain...")')
    patch(src / "main.go",
          'if runtime.GOOS != "android" {\n\t\tpermission |= os.ModeSticky\n\t}',
          'if runtime.GOOS != "android" && runtime.GOOS != "ios" {\n\t\tpermission |= os.ModeSticky\n\t}')
    patch(src / "main.go",
          'if runtime.GOOS == "android" {\n\t\tsdl.InitSubSystem(sdl.INIT_JOYSTICK)',
          'if runtime.GOOS == "android" || runtime.GOOS == "ios" {\n\t\tsdl.InitSubSystem(sdl.INIT_JOYSTICK)')
    patch(src / "main.go",
          '// Force to OpenGL ES 3.2 for Android\n\tif runtime.GOOS == "android" {',
          '// Force to OpenGL ES 3.2 for Android\n\tif runtime.GOOS == "android" || runtime.GOOS == "ios" {')

    patch(src / "system.go",
          'if runtime.GOOS != "android" {\n\t\texePath, err := os.Executable()',
          'if runtime.GOOS != "android" && runtime.GOOS != "ios" {\n\t\texePath, err := os.Executable()')
    patch(src / "system.go",
          'if runtime.GOOS != "android" {\n\t\t// So now that we have a window we add an icon.',
          'if runtime.GOOS != "android" && runtime.GOOS != "ios" {\n\t\t// So now that we have a window we add an icon.')

    patch(src / "system_sdl.go",
          '\tif runtime.GOOS == "android" {\n\t\t// On Android, we MUST use 0,0',
          '\tif runtime.GOOS == "android" || runtime.GOOS == "ios" {\n\t\t// On Android, we MUST use 0,0')
    for old, new in [
        ('if runtime.GOOS != "android" {\n\t\t\tmode, err := sdl.GetDesktopDisplayMode(0)',
         'if runtime.GOOS != "android" && runtime.GOOS != "ios" {\n\t\t\tmode, err := sdl.GetDesktopDisplayMode(0)'),
        ('if runtime.GOOS != "android" {\n\t\t\tx, y = (desktopW-w2)/2, (desktopH-h2)/2',
         'if runtime.GOOS != "android" && runtime.GOOS != "ios" {\n\t\t\tx, y = (desktopW-w2)/2, (desktopH-h2)/2'),
        ('// 5. WINDOW CREATION\n\t\tif runtime.GOOS != "android" {',
         '// 5. WINDOW CREATION\n\t\tif runtime.GOOS != "android" && runtime.GOOS != "ios" {'),
        ('if runtime.GOOS == "android" {\n\t\t\tposX, posY = 0, 0',
         'if runtime.GOOS == "android" || runtime.GOOS == "ios" {\n\t\t\tposX, posY = 0, 0'),
        ('if runtime.GOOS != "android" && sys.cfg.Video.WindowCentered {',
         'if runtime.GOOS != "android" && runtime.GOOS != "ios" && sys.cfg.Video.WindowCentered {'),
    ]:
        patch(src / "system_sdl.go", old, new)

    # Panic message mentions Android only; keep accurate.
    patch(src / "main.go",
          'panic("FATAL: Android baseDir not set")',
          'panic("FATAL: mobile baseDir not set")')

    shutil.copy2(util_ios, src / "util_ios.go")
    print("  installed: util_ios.go")
    print("OK — iOS fork applied.")


if __name__ == "__main__":
    main()
