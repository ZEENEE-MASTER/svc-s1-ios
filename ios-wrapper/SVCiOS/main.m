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
#import "AssetDownloader.h"
#import "SVCGamepadBridge.h"

@interface SVCAppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation SVCAppDelegate {
  UIWindow *_padWindow;
  UILabel *_statusLabel;
  UITextView *_logView;
  UILabel *_padLabel;
  NSString *_docs;
  NSString *_logPath;
  BOOL _engineStarted;
  BOOL _overlayHidden;
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
  // No touch controls: Backbone (MFi bridge) is the input.
  // Diagnostics hide synchronously: the main thread is about to block
  // inside the engine, so no main-queue timer could fire afterwards.
  // Triple-tap (event-driven) brings them back.
  [self setOverlayHidden:YES];
  [SVCGamepadBridge startPolling];
  UITapGestureRecognizer *triple = [[UITapGestureRecognizer alloc]
      initWithTarget:self action:@selector(toggleOverlay)];
  triple.numberOfTapsRequired = 3;
  [self->_padWindow.rootViewController.view addGestureRecognizer:triple];
  // Blocks inside the engine's game loop (pumps SDL events per frame).
  SVCStart([self->_docs UTF8String]);
}

- (void)setOverlayHidden:(BOOL)hidden {
  self->_overlayHidden = hidden;
  self->_statusLabel.hidden = hidden;
  self->_logView.hidden = hidden;
  self->_padLabel.hidden = hidden;
}

- (void)toggleOverlay {
  [self setOverlayHidden:!self->_overlayHidden];
}

// MFi / game-controller visibility straight from SDL.
- (void)refreshPadLabel {
  NSString *txt;
  if (!SDL_WasInit(SDL_INIT_JOYSTICK)) {
    txt = @"Pads: (engine starting)";
  } else {
    int n = SDL_NumJoysticks();
    if (n <= 0) {
      txt = @"Pads: none — connect an MFi controller";
    } else {
      const char *nm = SDL_JoystickNameForIndex(0);
      txt = [NSString stringWithFormat:@"Pads: %d (%s)", n, nm ? nm : "?"];
    }
  }
  dispatch_async(dispatch_get_main_queue(), ^{
    self->_padLabel.text = txt;
  });
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
  // SDL_MAIN_HANDLED is defined (our main must stay main), so SDL requires
  // this handshake before SDL_Init or init fails with "Application didn't
  // initialize properly". SDL_UIKitRunApp does it internally; we do it here.
  SDL_SetMainReady();
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
  NSString *buildNo = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
  _statusLabel.text = [NSString stringWithFormat:@"SVC S1 · build %@",
                                                 buildNo ?: @"?"];
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

  _padLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, b.size.height - 64, b.size.width - 40, 24)];
  _padLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
  _padLabel.textColor = [UIColor yellowColor];
  _padLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
  _padLabel.textAlignment = NSTextAlignmentCenter;
  _padLabel.font = [UIFont systemFontOfSize:12];
  _padLabel.text = @"Pads: ?";
  [_padWindow.rootViewController.view addSubview:_padLabel];

  _padWindow.hidden = NO;
  [self refreshLogView];
  [self refreshPadLabel];

  // Install + Files-drop polling (payload can arrive any time).
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    [self tryInstall];
    for (;;) {
      [NSThread sleepForTimeInterval:2.0];
      [self refreshLogView];
      [self refreshPadLabel];
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

// Engine asks for the native screen size (SDL reports 320x480 pre-window).
void SVCGetScreenPoints(float *w, float *h) {
  CGSize s = [UIScreen mainScreen].bounds.size;
  if (w)
    *w = (float)(s.width > s.height ? s.width : s.height);
  if (h)
    *h = (float)(s.height > s.width ? s.height : s.width);
}
