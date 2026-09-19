#import "AssetDownloader.h"
#import "vendor/miniz/miniz.h"
#import "vendor/miniz/miniz_zip.h"

@implementation AssetDownloader

+ (NSString *)documentsDir {
  return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                              NSUserDomainMask, YES) firstObject];
}

// A payload is present when the engine entry files exist in Documents/.
+ (BOOL)payloadPresent {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *docs = [self documentsDir];
  return [fm fileExistsAtPath:[docs stringByAppendingPathComponent:@"data/select.def"]] &&
         [fm fileExistsAtPath:[docs stringByAppendingPathComponent:@"save/config.ini"]];
}

+ (void)ensurePayloadWithCompletion:(void (^)(BOOL, NSString *))completion {
  if ([self payloadPresent]) {
    completion(YES, @"present");
    return;
  }
  // Bundled Lite payload (SVCiOS/Resources/payload-lite.zip) unpacks first.
  NSString *bundled = [[NSBundle mainBundle] pathForResource:@"payload-lite"
                                                      ofType:@"zip"];
  if (bundled && [self unzipFile:bundled toDir:[self documentsDir]]) {
    completion([self payloadPresent], @"bundled lite");
    return;
  }
  // Otherwise the CDN packs flow (packs.manifest) takes over in Phase 3.
  // URLs are NOT baked into the binary: fetched from the team's private
  // manifest endpoint after first launch.
  completion(NO, @"needs CDN packs (Phase 3)");
}

+ (BOOL)installPack:(NSString *)zipPath {
  NSString *docs = [self documentsDir];
  NSString *name = [[zipPath lastPathComponent] stringByDeletingPathExtension];
  NSString *target = docs;
  if ([name isEqualToString:@"payload-lite"]) {
    target = docs;
  } else if ([name hasPrefix:@"chars-"]) {
    target = [docs stringByAppendingPathComponent:
                       [@"chars" stringByAppendingPathComponent:[name substringFromIndex:6]]];
  } else if ([name isEqualToString:@"stages-full"]) {
    target = [docs stringByAppendingPathComponent:@"stages"];
  } else if ([name isEqualToString:@"data-full"]) {
    target = [docs stringByAppendingPathComponent:@"data"];
  } else if ([name isEqualToString:@"sound-full"]) {
    target = [docs stringByAppendingPathComponent:@"sound"];
  } else {
    return NO;
  }
  // Full data pack replaces the lite select.def (roster grows with packs).
  return [self unzipFile:zipPath toDir:target];
}

+ (BOOL)unzipFile:(NSString *)zipPath toDir:(NSString *)dir {
  mz_zip_archive zip;
  memset(&zip, 0, sizeof(zip));
  if (!mz_zip_reader_init_file(&zip, [zipPath UTF8String], 0))
    return NO;
  BOOL ok = YES;
  mz_uint count = mz_zip_reader_get_num_files(&zip);
  for (mz_uint i = 0; i < count && ok; i++) {
    mz_zip_archive_file_stat st;
    if (!mz_zip_reader_file_stat(&zip, i, &st)) {
      ok = NO;
      break;
    }
    NSString *out =
        [[dir stringByAppendingPathComponent:@(st.m_filename)] stringByStandardizingPath];
    // Zip-slip guard: stay inside dir.
    if (![out hasPrefix:[dir stringByStandardizingPath]]) {
      ok = NO;
      break;
    }
    if (mz_zip_reader_is_file_a_directory(&zip, i)) {
      [[NSFileManager defaultManager] createDirectoryAtPath:out
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:nil];
    } else {
      NSString *parent = [out stringByDeletingLastPathComponent];
      [[NSFileManager defaultManager] createDirectoryAtPath:parent
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:nil];
      if (!mz_zip_reader_extract_to_file(&zip, i, [out UTF8String], 0))
        ok = NO;
    }
  }
  mz_zip_reader_end(&zip);
  return ok;
}

@end
