// SVCGamepadView — touch fight-stick overlay.
// Phase 2: port the CONCEPT of ikemen-droid's DynamicGamepadView:
// low-latency touch buttons -> engine key events, user-movable layout.
// Injection point TBD during engine bind (keyboard-event API or virtual
// GameController). This stub renders + hit-tests so layout work can start.
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, SVCGameButton) {
  SVCGameButtonUp, SVCGameButtonDown, SVCGameButtonLeft, SVCGameButtonRight,
  SVCGameButtonA, SVCGameButtonB, SVCGameButtonC,
  SVCGameButtonX, SVCGameButtonY, SVCGameButtonZ,
  SVCGameButtonStart, SVCGameButtonMenu,
};

@protocol SVCGamepadDelegate <NSObject>
- (void)gamepadButton:(SVCGameButton)button pressed:(BOOL)pressed;
@end

@interface SVCGamepadView : UIView
@property (weak, nonatomic) id<SVCGamepadDelegate> delegate;
@end
