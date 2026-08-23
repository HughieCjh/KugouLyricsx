#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KTLLyricsTimingPolicy : NSObject
+ (BOOL)isLastLyricEndTime:(NSTimeInterval)lastLyricEnd
 compatibleWithTrackDuration:(NSTimeInterval)trackDuration;
@end

NS_ASSUME_NONNULL_END
