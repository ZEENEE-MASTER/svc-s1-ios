// SVCBridge.h — C interface between the ObjC shell and the Go engine
// (svc-engine-ios, src/util_ios.go). Linked together in the Xcode app.
#ifndef SVCBridge_h
#define SVCBridge_h

// Pass the app Documents directory. Called when the payload is ready
// (maybe minutes after launch — Files-app drop). Buffered channel in the
// engine: early or late calls are safe.
void SVCSetBaseDir(const char *path);

// Boot sequence (ObjC, main.m): overlay UI, stderr capture, payload
// install, readiness polling. Called by Go SDL_main (SDL's own app
// delegate means no custom AppDelegate of ours would ever fire).
void SVCBootSequence(void);

// Go-owned SDL entry point (exported from the engine static library).
// Referenced by main.m's call to SDL_UIKitRunApp — do NOT define SDL_main
// in ObjC or the link will fail with a duplicate symbol.
int SDL_main(int argc, char *argv[]);

#endif
