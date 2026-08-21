#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KTLKeepAwakePolicy : NSObject
+ (BOOL)shouldPreventDisplaySleepWithPreferenceEnabled:(BOOL)preferenceEnabled
                                               isKugou:(BOOL)isKugou
                                              isPlaying:(BOOL)isPlaying;
@end

NS_ASSUME_NONNULL_END
