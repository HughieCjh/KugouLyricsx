#import "KTLLyricsTimingPolicy.h"

@implementation KTLLyricsTimingPolicy

+ (BOOL)isLastLyricEndTime:(NSTimeInterval)lastLyricEnd
 compatibleWithTrackDuration:(NSTimeInterval)trackDuration {
    if (lastLyricEnd <= 0 || trackDuration <= 0) return YES;
    if (lastLyricEnd > trackDuration + 15.0) return NO;
    return lastLyricEnd / trackDuration >= 0.70;
}

@end
