#import <Foundation/Foundation.h>

@class KTLNowPlaying;

NS_ASSUME_NONNULL_BEGIN

typedef void (^KTLMediaRemoteObserverHandler)(KTLNowPlaying *state);

@interface KTLMediaRemoteObserver : NSObject
- (instancetype)initWithResourcesDirectory:(NSURL *)resourcesDirectory
                                    handler:(KTLMediaRemoteObserverHandler)handler;
- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
