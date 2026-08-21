#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A lyric line is represented as @{ @"time": NSNumber, @"text": NSString }.
@interface KTLLRCParser : NSObject
+ (NSArray<NSDictionary<NSString *, id> *> *)parseString:(NSString *)source;
@end

NS_ASSUME_NONNULL_END
