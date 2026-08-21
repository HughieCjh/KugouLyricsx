#import "KTLTrack.h"
#import <CommonCrypto/CommonDigest.h>

@implementation KTLTrack

- (instancetype)initWithTitle:(NSString *)title artist:(NSString *)artist duration:(NSTimeInterval)duration {
    self = [super init];
    if (self) {
        _title = [title copy];
        _artist = [artist copy];
        _duration = duration;
    }
    return self;
}

- (NSString *)normalizedTitle {
    NSString *value = self.title;
    NSArray<NSString *> *patterns = @[
        @"\\s*[\\(（\\[].*?(live|现场|remaster(?:ed)?|伴奏|纯音乐|无损|高品质).*?[\\)）\\]]\\s*",
        @"\\s+-\\s+(live|remaster(?:ed)?).*?$"
    ];
    for (NSString *pattern in patterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                options:NSRegularExpressionCaseInsensitive
                                                                                  error:nil];
        value = [regex stringByReplacingMatchesInString:value
                                                options:0
                                                  range:NSMakeRange(0, value.length)
                                           withTemplate:@""];
    }
    return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (NSString *)cacheKey {
    NSString *source = [NSString stringWithFormat:@"%@|%@|%.0f",
                        self.normalizedTitle.lowercaseString,
                        self.artist.lowercaseString,
                        round(self.duration)];
    NSData *data = [source dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [result appendFormat:@"%02x", digest[i]];
    return result;
}

@end
