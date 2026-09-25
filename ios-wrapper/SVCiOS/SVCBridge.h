// SVCBridge.h — C interface between the ObjC shell and the Go engine
// (svc-engine-ios, src/util_ios.go). Linked together in the Xcode app.
#ifndef SVCBridge_h
#define SVCBridge_h

// Pass the app Documents directory. Called when the payload is ready
// (maybe minutes after launch — Files-app drop). Buffered channel in the
// engine: early or late calls are safe.
void SVCSetBaseDir(const char *path);

// Direct engine entry (manual bootstrap: raw UIApplicationMain + our own
// delegate; SDL_UIKitRunApp is not used). Call ONCE on the main thread;
// blocks inside the engine's game loop.
void SVCStart(const char *baseDirPath);

// Native screen size in points, landscape-first (w>=h regardless of the
// current orientation). Implemented in main.m (UIKit, main thread).
void SVCGetScreenPoints(float *w, float *h);

// Go-owned SDL entry point (exported from the engine static library).
// Kept for compatibility; the manual bootstrap does not call it.
int SDL_main(int argc, char *argv[]);

#endif
