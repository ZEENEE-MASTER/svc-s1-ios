// SVC S1 — iOS entry point. Programmatic UIKit, no storyboards/XIBs.
//
// Bootstrap is MANUAL: raw UIApplicationMain with our own delegate
// (SDL_UIKitRunApp proved fatal on this device generation — black hang,
// SDL_main never reached). The engine starts via Go SVCStart(), called on
// the main thread once the payload is ready; it pumps SDL events every
// frame, keeping the runloop/watchdog satisfied.
//
// All wrapper UI lives in padWindow (above SDL's opaque window): boot
// status, live engine-log tail, and the touch gamepad.
#define SDL_MAIN_HANDLED
#import <UIKit/UIKit.h>
#include <SDL2/SDL.h>
#import "SVCBridge.h"
#import "GamepadView.h"
#import "AssetDownloader.h"

@interface SVCAppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation SVCAppDelegate {
  UIWindow *_padWindow;
  UILabel *_statusLabel;
  UITextView *_logView;
  NSString *_docs;
  NSString *_logPath;
  BOOL _engineStarted;
}

- (void)setStatus:(NSString *)msg {
  NSLog(@"[SVC-S1] %@", msg);
  dispatch_async(dispatch_get_main_queue(), ^{
    self->_statusLabel.text = msg;
  });
}

// Mirror the last lines of the boot log onto the overlay.
- (void)refreshLogView {
  NSData *d = [NSData dataWithContentsOfFile:self->_logPath];
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
    self->_logView.text = tail;
  });
}

// Payload ready -> start the engine ONCE, on the main thread.
- (void)startEngine {
  if (self->_engineStarted)
    return;
  self->_engineStarted = YES;
  [self setStatus:@"Entering the ring…"];
  SVCGamepadView *pad = [[SVCGamepadView alloc]
      initWithFrame:self->_padWindow.bounds];
  pad.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self->_padWindow.rootViewController.view addSubview:pad];
  // Blocks inside the engine's game loop (pumps SDL events per frame).
  SVCStart([self->_docs UTF8String]);
}

// One install attempt; engine starts the moment bootable.
- (void)tryInstall {
  __block BOOL ok = NO;
  __block NSString *note = @"";
  ok = [AssetDownloader installPayloadWithProgress:^(NSUInteger cur, NSUInteger total, NSString *name) {
    [self setStatus:[NSString stringWithFormat:@"Installing fight data…\n%@\n%lu / %lu",
                                               name, (unsigned long)cur,
                                               (unsigned long)total]];
  }
      note:&note];
  [self refreshLogView];
  if (ok) {
    // Engine must start on the main thread (UIKit confinement).
    if ([NSThread isMainThread]) {
      [self startEngine];
    } else {
      dispatch_sync(dispatch_get_main_queue(), ^{
        [self startEngine];
      });
    }
  } else {
    [self setStatus:[NSString stringWithFormat:@"Waiting for fight data…\n%@\n"
                     @"Drop payload-lite.zip in Files → SVC S1, no relaunch needed.",
                     note]];
  }
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  (void)application;
  (void)launchOptions;
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                       NSUserDomainMask, YES);
  _docs = [paths firstObject];
  _logPath = [_docs stringByAppendingPathComponent:@"svc-boot.log"];

  NSString *prevTail = @"";
  NSData *prev = [NSData dataWithContentsOfFile:_logPath];
  if (prev.length > 64) {
    NSString *all = [[NSString alloc] initWithData:prev encoding:NSUTF8StringEncoding];
    NSArray *lines = [all componentsSeparatedByString:@"\n"];
    NSUInteger n = lines.count, from = n > 12 ? n - 12 : 0;
    prevTail = [[lines subarrayWithRange:NSMakeRange(from, n - from)] componentsJoinedByString:@"\n"];
  }
  freopen([_logPath UTF8String], "w", stderr);
  NSLog(@"[SVC-S1] launch: manual bootstrap");
  if (prevTail.length)
    NSLog(@"[SVC-S1] previous run tail:\n%@", prevTail);

  _padWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  _padWindow.windowLevel = UIWindowLevelStatusBar + 1.0;
  _padWindow.rootViewController = [[UIViewController alloc] init];
  _padWindow.rootViewController.view.backgroundColor = [UIColor clearColor];

  CGRect b = _padWindow.bounds;
  _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 44, b.size.width - 40, 90)];
  _statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  _statusLabel.textColor = [UIColor whiteColor];
  _statusLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
  _statusLabel.numberOfLines = 0;
  _statusLabel.textAlignment = NSTextAlignmentCenter;
  _statusLabel.font = [UIFont boldSystemFontOfSize:16];
  _statusLabel.text = @"SVC S1 starting…";
  [_padWindow.rootViewController.view addSubview:_statusLabel];

  _logView = [[UITextView alloc] initWithFrame:CGRectMake(20, 140, b.size.width - 40, 190)];
  _logView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  _logView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
  _logView.textColor = [UIColor greenColor];
  _logView.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
  _logView.editable = NO;
  _logView.selectable = NO;
  _logView.userInteractionEnabled = NO;
  [_padWindow.rootViewController.view addSubview:_logView];

  _padWindow.hidden = NO;
  [self refreshLogView];

  // Install + Files-drop polling (payload can arrive any time).
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    [self tryInstall];
    for (;;) {
      [NSThread sleepForTimeInterval:2.0];
      [self refreshLogView];
      if (!self->_engineStarted)
        [self tryInstall];
    }
  });
  return YES;
}
@end

int main(int argc, char *argv[]) {
  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([SVCAppDelegate class]));
  }
}
