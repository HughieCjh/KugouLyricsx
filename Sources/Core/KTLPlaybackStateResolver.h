#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KTLPlaybackStateResolver : NSObject
- (BOOL)resolvedPlayingForReportedPlaying:(BOOL)reportedPlaying
                                   elapsed:(NSTimeInterval)elapsed;
- (void)noteUserRequestedResume;
- (void)reset;
@end

NS_ASSUME_NONNULL_END
