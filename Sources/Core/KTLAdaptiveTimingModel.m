#import "KTLAdaptiveTimingModel.h"

static const double KTLAdaptiveTimingPreviousWeight = 0.65;
static const double KTLAdaptiveTimingObservationWeight = 0.35;
static const double KTLAdaptiveTimingMinimumRatio = 0.55;
static const double KTLAdaptiveTimingMaximumRatio = 1.80;

@interface KTLAdaptiveTimingModel ()
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *learnedScales;
@property(nonatomic, copy) NSString *pendingKey;
@property(nonatomic, strong, nullable) NSDictionary<NSString *, id> *pendingPresentation;
@property(nonatomic, assign) NSTimeInterval pendingPlaybackTime;
@end

@implementation KTLAdaptiveTimingModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _learnedScales = [NSMutableDictionary dictionary];
        _pendingKey = @"";
    }
    return self;
}

- (void)resetForNewTrack {
    [self.learnedScales removeAllObjects];
    [self cancelPendingMeasurement];
}

- (void)cancelPendingMeasurement {
    self.pendingKey = @"";
    self.pendingPresentation = nil;
    self.pendingPlaybackTime = 0;
}

- (void)observePresentation:(NSDictionary<NSString *, id> *)presentation
                         key:(NSString *)key
                playbackTime:(NSTimeInterval)playbackTime {
    if (!isfinite(playbackTime)) {
        [self cancelPendingMeasurement];
        return;
    }
    if (presentation && key.length > 0 && [key isEqualToString:self.pendingKey]) return;

    if (self.pendingPresentation && self.pendingKey.length > 0) {
        NSTimeInterval actualDuration = playbackTime - self.pendingPlaybackTime;
        NSTimeInterval krcDuration = [self phraseDurationForPresentation:self.pendingPresentation];
        double observedScale = krcDuration > 0 ? actualDuration / krcDuration : 0;
        BOOL valid = actualDuration >= 0.25 && actualDuration <= 15.0 &&
            krcDuration >= 0.1 && observedScale >= KTLAdaptiveTimingMinimumRatio &&
            observedScale <= KTLAdaptiveTimingMaximumRatio;
        if (valid) {
            NSNumber *previousValue = self.learnedScales[self.pendingKey];
            double learnedScale = previousValue
                ? previousValue.doubleValue * KTLAdaptiveTimingPreviousWeight +
                    observedScale * KTLAdaptiveTimingObservationWeight
                : observedScale;
            self.learnedScales[self.pendingKey] = @(learnedScale);
        }
    }

    if (!presentation || key.length == 0) {
        [self cancelPendingMeasurement];
        return;
    }

    self.pendingKey = key;
    self.pendingPresentation = presentation;
    self.pendingPlaybackTime = playbackTime;
}

- (double)scaleForPresentationKey:(NSString *)key {
    NSNumber *scale = self.learnedScales[key];
    return scale ? scale.doubleValue : 1.0;
}

- (NSTimeInterval)phraseDurationForPresentation:(NSDictionary<NSString *, id> *)presentation {
    NSArray<NSDictionary<NSString *, id> *> *segments = presentation[@"segments"];
    NSDictionary *firstSegment = segments.firstObject;
    NSDictionary *lastSegment = segments.lastObject;
    if (!firstSegment || !lastSegment) return 0;
    NSTimeInterval firstOffset = [firstSegment[@"offset"] doubleValue];
    NSTimeInterval lastEnd = [lastSegment[@"offset"] doubleValue] +
        [lastSegment[@"duration"] doubleValue];
    return MAX(0, lastEnd - firstOffset);
}

@end
