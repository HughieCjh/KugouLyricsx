#import "KTLKeepAwakePolicy.h"

@implementation KTLKeepAwakePolicy

+ (BOOL)shouldPreventDisplaySleepWithPreferenceEnabled:(BOOL)preferenceEnabled
                                               isKugou:(BOOL)isKugou
                                              isPlaying:(BOOL)isPlaying {
    return preferenceEnabled && isKugou && isPlaying;
}

@end
