// SVC S1 — iOS entry point. Programmatic UIKit, no storyboards/XIBs.
//
// CRITICAL: SDL_UIKitRunApp installs SDL's OWN UIApplicationDelegate.
// A custom AppDelegate in this file would NEVER fire, so ALL boot logic
// lives in SVCBootSequence(), called by the Go engine as the first act of
// SDL_main (svc-engine-ios src/util_ios.go). Do not move boot work into an
// AppDelegate: the engine would wait on its start channel forever (black).
//
// All wrapper UI lives in padWindow (above SDL's opaque window): boot
// status, live engine-log tail, and the touch gamepad.
#define SDL_MAIN_HANDLED
#import <UIKit/UIKit.h>
#include <SDL2/SDL.h>
#import "SVCBridge.h"
#import "GamepadView.h"
#import "AssetDownloader.h"

static UIWindow *gPadWindow;
static UILabel *gStatusLabel;
static UITextView *gLogView;
static NSString *gDocs;
static NSString *gLogPath;
static BOOL gEngineSignaled;

static void SVCSetStatus(NSString *msg) {
  NSLog(@"[SVC-S1] %@", msg);
  dispatch_async(dispatch_get_main_queue(), ^{
    gStatusLabel.text = msg;
  });
}

// Mirror the last lines of the boot log onto the overlay.
static void SVCRefreshLog(void) {
  NSData *d = [NSData dataWithContentsOfFile:gLogPath];
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
    gLogView.text = tail;
  });
}

// One install attempt. Signals the engine exactly once, when bootable.
static void SVCTryInstall(void) {
  __block BOOL ok = NO;
  __block NSString *note = @"";
  ok = [AssetDownloader installPayloadWithProgress:^(NSUInteger cur, NSUInteger total, NSString *name) {
    SVCSetStatus([NSString stringWithFormat:@"Installing fight data…\n%@\n%lu / %lu",
                                            name, (unsigned long)cur,
                                            (unsigned long)total]);
  }
      note:&note];
  SVCRefreshLog();
  if (ok && !gEngineSignaled) {
    gEngineSignaled = YES;
    SVCSetBaseDir([gDocs UTF8String]);
    SVCSetStatus(@"Entering the ring…");
    SVCGamepadView *pad = [[SVCGamepadView alloc]
        initWithFrame:gPadWindow.bounds];
    pad.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    dispatch_async(dispatch_get_main_queue(), ^{
      [gPadWindow.rootViewController.view addSubview:pad];
    });
  } else if (!ok) {
    SVCSetStatus([NSString stringWithFormat:@"Waiting for fight data…\n%@\n"
                  @"Drop payload-lite.zip in Files → SVC S1, no relaunch needed.",
                  note]);
  }
}

// Called by Go SDL_main on the main thread. Returns immediately; the engine
// waits on its start channel until SVCTryInstall signals readiness.
void SVCBootSequence(void) {
  static BOOL booted = NO;
  if (booted)
    return;
  booted = YES;

  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                       NSUserDomainMask, YES);
  gDocs = [paths firstObject];
  gLogPath = [gDocs stringByAppendingPathComponent:@"svc-boot.log"];

  NSString *prevTail = @"";
  NSData *prev = [NSData dataWithContentsOfFile:gLogPath];
  if (prev.length > 64) {
    NSString *all = [[NSString alloc] initWithData:prev encoding:NSUTF8StringEncoding];
    NSArray *lines = [all componentsSeparatedByString:@"\n"];
    NSUInteger n = lines.count, from = n > 12 ? n - 12 : 0;
    prevTail = [[lines subarrayWithRange:NSMakeRange(from, n - from)] componentsJoinedByString:@"\n"];
  }
  freopen([gLogPath UTF8String], "w", stderr);
  NSLog(@"[SVC-S1] launch: SVC S1 iOS boot (via SDL_main)");
  if (prevTail.length)
    NSLog(@"[SVC-S1] previous run tail:\n%@", prevTail);

  gPadWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  gPadWindow.windowLevel = UIWindowLevelStatusBar + 1.0;
  gPadWindow.rootViewController = [[UIViewController alloc] init];
  gPadWindow.rootViewController.view.backgroundColor = [UIColor clearColor];

  CGRect b = gPadWindow.bounds;
  gStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 44, b.size.width - 40, 90)];
  gStatusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  gStatusLabel.textColor = [UIColor whiteColor];
  gStatusLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
  gStatusLabel.numberOfLines = 0;
  gStatusLabel.textAlignment = NSTextAlignmentCenter;
  gStatusLabel.font = [UIFont boldSystemFontOfSize:16];
  gStatusLabel.text = @"SVC S1 starting…";
  [gPadWindow.rootViewController.view addSubview:gStatusLabel];

  gLogView = [[UITextView alloc] initWithFrame:CGRectMake(20, 140, b.size.width - 40, 190)];
  gLogView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  gLogView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
  gLogView.textColor = [UIColor greenColor];
  gLogView.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
  gLogView.editable = NO;
  gLogView.selectable = NO;
  gLogView.userInteractionEnabled = NO;
  [gPadWindow.rootViewController.view addSubview:gLogView];

  gPadWindow.hidden = NO;
  SVCRefreshLog();

  // Install + Files-drop polling (payload can arrive any time).
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    SVCTryInstall();
    for (;;) {
      [NSThread sleepForTimeInterval:2.0];
      SVCRefreshLog();
      if (!gEngineSignaled)
        SVCTryInstall();
    }
  });
}

int main(int argc, char *argv[]) {
  @autoreleasepool {
    return SDL_UIKitRunApp(argc, argv, SDL_main);
  }
}
