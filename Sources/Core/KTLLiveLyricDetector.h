#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KTLLiveLyricDetector : NSObject
@property(nonatomic, assign, readonly, getter=isActive) BOOL active;
@property(nonatomic, copy, readonly) NSString *currentLyric;
- (void)resetWithKnownLines:(NSArray<NSDictionary<NSString *, id> *> *)lines;
- (void)observeMediaText:(NSString *)text;
@end

NS_ASSUME_NONNULL_END
