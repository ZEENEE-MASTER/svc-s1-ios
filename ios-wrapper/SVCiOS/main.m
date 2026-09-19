// SVC S1 — iOS entry point. Programmatic UIKit, no storyboards/XIBs.
// SDL2 iOS pattern per docs/README-ios.md: main() lives in the app and
// calls SDL_UIKitRunApp. SDL_main itself is OWNED BY THE GO ENGINE
// (svc-engine-ios src/util_ios.go, //export SDL_main) — mirroring how
// ikemen-droid's libmain.so owns SDL_main on Android.
#import <UIKit/UIKit.h>
#include <SDL2/SDL.h>
#import "SVCBridge.h"
#import "GamepadView.h"
#import "AssetDownloader.h"

@interface SVCAppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation SVCAppDelegate
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  // 1. Hand the engine its sandbox home (Documents/) before SDL starts.
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                       NSUserDomainMask, YES);
  NSString *docs = [paths firstObject];
  SVCSetBaseDir([docs UTF8String]);

  // 2. Ensure the Lite payload is present (bundled or downloaded).
  //    Blocks the menu, not the engine: SDL_main waits on the same bridge.
  [AssetDownloader ensurePayloadWithCompletion:^(BOOL ready, NSString *note) {
    NSLog(@"[SVC-S1] payload: %@ (%@)", ready ? @"ready" : @"MISSING", note);
  }];

  // 3. Programmatic root; SDL creates its view, gamepad overlays it.
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  UIViewController *root = [[UIViewController alloc] init];
  root.view.backgroundColor = [UIColor blackColor];
  self.window.rootViewController = root;
  [self.window makeKeyAndVisible];

  SVCGamepadView *pad = [[SVCGamepadView alloc]
      initWithFrame:self.window.bounds];
  pad.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self.window addSubview:pad];
  return YES;
}
@end

int main(int argc, char *argv[]) {
  @autoreleasepool {
    return SDL_UIKitRunApp(argc, argv, SDL_main);
  }
}
