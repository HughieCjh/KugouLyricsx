#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KTLTrack : NSObject
@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) NSString *artist;
@property(nonatomic, assign, readonly) NSTimeInterval duration;
- (instancetype)initWithTitle:(NSString *)title artist:(NSString *)artist duration:(NSTimeInterval)duration;
- (NSString *)normalizedTitle;
- (NSString *)cacheKey;
@end

NS_ASSUME_NONNULL_END
