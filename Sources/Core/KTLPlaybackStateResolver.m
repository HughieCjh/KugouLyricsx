#import "KTLPlaybackStateResolver.h"

static const NSTimeInterval KTLPlaybackResumeMovementThreshold = 0.20;

@interface KTLPlaybackStateResolver ()
@property(nonatomic, assign) BOOL pauseLatched;
@property(nonatomic, assign) NSTimeInterval pausedElapsed;
@end

@implementation KTLPlaybackStateResolver

- (BOOL)resolvedPlayingForReportedPlaying:(BOOL)reportedPlaying
                                   elapsed:(NSTimeInterval)elapsed {
    if (!reportedPlaying) {
        self.pauseLatched = YES;
        if (isfinite(elapsed)) self.pausedElapsed = elapsed;
        return NO;
    }
    if (!self.pauseLatched) return YES;
    if (isfinite(elapsed) && elapsed - self.pausedElapsed > KTLPlaybackResumeMovementThreshold) {
        self.pauseLatched = NO;
        return YES;
    }
    return NO;
}

- (void)noteUserRequestedResume {
    self.pauseLatched = NO;
}

- (void)reset {
    self.pauseLatched = NO;
    self.pausedElapsed = 0;
}

@end
