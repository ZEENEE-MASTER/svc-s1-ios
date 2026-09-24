#define SDL_MAIN_HANDLED
#import <SDL2/SDL.h>
#import <GameController/GameController.h>
#import "SVCGamepadBridge.h"

// Keys_P1 mapping (save/config.ini): dirs=arrows, A=a B=s C=d X=z Y=x Z=c.
static SDL_Keycode codeForControl(NSString *control) {
  static NSDictionary *map = nil;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    map = @{
      @"up" : @(SDLK_UP), @"down" : @(SDLK_DOWN),
      @"left" : @(SDLK_LEFT), @"right" : @(SDLK_RIGHT),
      @"a" : @(SDLK_a), @"b" : @(SDLK_s),
      @"x" : @(SDLK_z), @"y" : @(SDLK_x),
      @"lb" : @(SDLK_d), @"rb" : @(SDLK_c),
      @"start" : @(SDLK_RETURN), @"menu" : @(SDLK_e),
    };
  });
  return (SDL_Keycode)[map[control] intValue];
}

static void pushKey(NSString *control, BOOL down) {
  if (!SDL_WasInit(SDL_INIT_VIDEO))
    return;
  SDL_Event ev;
  SDL_memset(&ev, 0, sizeof(ev));
  ev.type = down ? SDL_KEYDOWN : SDL_KEYUP;
  ev.key.state = down ? SDL_PRESSED : SDL_RELEASED;
  ev.key.keysym.sym = codeForControl(control);
  SDL_PushEvent(&ev);
}

@implementation SVCGamepadBridge

+ (void)startPolling {
  static BOOL started = NO;
  if (started)
    return;
  started = YES;
  NSMutableDictionary<NSString *, NSNumber *> *state = [NSMutableDictionary dictionary];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
    for (;;) {
      @autoreleasepool {
        NSMutableDictionary<NSString *, NSNumber *> *now = [NSMutableDictionary dictionary];
        for (GCController *c in [GCController controllers]) {
          GCExtendedGamepad *g = c.extendedGamepad;
          if (!g)
            continue;
          float dx = g.leftThumbstick.xAxis.value + g.dpad.xAxis.value;
          float dy = g.leftThumbstick.yAxis.value + g.dpad.yAxis.value;
          now[@"left"] = @(dx < -0.4);
          now[@"right"] = @(dx > 0.4);
          now[@"up"] = @(dy > 0.4);
          now[@"down"] = @(dy < -0.4);
          now[@"a"] = @(g.buttonA.isPressed);
          now[@"b"] = @(g.buttonB.isPressed);
          now[@"x"] = @(g.buttonX.isPressed);
          now[@"y"] = @(g.buttonY.isPressed);
          now[@"lb"] = @(g.leftShoulder.isPressed);
          now[@"rb"] = @(g.rightShoulder.isPressed);
          now[@"start"] = @(g.buttonMenu.isPressed);
          now[@"menu"] = @(g.buttonOptions.isPressed);
        }
        for (NSString *k in now) {
          BOOL was = [state[k] boolValue], is = [now[k] boolValue];
          if (is != was)
            pushKey(k, is);
        }
        [state setDictionary:now];
      }
      [NSThread sleepForTimeInterval:1.0 / 60.0];
    }
  });
}

@end
