#import <Foundation/Foundation.h>

@class KTLNowPlaying;

typedef NS_ENUM(NSInteger, KTLMediaCommand) {
    KTLMediaCommandPlay = 0,
    KTLMediaCommandPause = 1,
    KTLMediaCommandTogglePlayPause = 2,
    KTLMediaCommandStop = 3,
    KTLMediaCommandNext = 4,
    KTLMediaCommandPrevious = 5,
};

NS_ASSUME_NONNULL_BEGIN

@interface KTLMediaRemoteClient : NSObject
- (instancetype)initWithResourcesDirectory:(NSURL *)resourcesDirectory;
- (nullable KTLNowPlaying *)snapshotWithError:(NSError **)error;
- (BOOL)sendCommand:(KTLMediaCommand)command error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
