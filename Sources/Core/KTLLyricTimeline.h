#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KTLLyricTimeline : NSObject
- (instancetype)initWithLines:(NSArray<NSDictionary<NSString *, id> *> *)lines;
- (nullable NSDictionary<NSString *, id> *)lineAtTime:(NSTimeInterval)time;
- (nullable NSDictionary<NSString *, id> *)nextLineAfterTime:(NSTimeInterval)time
                                            excludingMetadata:(BOOL)excludingMetadata;
@property(nonatomic, copy, readonly) NSArray<NSDictionary<NSString *, id> *> *lines;
@end

NS_ASSUME_NONNULL_END
