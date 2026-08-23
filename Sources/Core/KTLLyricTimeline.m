#import "KTLLyricTimeline.h"

@implementation KTLLyricTimeline

- (instancetype)initWithLines:(NSArray<NSDictionary<NSString *, id> *> *)lines {
    self = [super init];
    if (self) {
        _lines = [lines sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
            return [left[@"time"] compare:right[@"time"]];
        }];
    }
    return self;
}

- (NSDictionary<NSString *, id> *)lineAtTime:(NSTimeInterval)time {
    if (self.lines.count == 0 || time < [self.lines[0][@"time"] doubleValue]) return nil;
    NSUInteger lower = 0;
    NSUInteger upper = self.lines.count;
    while (lower < upper) {
        NSUInteger middle = lower + (upper - lower) / 2;
        if ([self.lines[middle][@"time"] doubleValue] <= time) lower = middle + 1;
        else upper = middle;
    }
    NSDictionary<NSString *, id> *line = self.lines[lower - 1];
    id endTime = line[@"endTime"];
    if ([endTime respondsToSelector:@selector(doubleValue)] &&
        [endTime doubleValue] > [line[@"time"] doubleValue] &&
        time >= [endTime doubleValue]) return nil;
    return line;
}

@end
