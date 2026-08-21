#import "KTLLyricsCache.h"
#import "KTLTrack.h"

@interface KTLLyricsCache ()
@property(nonatomic, strong) NSURL *directoryURL;
@end

@implementation KTLLyricsCache

- (instancetype)initWithDirectoryURL:(NSURL *)directoryURL {
    self = [super init];
    if (self) _directoryURL = directoryURL;
    return self;
}

- (NSURL *)URLForTrack:(KTLTrack *)track {
    return [self.directoryURL URLByAppendingPathComponent:[track.cacheKey stringByAppendingPathExtension:@"lrc"]];
}

- (NSString *)lyricsForTrack:(KTLTrack *)track {
    return [NSString stringWithContentsOfURL:[self URLForTrack:track]
                                   encoding:NSUTF8StringEncoding
                                      error:nil];
}

- (BOOL)storeLyrics:(NSString *)lyrics forTrack:(KTLTrack *)track error:(NSError **)error {
    NSFileManager *manager = NSFileManager.defaultManager;
    if (![manager createDirectoryAtURL:self.directoryURL
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:error]) return NO;
    return [lyrics writeToURL:[self URLForTrack:track]
                   atomically:YES
                     encoding:NSUTF8StringEncoding
                        error:error];
}

@end
