// Full touch fight-stick: 4-dir + 6-button + start/menu, multi-touch,
// drag-to-arrange edit mode persisted to NSUserDefaults.
// Input reaches the engine as SDL keyboard events matching save/config.ini
// [Keys_P1] (dirs=arrows, A=a B=s C=d X=z Y=x Z=c, Start=Return, Menu=e).
// The engine polls these in system_sdl.go pollEvents -> OnKeyPressed.
#define SDL_MAIN_HANDLED
#import <SDL2/SDL.h>
#import "GamepadView.h"

static NSString *const kPadLayoutKey = @"SVCGamepadLayoutV1";

@interface SVCGamepadView ()
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, NSValue *> *buttonRects;
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, NSNumber *> *touchOwners;
@property (nonatomic) BOOL editMode;
@end

@implementation SVCGamepadView

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.multipleTouchEnabled = YES;
    self.backgroundColor = [UIColor clearColor];
    _buttonRects = [NSMutableDictionary dictionary];
    _touchOwners = [NSMutableDictionary dictionary];
    [self loadOrDefaultLayoutInBounds:frame];
  }
  return self;
}

- (NSArray<NSNumber *> *)allButtons {
  return @[
    @(SVCGameButtonUp), @(SVCGameButtonDown), @(SVCGameButtonLeft),
    @(SVCGameButtonRight), @(SVCGameButtonA), @(SVCGameButtonB),
    @(SVCGameButtonC), @(SVCGameButtonX), @(SVCGameButtonY),
    @(SVCGameButtonZ), @(SVCGameButtonStart), @(SVCGameButtonMenu)
  ];
}

// Default: d-pad bottom-left, 6-button arc bottom-right, start/menu top.
- (void)loadOrDefaultLayoutInBounds:(CGRect)b {
  NSDictionary *saved =
      [[NSUserDefaults standardUserDefaults] dictionaryForKey:kPadLayoutKey];
  CGFloat d = 64.0, gap = 8.0;
  CGFloat leftX = 24.0, baseY = b.size.height - 24.0 - d;
  NSDictionary *def = @{
    @(SVCGameButtonLeft) : @[@(leftX), @(baseY - d - gap), @(d), @(d)],
    @(SVCGameButtonRight) : @[@(leftX + 2 * (d + gap)), @(baseY - d - gap), @(d), @(d)],
    @(SVCGameButtonUp) : @[@(leftX + d + gap), @(baseY - 2 * d - 2 * gap), @(d), @(d)],
    @(SVCGameButtonDown) : @[@(leftX + d + gap), @(baseY), @(d), @(d)],
    @(SVCGameButtonX) : @[@(b.size.width - 24 - 3 * (d + gap)), @(baseY - d - gap), @(d), @(d)],
    @(SVCGameButtonY) : @[@(b.size.width - 24 - 2 * (d + gap)), @(baseY - 2 * d - 2 * gap), @(d), @(d)],
    @(SVCGameButtonZ) : @[@(b.size.width - 24 - (d + gap)), @(baseY - 2 * d - 2 * gap), @(d), @(d)],
    @(SVCGameButtonA) : @[@(b.size.width - 24 - 3 * (d + gap)), @(baseY), @(d), @(d)],
    @(SVCGameButtonB) : @[@(b.size.width - 24 - 2 * (d + gap)), @(baseY), @(d), @(d)],
    @(SVCGameButtonC) : @[@(b.size.width - 24 - (d + gap)), @(baseY), @(d), @(d)],
    @(SVCGameButtonStart) : @[@(b.size.width / 2 - d - 4), @(24), @(d), @(d / 2)],
    @(SVCGameButtonMenu) : @[@(b.size.width / 2 + 4), @(24), @(d), @(d / 2)],
  };
  for (NSNumber *btn in [self allButtons]) {
    NSArray *r = saved[[btn stringValue]] ?: def[btn];
    self.buttonRects[btn] = [NSValue
        valueWithCGRect:CGRectMake([r[0] doubleValue], [r[1] doubleValue],
                                   [r[2] doubleValue], [r[3] doubleValue])];
  }
}

