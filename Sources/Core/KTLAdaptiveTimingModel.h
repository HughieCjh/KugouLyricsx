#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KTLAdaptiveTimingModel : NSObject
- (void)resetForNewTrack;
- (void)cancelPendingMeasurement;
- (void)observePresentation:(nullable NSDictionary<NSString *, id> *)presentation
                         key:(NSString *)key
                playbackTime:(NSTimeInterval)playbackTime;
- (double)scaleForPresentationKey:(NSString *)key;
@end

NS_ASSUME_NONNULL_END
