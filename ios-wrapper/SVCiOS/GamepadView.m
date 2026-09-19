// Stub: 4-dir + 6-button + start/menu, left/right player sides.
// TODO(Phase 2): multi-touch tracking, haptics, edit-mode layout,
// event injection into engine.
#import "GamepadView.h"

@implementation SVCGamepadView

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.multipleTouchEnabled = YES;
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = YES;
  }
  return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  // TODO: hit-test against button rects, notify delegate.
  [self.delegate gamepadButton:SVCGameButtonA pressed:YES];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [self.delegate gamepadButton:SVCGameButtonA pressed:NO];
}

@end
