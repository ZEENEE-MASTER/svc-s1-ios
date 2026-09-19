// SVC S1 — iOS entry point. Programmatic UIKit, no storyboards/XIBs.
// SDL2 iOS pattern per docs/README-ios.md: main() lives in the app and
// calls SDL_UIKitRunApp. SDL_main itself is OWNED BY THE GO ENGINE
// (svc-engine-ios src/util_ios.go, //export SDL_main).
//
// All wrapper UI lives in padWindow (above SDL's window): boot status,
// live engine-log tail, and the touch gamepad. SDL's window is opaque, so
// anything in self.window would be invisible once the engine starts.
//
// First-launch flow:
//   stderr -> Documents/svc-boot.log (also mirrored on screen, live)
//   payload install (bundled / side-loaded / Files-app drop, polled)
//   SVCSetBaseDir -> engine (SDL_main) proceeds whenever ready
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
@property (strong, nonatomic) UITextView *logView;
@property (strong, nonatomic) NSString *docs;
@property (strong, nonatomic) NSString *logPath;
@property (nonatomic) BOOL engineSignaled;
@end

@implementation SVCAppDelegate
- (void)setStatus:(NSString *)msg {
  NSLog(@"[SVC-S1] %@", msg);
  dispatch_async(dispatch_get_main_queue(), ^{
    self.statusLabel.text = msg;
  });
}

// Mirror the last lines of the boot log onto the overlay.
- (void)refreshLogView {
  NSData *d = [NSData dataWithContentsOfFile:self.logPath];
  if (!d.length)
    return;
  NSString *all = [[NSString alloc] initWithData:d
                                        encoding:NSUTF8StringEncoding];
  if (!all.length)
    return;
  NSArray *lines = [all componentsSeparatedByString:@"\n"];
  NSUInteger n = lines.count;
  NSUInteger from = n > 14 ? n - 14 : 0;
  NSString *tail = [[lines subarrayWithRange:NSMakeRange(from, n - from)]
      componentsJoinedByString:@"\n"];
  dispatch_async(dispatch_get_main_queue(), ^{
    self.logView.text = tail;
  });
}

- (void)buildTopWindow {
  self.padWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.padWindow.windowLevel = UIWindowLevelStatusBar + 1.0;
  self.padWindow.rootViewController = [[UIViewController alloc] init];
  self.padWindow.rootViewController.view.backgroundColor = [UIColor clearColor];
  // NOTE: keep interaction enabled: empty areas pass touches through to SDL.

  CGRect b = self.padWindow.bounds;
  self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 44, b.size.width - 40, 90)];
  self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  self.statusLabel.textColor = [UIColor whiteColor];
  self.statusLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
  self.statusLabel.numberOfLines = 0;
  self.statusLabel.textAlignment = NSTextAlignmentCenter;
  self.statusLabel.font = [UIFont boldSystemFontOfSize:16];
  [self.padWindow.rootViewController.view addSubview:self.statusLabel];

  self.logView = [[UITextView alloc]
      initWithFrame:CGRectMake(20, 140, b.size.width - 40, 190)];
  self.logView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  self.logView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
  self.logView.textColor = [UIColor greenColor];
  self.logView.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
  self.logView.editable = NO;
  self.logView.selectable = NO;
  self.logView.userInteractionEnabled = NO;
  [self.padWindow.rootViewController.view addSubview:self.logView];

  [self.padWindow makeKeyAndVisible];
  // SDL needs key status for keyboard/focus: hand it back, stay visible.
  [self.window makeKeyAndVisible];
}

- (void)addGamepad {
  SVCGamepadView *pad = [[SVCGamepadView alloc]
      initWithFrame:self.padWindow.bounds];
  pad.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self.padWindow.rootViewController.view addSubview:pad];
}

// One install attempt. Signals the engine exactly once, when bootable.
- (void)tryInstall {
  __block BOOL ok = NO;
  __block NSString *note = @"";
  ok = [AssetDownloader installPayloadWithProgress:^(NSUInteger cur, NSUInteger total, NSString *name) {
    [self setStatus:[NSString stringWithFormat:@"Installing fight data…\n%@\n%lu / %lu",
                                               name, (unsigned long)cur, (unsigned long)total]];
  }
      note:&note];
  [self refreshLogView];
  if (ok && !self.engineSignaled) {
    self.engineSignaled = YES;
    SVCSetBaseDir([self.docs UTF8String]);
    [self setStatus:@"Entering the ring…"];
    [self addGamepad];
  } else if (!ok) {
    [self setStatus:[NSString stringWithFormat:@"Waiting for fight data…\n%@\n"
                     @"Drop payload-lite.zip in Files → SVC S1, no relaunch needed.",
                     note]];
  }
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                       NSUserDomainMask, YES);
  self.docs = [paths firstObject];
  self.logPath = [self.docs stringByAppendingPathComponent:@"svc-boot.log"];

  // Truncate stale logs; a previous run's tail is shown below instead.
  NSString *prevTail = @"";
  NSData *prev = [NSData dataWithContentsOfFile:self.logPath];
  if (prev.length > 64) {
    NSString *all = [[NSString alloc] initWithData:prev encoding:NSUTF8StringEncoding];
    NSArray *lines = [all componentsSeparatedByString:@"\n"];
    NSUInteger n = lines.count, from = n > 12 ? n - 12 : 0;
    prevTail = [lines subarrayWithRange:NSMakeRange(from, n - from)] componentsJoinedByString:@"\n"];
  }
  freopen([self.logPath UTF8String], "w", stderr);
  NSLog(@"[SVC-S1] launch: SVC S1 iOS boot");
  if (prevTail.length)
    NSLog(@"[SVC-S1] previous run tail:\n%@", prevTail);

  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.window.rootViewController = [[UIViewController alloc] init];
  self.window.rootViewController.view.backgroundColor = [UIColor blackColor];
  [self.window makeKeyAndVisible];
  [self buildTopWindow];
  [self setStatus:@"SVC S1 starting…"];
  [self refreshLogView];

  // Live tail refresh + Files-drop polling (payload can arrive any time).
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    [self tryInstall];
    for (;;) {
      [NSThread sleepForTimeInterval:2.0];
      [self refreshLogView];
      if (!self.engineSignaled)
        [self tryInstall];
    }
  });
  return YES;
}
@end

int main(int argc, char *argv[]) {
  @autoreleasepool {
    return SDL_UIKitRunApp(argc, argv, SDL_main);
  }
}
