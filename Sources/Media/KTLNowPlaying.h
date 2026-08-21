#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KTLNowPlaying : NSObject
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *artist;
@property(nonatomic, copy) NSString *album;
@property(nonatomic, copy) NSString *bundleIdentifier;
@property(nonatomic, copy) NSString *appName;
@property(nonatomic, assign) NSTimeInterval duration;
@property(nonatomic, assign) NSTimeInterval elapsed;
@property(nonatomic, assign) double playbackRate;
@property(nonatomic, assign) BOOL reportedPlaying;
@property(nonatomic, readonly) BOOL isPlaying;
@property(nonatomic, readonly) BOOL isKugou;
+ (nullable instancetype)nowPlayingFromDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;
@end

NS_ASSUME_NONNULL_END
