#import "KTLLRCParser.h"

@implementation KTLLRCParser

+ (NSArray<NSDictionary<NSString *, id> *> *)parseString:(NSString *)source {
    NSRegularExpression *timestamp = [NSRegularExpression
        regularExpressionWithPattern:@"\\[(\\d+):([0-5]?\\d)(?:[\\.:](\\d{1,3}))?\\]"
        options:0
        error:nil];
    NSRegularExpression *enhanced = [NSRegularExpression
        regularExpressionWithPattern:@"<\\d+:[0-5]?\\d(?:[\\.:]\\d{1,3})?>"
        options:0
        error:nil];
    NSMutableArray<NSDictionary<NSString *, id> *> *lines = [NSMutableArray array];
    __block NSTimeInterval offset = 0;

    [source enumerateLinesUsingBlock:^(NSString *rawLine, BOOL *stop) {
        (void)stop;
        NSString *lower = rawLine.lowercaseString;
        if ([lower hasPrefix:@"[offset:"]) {
            NSRange closing = [lower rangeOfString:@"]"];
            if (closing.location != NSNotFound && closing.location > 8) {
                NSString *milliseconds = [lower substringWithRange:NSMakeRange(8, closing.location - 8)];
                offset = milliseconds.doubleValue / 1000.0;
            }
            return;
        }

        NSArray<NSTextCheckingResult *> *matches = [timestamp matchesInString:rawLine
                                                                      options:0
                                                                        range:NSMakeRange(0, rawLine.length)];
        if (matches.count == 0) return;

        NSUInteger lyricStart = 0;
        for (NSTextCheckingResult *match in matches) {
            lyricStart = MAX(lyricStart, NSMaxRange(match.range));
        }
        NSString *text = [rawLine substringFromIndex:lyricStart];
        text = [enhanced stringByReplacingMatchesInString:text
                                                  options:0
                                                    range:NSMakeRange(0, text.length)
                                             withTemplate:@""];
        text = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (text.length == 0) return;

        for (NSTextCheckingResult *match in matches) {
            double minutes = [[rawLine substringWithRange:[match rangeAtIndex:1]] doubleValue];
            double seconds = [[rawLine substringWithRange:[match rangeAtIndex:2]] doubleValue];
            double fraction = 0;
            NSRange fractionRange = [match rangeAtIndex:3];
            if (fractionRange.location != NSNotFound) {
                NSString *digits = [rawLine substringWithRange:fractionRange];
                fraction = digits.doubleValue;
                for (NSUInteger i = 0; i < digits.length; i++) fraction /= 10.0;
            }
            double time = MAX(0, minutes * 60.0 + seconds + fraction + offset);
            [lines addObject:@{ @"time": @(time), @"text": text }];
        }
    }];

    [lines sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[@"time"] compare:right[@"time"]];
    }];

    NSMutableArray *deduplicated = [NSMutableArray array];
    for (NSDictionary *line in lines) {
        if (![deduplicated.lastObject isEqual:line]) [deduplicated addObject:line];
    }
    return deduplicated;
}

@end
