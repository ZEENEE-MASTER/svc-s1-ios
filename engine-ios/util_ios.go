//go:build ios

// iOS platform layer for the SVC S1 port. Mirrors util_android.go:
//   - Go OWNS SDL_main (SDL_MAIN_HANDLED; SDL_uikit_main calls into us).
//   - ObjC passes the app Documents dir via SVCSetBaseDir, then we chdir
//     and run realMain on the SDL main thread.
//   - GLES2 renderer (same path as Android); proc addresses via SDL.
//   - Logging goes to stderr (visible in Console/idevicesyslog).
//   - GODEBUG constructor: same mobile-stability rationale as Android.
package main

/*
#cgo CFLAGS: -DSDL_MAIN_HANDLED
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include "SDL.h"

// Runs at library load, BEFORE the Go runtime starts.
__attribute__((constructor))
static void svc_prepare_go_runtime() {
	setenv("GODEBUG", "asyncpreemptoff=1,sigaltstack=0,cgocheck=0,scavenge=off,installgoroot=0,hardstacklimit=0", 1);
}

static void svc_log(const char *s) {
	fprintf(stderr, "[svc-s1] %s\n", s);
	fflush(stderr);
}
*/
import "C"
import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"unsafe"

	findfont "github.com/flopp/go-findfont"
	"github.com/veandco/go-sdl2/sdl"
)

var (
	extractionDone = make(chan bool, 1)
	baseDir        string
)

func init() {
}

func NewLogWriter() io.Writer {
	return os.Stderr
}

func LoadFntTtf(f *Fnt, fontfile string, filename string, height int32) {
	fileDir := SearchFile(filename, []string{fontfile, sys.motif.Def, "", "data/"}, "font/")
	// Anchor to the app container when the relative lookup misses.
	if !filepath.IsAbs(fileDir) && FileExist(fileDir) == "" && baseDir != "" {
		fullPath := filepath.Join(baseDir, fileDir)
		if FileExist(fullPath) != "" {
			fileDir = fullPath
		}
	}
	if FileExist(fileDir) == "" {
		if found, err := findfont.Find(fileDir); err == nil {
			fileDir = found
		} else {
			Logcat(fmt.Sprintf("Font search failed for %s, trying direct path...", filename))
		}
	}
	if height == -1 {
		height = int32(f.Size[1])
	} else {
		f.Size[1] = uint16(height)
	}
	ttf, err := gfxFont.LoadFont(fileDir, height, int(sys.gameWidth), int(sys.gameHeight))
	if err != nil {
		Logcat(fmt.Sprintf("ERROR: Failed to load TTF from %s", fileDir))
		panic(fmt.Errorf("failed to load ttf font %v: %w", fileDir, err))
	}
	f.ttf = ttf.(Font)
	f.palettes = make([][256]uint32, 1)
	for i := 0; i < 256; i++ {
		f.palettes[0][i] = 0
	}
}

func ShowInfoDialog(message, title string) {
	Logcat(fmt.Sprintf("INFO [%s]: %s", title, message))
}

func ShowErrorDialog(message string) {
	Logcat(fmt.Sprintf("CRITICAL ERROR: %s", message))
}

// Direct engine entry for the manual bootstrap (raw UIApplicationMain +
// our own delegate; SDL_UIKitRunApp is not used). Call ONCE on the main
// thread; blocks inside the engine's game loop (which pumps SDL events
// every frame, keeping the runloop/watchdog satisfied).
//
//export SVCStart
func SVCStart(cBaseDir *C.char) {
	runtime.LockOSThread()
	if cBaseDir != nil {
		baseDir = C.GoString(cBaseDir)
	}
	select {
	case extractionDone <- true:
	default:
	}
	Logcat("SVCStart: baseDir=" + baseDir)
	sys.baseDir = baseDir
	// MFi input arrives through our own GameController->keyboard bridge
	// (SVCGamepadBridge), so the engine's native joystick layer stays off:
	// single deterministic input path, no double-mapped buttons.
	os.Args = []string{"svc-s1", "-nojoy"}
	realMain()
}

//export SDL_main
func SDL_main(argc C.int, argv **C.char) C.int {
	runtime.LockOSThread()
	// Manual bootstrap does not use this path; kept for compatibility.
	// Wait for ObjC to hand us a bootable Documents path.
	<-extractionDone
	Logcat("SDL_main: baseDir ready, entering realMain")
	sys.baseDir = baseDir
	realMain()
	return 0
}

//export SVCSetBaseDir
func SVCSetBaseDir(cPath *C.char) {
	if cPath != nil {
		baseDir = C.GoString(cPath)
	}
	select {
	case extractionDone <- true:
		Logcat("ObjC: baseDir received: " + baseDir)
	default:
		Logcat("ObjC: baseDir already set")
	}
}

func eglGetProcAddress(name string) unsafe.Pointer {
	return sdl.GLGetProcAddress(name)
}

func selectRenderer(cfgVal string) (Renderer, FontRenderer) {
	// iOS renders through MoltenVK; GLES32 stays as fallback.
	if cfgVal == "Vulkan 1.3" {
		return &Renderer_VK{}, &FontRenderer_VK{}
	}
	return &Renderer_GLES32{}, &FontRenderer_GLES32{}
}

func Logcat(s string) {
	cs := C.CString(s)
	C.svc_log(cs)
	C.free(unsafe.Pointer(cs))
}

// osPreferredLanguage: iOS has no `defaults` CLI; SelectedLanguage() treats
// "" as unset and falls back to "en" (S1 pins Language = en in config.ini).
func osPreferredLanguage() string {
	return ""
}
