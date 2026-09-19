// AssetDownloader — manifest-driven payload fetch + miniz unzip into Documents/.
// Packs are built by tools/Build-LitePacks.ps1 (S1-Lite + per-fighter/stage
// zips + packs.sha256). URLs come from packs.manifest (CDN, signed URLs).
#import <Foundation/Foundation.h>

@interface AssetDownloader : NSObject
// Ensures the bundled/lite payload exists; downloads missing packs.
// Completion runs on the main queue.
+ (void)ensurePayloadWithCompletion:(void (^)(BOOL ready, NSString *note))completion;
// Synchronous first-launch install with progress. Returns YES when
// Documents/ holds a bootable payload. Progress block may run off-main.
+ (BOOL)installPayloadWithProgress:(void (^)(NSUInteger current, NSUInteger total, NSString *entry))progress
                              note:(NSString **)note;
// Installs one CDN pack zip into its engine-relative location:
//   payload-lite.zip -> Documents/ ; chars-<X>.zip -> Documents/chars/<X>/
//   stages-full.zip -> Documents/stages/ ; data-full.zip -> Documents/data/
//   sound-full.zip -> Documents/sound/
+ (BOOL)installPack:(NSString *)zipPath;
// Zip entries MUST use forward slashes (built by tools/zip-packs.py);
// backslash entries extract as literal filenames on iOS.
+ (BOOL)unzipFile:(NSString *)zipPath toDir:(NSString *)dir;
@end
