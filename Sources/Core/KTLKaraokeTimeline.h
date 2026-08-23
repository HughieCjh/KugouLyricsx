#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KTLKaraokeTimeline : NSObject
+ (nullable NSDictionary<NSString *, id> *)presentationForLiveText:(NSString *)liveText
                                                              lines:(NSArray<NSDictionary<NSString *, id> *> *)lines;
+ (NSDictionary<NSString *, NSNumber *> *)highlightForLine:(NSDictionary<NSString *, id> *)line
                                               relativeTime:(NSTimeInterval)relativeTime;
+ (nullable NSDictionary<NSString *, id> *)nextFragmentAfterPresentation:(NSDictionary<NSString *, id> *)presentation
                                                                     lines:(NSArray<NSDictionary<NSString *, id> *> *)lines;
+ (nullable NSDictionary<NSString *, id> *)nextPresentationAfterPresentation:(NSDictionary<NSString *, id> *)presentation
                                                                         lines:(NSArray<NSDictionary<NSString *, id> *> *)lines;
@end

NS_ASSUME_NONNULL_END
