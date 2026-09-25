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
    # NOTE: `new in text` alone means applied (append-style patches keep
    # `old` as a substring of `new`; requiring old-absence re-applies).
    text = path.read_text(encoding="utf-8", newline="")
    if new in text:
        print(f"  already applied: {path.name}")
        return
    count = text.count(old)
    assert count == 1, f"{path}: expected 1 match, found {count} for: {old[:70]!r}"
    path.write_text(text.replace(old, new), encoding="utf-8", newline="")
    print(f"  patched: {path.name}")


def patch_any(path: Path, variants: list) -> None:
    """Apply the first variant whose old-string matches exactly once.
    Variants are tried longest-old-first so a short old-string can never
    match inside an already-patched longer line."""
    text = path.read_text(encoding="utf-8", newline="")
    if any(new in text for _, new in variants):
        print(f"  already applied: {path.name}")
        return
    for old, new in sorted(variants, key=lambda v: len(v[0]), reverse=True):
        if text.count(old) == 1:
            path.write_text(text.replace(old, new), encoding="utf-8", newline="")
            print(f"  patched: {path.name}")
            return
    raise AssertionError(f"{path}: no variant matched")


def main() -> None:
    engine = Path(sys.argv[1])
    util_ios = Path(sys.argv[2])
    src = engine / "src"
    assert (src / "main.go").exists(), f"not an engine checkout: {engine}"

    patch(src / "font_gl33.go", "//go:build !android", "//go:build !android && !ios")
    patch(src / "render_gl33.go", "//go:build !android", "//go:build !android && !ios")
    patch(src / "font_gles32.go", "//go:build android", "//go:build android || ios")
    patch(src / "render_gles32.go", "//go:build android", "//go:build android || ios")
    patch_any(src / "font_vk.go", [
        ("//go:build !kinc && !android", "//go:build !kinc && (!android || ios)"),
        ("//go:build !kinc && !android && !ios", "//go:build !kinc && (!android || ios)"),
    ])
    patch_any(src / "render_vk.go", [
        ("//go:build !kinc && !android", "//go:build !kinc && (!android || ios)"),
        ("//go:build !kinc && !android && !ios", "//go:build !kinc && (!android || ios)"),
    ])
    patch(src / "util_desktop.go", "//go:build !raw && !android", "//go:build !raw && !android && !ios")
    # GOOS=ios also satisfies the `darwin` build tag: keep darwin-only
    # helpers (osPreferredLanguage via /usr/bin/defaults) off iOS.
    patch(src / "util_darwin.go", "//go:build darwin", "//go:build darwin && !ios")

    patch(src / "render_gles32.go",
          'if runtime.GOOS != "android" {',
          'if runtime.GOOS != "android" && runtime.GOOS != "ios" {')

    # MoltenVK on iOS: explicit loader init (static link resolves via
    # dlsym(RTLD_DEFAULT)) + portability enumeration for device discovery.
    patch(src / "render_vk.go",
          'func (r *Renderer_VK) NewVulkanDevice(appInfo *vk.ApplicationInfo, window uintptr) error {\n\t// create a Vulkan instance.',
          'func (r *Renderer_VK) NewVulkanDevice(appInfo *vk.ApplicationInfo, window uintptr) error {\n\tif runtime.GOOS == "ios" {\n\t\tif err := sdl.VulkanLoadLibrary(""); err != nil {\n\t\t\treturn fmt.Errorf("VulkanLoadLibrary failed: %w", err)\n\t\t}\n\t}\n\t// create a Vulkan instance.')
    # MoltenVK 1.4+: VK_KHR_portability_enumeration is GONE (devices enumerate
    # without it). An earlier revision of this script added it — remove that
    # block wherever present; fresh trees simply skip.
    try:
        patch(src / "render_vk.go",
              '\tif runtime.GOOS == "ios" {\n\t\tinstanceExtensions = append(instanceExtensions, vk.KhrPortabilityEnumerationExtensionName+"\\x00")\n\t\tinstanceCreateInfo.PpEnabledExtensionNames = instanceExtensions\n\t\tinstanceCreateInfo.EnabledExtensionCount = uint32(len(instanceExtensions))\n\t\tinstanceCreateInfo.Flags = vk.InstanceCreateFlags(vk.InstanceCreateEnumeratePortabilityBit)\n\t}\n',
              '')
    except AssertionError:
        print("  portability block absent, skipping")
    # No discrete GPU on iOS (integrated Apple GPU): take limits from device 0
    # instead of leaving zeros (e.g. maxAnisotropy).
    patch(src / "render_vk.go",
          '\t\t\tr.gpuIndex = uint32(i)\n\t\t\tbreak\n\t\t}\n\t}\n\tqueueCreateInfos := []vk.DeviceQueueCreateInfo{{',
          '\t\t\tr.gpuIndex = uint32(i)\n\t\t\tbreak\n\t\t}\n\t}\n\tif len(r.gpuDevices) > 0 && r.maxAnisotropy == 0 {\n\t\tvar gp vk.PhysicalDeviceProperties\n\t\tvk.GetPhysicalDeviceProperties(r.gpuDevices[r.gpuIndex], &gp)\n\t\tgp.Deref()\n\t\tr.maxAnisotropy = gp.Limits.MaxSamplerAnisotropy\n\t\tr.minUniformBufferOffsetAlignment = uint32(gp.Limits.MinUniformBufferOffsetAlignment)\n\t\tr.maxImageArrayLayers = uint32(gp.Limits.MaxImageArrayLayers)\n\t}\n\tqueueCreateInfos := []vk.DeviceQueueCreateInfo{{')

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
    # iOS renders through MoltenVK (EAGL is ES 2.0-only on modern iOS);
    # Android keeps the GLES path.
    patch(src / "main.go",
          '// Force to OpenGL ES 3.2 for Android\n\tif runtime.GOOS == "android" || runtime.GOOS == "ios" {',
          '// Force to OpenGL ES 3.2 for Android\n\tif runtime.GOOS == "android" {')
    patch(src / "main.go",
          '\tcfg.Video.RenderMode = "OpenGL ES 3.2"\n\t}',
          '\tcfg.Video.RenderMode = "OpenGL ES 3.2"\n\t}\n\tif runtime.GOOS == "ios" {\n\t\tcfg.Video.RenderMode = "Vulkan 1.3"\n\t}')

    patch(src / "system.go",
          'if runtime.GOOS != "android" {\n\t\texePath, err := os.Executable()',
          'if runtime.GOOS != "android" && runtime.GOOS != "ios" {\n\t\texePath, err := os.Executable()')
    patch(src / "system.go",
          'if runtime.GOOS != "android" {\n\t\t// So now that we have a window we add an icon.',
          'if runtime.GOOS != "android" && runtime.GOOS != "ios" {\n\t\t// So now that we have a window we add an icon.')

    # system_sdl: iOS+Vulkan takes the generic (Vulkan-aware) window path,
    # not Android's forced-GLES one. Config is forced to Vulkan on iOS.
    patch(src / "system_sdl.go",
          '\tif runtime.GOOS == "android" || runtime.GOOS == "ios" {\n\t\t// On Android, we MUST use 0,0',
          '\tif runtime.GOOS == "android" || (runtime.GOOS == "ios" && s.cfg.Video.RenderMode != "Vulkan 1.3") {\n\t\t// On Android, we MUST use 0,0')
    # iOS is landscape-only (Backbone, fullscreen fighter): pin SDL's view
    # controller orientations or the app sits in portrait.
    patch(src / "main.go",
          '\t\tsdl.GLSetAttribute(sdl.GL_DEPTH_SIZE, 24)',
          '\t\tsdl.GLSetAttribute(sdl.GL_DEPTH_SIZE, 24)\n\t\tif runtime.GOOS == "ios" {\n\t\t\tsdl.SetHint(sdl.HINT_ORIENTATIONS, "LandscapeLeft LandscapeRight")\n\t\t}')
    # iOS is fullscreen-only (no windowed desktop): force it.
    patch(src / "system_sdl.go",
          '\t\t_, forceWindowed := sys.cmdFlags["-windowed"]\n\t\tfullscreen := s.cfg.Video.Fullscreen && !forceWindowed',
          '\t\t_, forceWindowed := sys.cmdFlags["-windowed"]\n\t\tfullscreen := s.cfg.Video.Fullscreen && !forceWindowed\n\t\tif runtime.GOOS == "ios" {\n\t\t\tfullscreen = true\n\t\t}')
    # ...at the NATIVE size: SDL reports bogus 320x480 pre-window and a
    # 1280x720 default stays a small centered rectangle. Landscape-first
    # points come from UIKit (SVCGetScreenPoints in the ObjC shell).
    patch(src / "system_sdl.go",
          '\t\tif sys.cfg.Video.WindowWidth > 0 || sys.cfg.Video.WindowHeight > 0 {\n\t\t\tw2, h2 = int32(sys.cfg.Video.WindowWidth), int32(sys.cfg.Video.WindowHeight)\n\t\t}',
          '\t\tif sys.cfg.Video.WindowWidth > 0 || sys.cfg.Video.WindowHeight > 0 {\n\t\t\tw2, h2 = int32(sys.cfg.Video.WindowWidth), int32(sys.cfg.Video.WindowHeight)\n\t\t}\n\t\tif runtime.GOOS == "ios" && fullscreen {\n\t\t\tif sw, sh := svcScreenPoints(); sw > 0 && sh > 0 {\n\t\t\t\tw2, h2 = sw, sh\n\t\t\t}\n\t\t}')
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
