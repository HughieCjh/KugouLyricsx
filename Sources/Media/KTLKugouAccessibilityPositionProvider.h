#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KTLKugouAccessibilityPositionProvider : NSObject
@property(nonatomic, readonly, getter=isAuthorized) BOOL authorized;
+ (BOOL)parseElapsedTimeText:(NSString *)text elapsed:(NSTimeInterval *)elapsed;
+ (BOOL)shouldAdoptElapsed:(NSTimeInterval)accessibilityElapsed
          estimatedElapsed:(NSTimeInterval)estimatedElapsed;
+ (BOOL)isAccessibilityDuration:(NSTimeInterval)accessibilityDuration
  compatibleWithExpectedDuration:(NSTimeInterval)expectedDuration;
- (BOOL)requestAuthorization;
- (nullable NSNumber *)currentElapsedTimeForExpectedDuration:(NSTimeInterval)expectedDuration;
@end

NS_ASSUME_NONNULL_END
