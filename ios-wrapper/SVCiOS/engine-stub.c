// engine-stub.c — WEAK stand-ins for the Go engine (smoke-test shell only).
// The real definitions live in svc-engine-ios (src/util_ios.go):
//   void SVCStart(const char *), int SDL_main(int, char **),
//   void SVCSetBaseDir(const char *).
// Weak attributes let the engine's strong symbols supersede these at
// link time with zero source changes. DO NOT call these knowingly:
// if you hit the stub on device, the engine archive failed to link.
#include <stdio.h>

__attribute__((weak)) void SVCSetBaseDir(const char *path) {
  fprintf(stderr, "[svc-s1] STUB SVCSetBaseDir(%s) — engine not linked\n",
          path ? path : "(null)");
}

__attribute__((weak)) int SDL_main(int argc, char *argv[]) {
  (void)argc;
  (void)argv;
  fprintf(stderr, "[svc-s1] STUB SDL_main — engine not linked\n");
  return 0;
}

__attribute__((weak)) void SVCStart(const char *path) {
  fprintf(stderr, "[svc-s1] STUB SVCStart(%s) — engine not linked\n",
          path ? path : "(null)");
}