- (void)saveLayout {
  NSMutableDictionary *d = [NSMutableDictionary dictionary];
  for (NSNumber *btn in [self allButtons]) {
    CGRect r = [self.buttonRects[btn] CGRectValue];
    d[[btn stringValue]] = @[ @(r.origin.x), @(r.origin.y), @(r.size.width), @(r.size.height) ];
  }
  [[NSUserDefaults standardUserDefaults] setObject:d forKey:kPadLayoutKey];
}

- (NSNumber *)buttonAtPoint:(CGPoint)p {
  for (NSNumber *btn in [self allButtons]) {
    if (CGRectContainsPoint([self.buttonRects[btn] CGRectValue], p))
      return btn;
  }
  return nil;
}

- (void)press:(NSNumber *)btn down:(BOOL)down {
  if (SDL_WasInit(SDL_INIT_VIDEO)) {
    SDL_Event ev;
    SDL_memset(&ev, 0, sizeof(ev));
    ev.type = down ? SDL_KEYDOWN : SDL_KEYUP;
    ev.key.state = down ? SDL_PRESSED : SDL_RELEASED;
    ev.key.keysym.sym = [self keycodeForButton:(SVCGameButton)[btn integerValue]];
    SDL_PushEvent(&ev);
  }
  [self.delegate gamepadButton:(SVCGameButton)[btn integerValue] pressed:down];
  [self setNeedsDisplay];
}

// Must match save/config.ini [Keys_P1].
- (SDL_Keycode)keycodeForButton:(SVCGameButton)btn {
  switch (btn) {
    case SVCGameButtonUp: return SDLK_UP;
    case SVCGameButtonDown: return SDLK_DOWN;
    case SVCGameButtonLeft: return SDLK_LEFT;
    case SVCGameButtonRight: return SDLK_RIGHT;
    case SVCGameButtonA: return SDLK_a;
    case SVCGameButtonB: return SDLK_s;
    case SVCGameButtonC: return SDLK_d;
    case SVCGameButtonX: return SDLK_z;
    case SVCGameButtonY: return SDLK_x;
    case SVCGameButtonZ: return SDLK_c;
    case SVCGameButtonStart: return SDLK_RETURN;
    case SVCGameButtonMenu: return SDLK_e;
  }
  return SDLK_UNKNOWN;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  for (UITouch *t in touches) {
    CGPoint p = [t locationInView:self];
    NSNumber *btn = [self buttonAtPoint:p];
    if (btn) {
      self.touchOwners[@((uintptr_t)(__bridge void *)t)] = btn;
      [self press:btn down:YES];
    }
  }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  for (UITouch *t in touches) {
    NSNumber *key = @((uintptr_t)(__bridge void *)t);
    NSNumber *old = self.touchOwners[key];
    NSNumber *now = [self buttonAtPoint:[t locationInView:self]];
    if (self.editMode && old) {
      // Drag the button with the finger.
      CGPoint p = [t locationInView:self];
      CGRect r = [self.buttonRects[old] CGRectValue];
      r.origin = CGPointMake(p.x - r.size.width / 2, p.y - r.size.height / 2);
      self.buttonRects[old] = [NSValue valueWithCGRect:r];
      [self setNeedsDisplay];
    } else if (old && ![old isEqual:now]) {
      [self press:old down:NO];
      if (now) {
        self.touchOwners[key] = now;
        [self press:now down:YES];
      } else {
        [self.touchOwners removeObjectForKey:key];
      }
    }
  }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [self releaseTouches:touches];
  if (self.editMode)
    [self saveLayout];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [self releaseTouches:touches];
}

- (void)releaseTouches:(NSSet<UITouch *> *)touches {
  for (UITouch *t in touches) {
    NSNumber *key = @((uintptr_t)(__bridge void *)t);
    NSNumber *btn = self.touchOwners[key];
    if (btn)
      [self press:btn down:NO];
    [self.touchOwners removeObjectForKey:key];
  }
}

- (void)drawRect:(CGRect)rect {
  [[UIColor colorWithWhite:1.0 alpha:0.18] setFill];
  for (NSNumber *btn in [self allButtons]) {
    CGRect r = [self.buttonRects[btn] CGRectValue];
    if (CGRectIntersectsRect(r, rect)) {
      UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:10];
      [p fill];
    }
  }
}

@end
