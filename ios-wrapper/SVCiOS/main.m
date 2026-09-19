// SVC S1 — iOS entry point. Programmatic UIKit, no storyboards/XIBs.
// SDL2 iOS pattern per docs/README-ios.md: main() must live in the app and
// call SDL_UIKitRunApp with our SDL_main. (SDL_uikit_main.c equivalent.)
#import <UIKit/UIKit.h>
#include "SDL.h"

// Forward: engine + gamepad, wired in Phase 1/2.
extern int SVC_EngineMain(int argc, char *argv[]);
@class SVCGamepadView;

@interface SVCAppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation SVCAppDelegate
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  UIViewController *root = [[UIViewController alloc] init];
  root.view.backgroundColor = [UIColor blackColor];
  // NOTE: SDL creates its own window/view on top when the engine starts.
  // Gamepad overlay (Phase 2) attaches to root.view.window above SDL's view.
  self.window.rootViewController = root;
  [self.window makeKeyAndVisible];
  return YES;
}
@end

// SDL_main: called by SDL_UIKitRunApp on the app's main thread.
int SDL_main(int argc, char *argv[]) {
  // Phase 0: splash signal so a smoke-test IPA proves launch + SDL linkage.
  // Phase 1: replace body with `return SVC_EngineMain(argc, argv);`
  NSLog(@"[SVC-S1] bootstrap OK (Phase 0). Engine linkage pending.");
  return 0;
}

int main(int argc, char *argv[]) {
  @autoreleasepool {
    return SDL_UIKitRunApp(argc, argv, SDL_main);
  }
}
