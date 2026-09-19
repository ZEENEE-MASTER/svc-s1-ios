// SVCBridge.h — C interface between the ObjC shell and the Go engine
// (svc-engine-ios, src/util_ios.go). Linked together in the Xcode app.
#ifndef SVCBridge_h
#define SVCBridge_h

// Pass the app Documents directory. Call once at launch, before the SDL
// main thread enters SDL_main. Buffered channel: early call is safe.
void SVCSetBaseDir(const char *path);

// Go-owned SDL entry point (exported from the engine static library).
// Referenced by main.m's call to SDL_UIKitRunApp — do NOT define SDL_main
// in ObjC or the link will fail with a duplicate symbol.
int SDL_main(int argc, char *argv[]);

#endif
