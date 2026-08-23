#import "KTLKaraokeTimeline.h"

@implementation KTLKaraokeTimeline

+ (NSString *)normalizedText:(NSString *)text {
    NSMutableCharacterSet *allowed = [NSCharacterSet.letterCharacterSet mutableCopy];
    [allowed formUnionWithCharacterSet:NSCharacterSet.decimalDigitCharacterSet];
    NSArray<NSString *> *parts = [text.lowercaseString componentsSeparatedByCharactersInSet:allowed.invertedSet];
    return [parts componentsJoinedByString:@""];
}

+ (NSDictionary<NSString *, id> *)presentationForLiveText:(NSString *)liveText
                                                      lines:(NSArray<NSDictionary<NSString *, id> *> *)lines {
    NSString *visible = [liveText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (visible.length == 0) return nil;
    NSString *normalizedVisible = [self normalizedText:visible];
    NSDictionary *bestLine = nil;
    NSRange bestRange = NSMakeRange(NSNotFound, 0);
    BOOL exact = NO;
    NSUInteger bestIndex = NSNotFound;
    for (NSUInteger lineIndex = 0; lineIndex < lines.count; lineIndex++) {
        NSDictionary *line = lines[lineIndex];
        NSString *candidate = [line[@"text"] isKindOfClass:NSString.class] ? line[@"text"] : @"";
        NSRange literalRange = [candidate rangeOfString:visible options:NSCaseInsensitiveSearch];
        BOOL candidateExact = [candidate isEqualToString:visible];
        if (literalRange.location != NSNotFound && (!bestLine || candidateExact)) {
            bestLine = line;
            bestRange = literalRange;
            bestIndex = lineIndex;
            exact = candidateExact;
            if (exact) break;
        }
        if (!bestLine && normalizedVisible.length > 0) {
            NSString *normalizedCandidate = [self normalizedText:candidate];
            if ([normalizedCandidate containsString:normalizedVisible] ||
                [normalizedVisible containsString:normalizedCandidate]) {
                bestLine = line;
                bestIndex = lineIndex;
            }
        }
    }
    if (!bestLine) return nil;

    NSString *sourceText = bestLine[@"text"];
    if (bestRange.location == NSNotFound) {
        if ([[self normalizedText:sourceText] isEqualToString:normalizedVisible]) {
            bestRange = NSMakeRange(0, sourceText.length);
        } else {
            return @{ @"text": visible, @"segments": @[], @"time": bestLine[@"time"] ?: @0,
                      @"duration": bestLine[@"duration"] ?: @0, @"sourceIndex": @(bestIndex),
                      @"sourceRange": [NSValue valueWithRange:NSMakeRange(0, sourceText.length)],
                      @"metadata": bestLine[@"metadata"] ?: @NO };
        }
    }

    NSMutableArray *clippedSegments = [NSMutableArray array];
    for (NSDictionary *segment in bestLine[@"segments"] ?: @[]) {
        NSRange range = [segment[@"range"] rangeValue];
        NSRange intersection = NSIntersectionRange(range, bestRange);
        if (intersection.length == 0) continue;
        NSTimeInterval offset = [segment[@"offset"] doubleValue];
        NSTimeInterval segmentDuration = [segment[@"duration"] doubleValue];
        if (range.length > 0 && intersection.location > range.location) {
            offset += segmentDuration * (double)(intersection.location - range.location) / (double)range.length;
        }
        NSTimeInterval clippedDuration = range.length > 0
            ? segmentDuration * (double)intersection.length / (double)range.length
            : segmentDuration;
        NSRange visibleRange = NSMakeRange(intersection.location - bestRange.location, intersection.length);
        [clippedSegments addObject:@{
            @"text": [sourceText substringWithRange:intersection],
            @"range": [NSValue valueWithRange:visibleRange],
            @"offset": @(offset),
            @"duration": @(clippedDuration)
        }];
    }
    return @{
        @"text": visible,
        @"segments": clippedSegments,
        @"time": bestLine[@"time"] ?: @0,
        @"duration": bestLine[@"duration"] ?: @0,
        @"sourceIndex": @(bestIndex),
        @"sourceRange": [NSValue valueWithRange:bestRange],
        @"metadata": bestLine[@"metadata"] ?: @NO
    };
}

+ (NSDictionary<NSString *, id> *)nextFragmentAfterPresentation:(NSDictionary<NSString *, id> *)presentation
                                                            lines:(NSArray<NSDictionary<NSString *, id> *> *)lines {
    NSUInteger sourceIndex = [presentation[@"sourceIndex"] unsignedIntegerValue];
    if (sourceIndex >= lines.count || !presentation[@"sourceRange"]) return nil;
    NSDictionary *sourceLine = lines[sourceIndex];
    NSString *sourceText = [sourceLine[@"text"] isKindOfClass:NSString.class] ? sourceLine[@"text"] : @"";
    NSRange sourceRange = [presentation[@"sourceRange"] rangeValue];
    if (NSMaxRange(sourceRange) >= sourceText.length) return nil;
    NSRange suffixRange = NSMakeRange(NSMaxRange(sourceRange), sourceText.length - NSMaxRange(sourceRange));
    NSString *suffix = [[sourceText substringWithRange:suffixRange]
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (suffix.length == 0) return nil;
    NSDictionary *fragment = [self presentationForLiveText:suffix lines:@[sourceLine]];
    if (!fragment) return nil;
    NSMutableDictionary *result = [fragment mutableCopy];
    result[@"sourceIndex"] = @(sourceIndex);
    return result;
}

+ (NSDictionary<NSString *, id> *)nextPresentationAfterPresentation:(NSDictionary<NSString *, id> *)presentation
                                                                lines:(NSArray<NSDictionary<NSString *, id> *> *)lines {
    NSDictionary *fragment = [self nextFragmentAfterPresentation:presentation lines:lines];
    if (fragment) return fragment;
    NSUInteger sourceIndex = [presentation[@"sourceIndex"] unsignedIntegerValue];
    NSUInteger nextIndex = sourceIndex + 1;
    while (nextIndex < lines.count && [lines[nextIndex][@"metadata"] boolValue]) nextIndex += 1;
    if (sourceIndex == NSNotFound || nextIndex >= lines.count) return nil;
    NSDictionary *line = lines[nextIndex];
    NSString *text = [line[@"text"] isKindOfClass:NSString.class] ? line[@"text"] : @"";
    if (text.length == 0) return nil;
    NSRange separator = [text rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (separator.location != NSNotFound && separator.location > 0) {
        NSString *firstPhrase = [[text substringToIndex:separator.location]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSDictionary *phrase = [self presentationForLiveText:firstPhrase lines:@[line]];
        if (phrase) {
            NSMutableDictionary *result = [phrase mutableCopy];
            result[@"sourceIndex"] = @(nextIndex);
            return result;
        }
    }
    NSMutableDictionary *result = [line mutableCopy];
    result[@"sourceIndex"] = @(nextIndex);
    result[@"sourceRange"] = [NSValue valueWithRange:NSMakeRange(0, text.length)];
    return result;
}

+ (NSDictionary<NSString *, NSNumber *> *)highlightForLine:(NSDictionary<NSString *, id> *)line
                                               relativeTime:(NSTimeInterval)relativeTime {
    NSString *text = [line[@"text"] isKindOfClass:NSString.class] ? line[@"text"] : @"";
    NSArray<NSDictionary<NSString *, id> *> *segments = line[@"segments"];
    if (relativeTime < 0) return @{ @"completedLength": @0, @"characterFraction": @0 };
    if (segments.count == 0) {
        return @{ @"completedLength": @(text.length), @"characterFraction": @0 };
    }

    NSUInteger completed = 0;
    for (NSDictionary *segment in segments) {
        NSRange range = [segment[@"range"] rangeValue];
        NSTimeInterval start = [segment[@"offset"] doubleValue];
        NSTimeInterval duration = MAX(0, [segment[@"duration"] doubleValue]);
        if (relativeTime < start) break;
        if (duration == 0 || relativeTime >= start + duration) {
            completed = MAX(completed, NSMaxRange(range));
            continue;
        }
        double segmentProgress = MIN(1, MAX(0, (relativeTime - start) / duration));
        double characterProgress = segmentProgress * range.length;
        NSUInteger wholeCharacters = (NSUInteger)floor(characterProgress);
        return @{
            @"completedLength": @(MIN(text.length, range.location + wholeCharacters)),
            @"characterFraction": @(characterProgress - wholeCharacters)
        };
    }
    return @{ @"completedLength": @(MIN(text.length, completed)), @"characterFraction": @0 };
}

@end
