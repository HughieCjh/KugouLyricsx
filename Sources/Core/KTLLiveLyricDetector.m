#import "KTLLiveLyricDetector.h"

@interface KTLLiveLyricDetector ()
@property(nonatomic, assign, readwrite, getter=isActive) BOOL active;
@property(nonatomic, copy, readwrite) NSString *currentLyric;
@property(nonatomic, copy) NSArray<NSString *> *normalizedKnownLyrics;
@property(nonatomic, copy) NSString *lastObservedText;
@property(nonatomic, assign) NSUInteger observedChangeCount;
@end

@implementation KTLLiveLyricDetector

- (instancetype)init {
    self = [super init];
    if (self) [self resetWithKnownLines:@[]];
    return self;
}

+ (NSString *)normalizedText:(NSString *)text {
    NSMutableCharacterSet *allowed = [NSCharacterSet.letterCharacterSet mutableCopy];
    [allowed formUnionWithCharacterSet:NSCharacterSet.decimalDigitCharacterSet];
    NSArray<NSString *> *parts = [text.lowercaseString componentsSeparatedByCharactersInSet:allowed.invertedSet];
    return [parts componentsJoinedByString:@""];
}

- (void)resetWithKnownLines:(NSArray<NSDictionary<NSString *, id> *> *)lines {
    NSMutableArray<NSString *> *known = [NSMutableArray array];
    for (NSDictionary<NSString *, id> *line in lines) {
        if ([line[@"metadata"] boolValue]) continue;
        NSString *text = [line[@"text"] isKindOfClass:NSString.class] ? line[@"text"] : @"";
        NSString *normalized = [KTLLiveLyricDetector normalizedText:text];
        if (normalized.length >= 2) [known addObject:normalized];
    }
    self.normalizedKnownLyrics = known;
    self.active = NO;
    self.currentLyric = @"";
    self.lastObservedText = @"";
    self.observedChangeCount = 0;
}

- (BOOL)matchesKnownLyric:(NSString *)text {
    NSString *candidate = [KTLLiveLyricDetector normalizedText:text];
    if (candidate.length < 2) return NO;
    for (NSString *known in self.normalizedKnownLyrics) {
        if ([known containsString:candidate] || [candidate containsString:known]) return YES;
    }
    return NO;
}

- (void)observeMediaText:(NSString *)text {
    NSString *value = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (self.active) {
        self.currentLyric = value;
        if (value.length > 0) self.lastObservedText = value;
        return;
    }

    if ([self matchesKnownLyric:value]) self.active = YES;
    if (value.length > 0 && self.lastObservedText.length > 0 &&
        ![value isEqualToString:self.lastObservedText]) {
        self.observedChangeCount += 1;
        if (self.observedChangeCount >= 2) self.active = YES;
    }
    if (value.length > 0) self.lastObservedText = value;
    self.currentLyric = self.active ? value : @"";
}

@end
