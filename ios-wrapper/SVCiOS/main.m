// SVC S1 — iOS entry point. Programmatic UIKit, no storyboards/XIBs.
// SDL2 iOS pattern per docs/README-ios.md: main() lives in the app and
// calls SDL_UIKitRunApp. SDL_main itself is OWNED BY THE GO ENGINE
// (svc-engine-ios src/util_ios.go, //export SDL_main) — mirroring how
// ikemen-droid's libmain.so owns SDL_main on Android.
//
// First-launch flow (all inside didFinishLaunching, BEFORE SDL_main runs):
//   stderr -> Documents/svc-boot.log (pull via Finder File Sharing)
//   boot overlay with live status (no more silent black screen)
//   synchronous payload install (bundled payload-lite.zip -> Documents/)
//   SVCSetBaseDir -> engine proceeds
#define SDL_MAIN_HANDLED
#import <UIKit/UIKit.h>
#include <SDL2/SDL.h>
#import "SVCBridge.h"
#import "GamepadView.h"
#import "AssetDownloader.h"

@interface SVCAppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIWindow *padWindow;
@property (strong, nonatomic) UILabel *statusLabel;
@end

@implementation SVCAppDelegate

- (void)setStatus:(NSString *)msg {
  NSLog(@"[SVC-S1] %@", msg);
  if ([NSThread isMainThread]) {
    self.statusLabel.text = msg;
  } else {
    dispatch_sync(dispatch_get_main_queue(), ^{
      self.statusLabel.text = msg;
    });
  }
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                       NSUserDomainMask, YES);
  NSString *docs = [paths firstObject];

  // 1. Capture ALL stderr (ours + engine Logcat) to a pullable file.
  NSString *logPath =
      [docs stringByAppendingPathComponent:@"svc-boot.log"];
  freopen([logPath UTF8String], "a+", stderr);
  NSLog(@"[SVC-S1] launch: SVC S1 iOS boot");

  // 2. Boot overlay: visible status instead of a silent black screen.
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  UIViewController *root = [[UIViewController alloc] init];
  root.view.backgroundColor = [UIColor blackColor];
  self.statusLabel = [[UILabel alloc]
      initWithFrame:CGRectMake(20, 0, root.view.bounds.size.width - 40, 120)];
  self.statusLabel.center =
      CGPointMake(root.view.bounds.size.width / 2, root.view.bounds.size.height / 2);
  self.statusLabel.autoresizingMask =
      UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
      UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
  self.statusLabel.textColor = [UIColor whiteColor];
  self.statusLabel.numberOfLines = 0;
  self.statusLabel.textAlignment = NSTextAlignmentCenter;
  self.statusLabel.font = [UIFont systemFontOfSize:15];
  [root.view addSubview:self.statusLabel];
  UIActivityIndicatorView *spin = [[UIActivityIndicatorView alloc]
      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
  spin.center = CGPointMake(root.view.bounds.size.width / 2,
                            root.view.bounds.size.height / 2 + 90);
  spin.autoresizingMask = self.statusLabel.autoresizingMask;
  [spin startAnimating];
  [root.view addSubview:spin];
  self.window.rootViewController = root;
  [self.window makeKeyAndVisible];
  [self setStatus:@"SVC S1 starting…"];

  // 3. Payload install on a worker thread; main runloop stays alive so the
  //    overlay paints. didFinishLaunching returns only when done, so the
  //    engine (SDL_main) can never start with missing files.
  dispatch_semaphore_t done = dispatch_semaphore_create(0);
  __block BOOL installOK = NO;
  __block NSString *installNote = @"";
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    installOK = [AssetDownloader installPayloadWithProgress:^(NSUInteger cur,
                                                              NSUInteger total,
                                                              NSString *name) {
      [self setStatus:[NSString stringWithFormat:@"Installing fight data…\n%@\n%lu / %lu",
                                                 name, (unsigned long)cur,
                                                 (unsigned long)total]];
    }
        note:&installNote];
    dispatch_semaphore_signal(done);
  });
  while (dispatch_semaphore_wait(done, DISPATCH_TIME_NOW) != 0) {
    [[NSRunLoop mainRunLoop]
        runMode:NSDefaultRunLoopMode
     beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  }
  if (!installOK) {
    [self setStatus:[NSString stringWithFormat:@"Payload missing: %@\n"
                      @"Add payload-lite.zip via Finder File Sharing, then relaunch.",
                      installNote]];
    NSLog(@"[SVC-S1] FATAL: payload not ready: %@", installNote);
    return YES;  // Stay on the overlay with the reason visible.
  }
  [self setStatus:@"Entering the ring…"];

  // 4. Hand the engine its sandbox home; SDL_main (Go) proceeds.
  SVCSetBaseDir([docs UTF8String]);

  // 5. Touch overlay in its own high window: above SDL's window for
  //    hit-testing, but never key (SDL keeps keyboard/focus duties).
  self.padWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.padWindow.windowLevel = UIWindowLevelStatusBar + 1.0;
  SVCGamepadView *pad = [[SVCGamepadView alloc]
      initWithFrame:self.padWindow.bounds];
  pad.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self.padWindow addSubview:pad];
  self.padWindow.hidden = NO;
  return YES;
}
@end

int main(int argc, char *argv[]) {
  @autoreleasepool {
    return SDL_UIKitRunApp(argc, argv, SDL_main);
  }
}
