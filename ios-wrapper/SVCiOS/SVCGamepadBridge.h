// SVCGamepadBridge — MFi polling bridge (background thread, no runloop needed).
// Reads GCController state at 60 Hz and injects SDL keyboard events matching
// save/config.ini [Keys_P1], so menus AND fights respond identically to the
// touch pad. SDL_PushEvent is thread-safe; the engine polls them normally.
#import <Foundation/Foundation.h>

@interface SVCGamepadBridge : NSObject
+ (void)startPolling;
@end
