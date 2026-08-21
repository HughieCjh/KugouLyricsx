#import <Foundation/Foundation.h>

@class KTLTrack;

NS_ASSUME_NONNULL_BEGIN

@interface KTLLyricsCache : NSObject
- (instancetype)initWithDirectoryURL:(NSURL *)directoryURL;
- (nullable NSString *)lyricsForTrack:(KTLTrack *)track;
- (BOOL)storeLyrics:(NSString *)lyrics forTrack:(KTLTrack *)track error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
