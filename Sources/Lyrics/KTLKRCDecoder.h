#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KTLKRCDecoder : NSObject
+ (nullable NSString *)decodeData:(NSData *)data error:(NSError **)error;
@end


@interface KTLKRCParser : NSObject
+ (NSArray<NSDictionary<NSString *, id> *> *)parseString:(NSString *)source;
+ (NSArray<NSDictionary<NSString *, id> *> *)parseKaraokeString:(NSString *)source;
@end

NS_ASSUME_NONNULL_END
