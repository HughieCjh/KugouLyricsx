#import "KTLKugouLocalLyricsProvider.h"
#import "KTLKRCDecoder.h"
#import "../Core/KTLLyricsTimingPolicy.h"

@implementation KTLKugouLocalLyricsResult
@end

@interface KTLKugouLocalLyricsProvider ()
@property(nonatomic, copy) NSArray<NSURL *> *lyricsDirectories;
@end

@implementation KTLKugouLocalLyricsProvider

+ (NSArray<NSURL *> *)defaultLyricsDirectories {
    NSString *containerPath = [NSHomeDirectory() stringByAppendingPathComponent:
        @"Library/Containers/com.kugou.mac.Music/Data"];
    return @[
        [NSURL fileURLWithPath:[containerPath stringByAppendingPathComponent:
            @"Library/Application Support/com.kugou.mac.Music/Caches/kgLyric"]],
        [NSURL fileURLWithPath:[containerPath stringByAppendingPathComponent:@"Documents/Caches/kgLyric"]]
    ];
}

- (instancetype)initWithLyricsDirectory:(NSURL *)lyricsDirectory {
    return [self initWithLyricsDirectories:@[lyricsDirectory]];
}

- (instancetype)initWithLyricsDirectories:(NSArray<NSURL *> *)lyricsDirectories {
    self = [super init];
    if (self) _lyricsDirectories = [lyricsDirectories copy];
    return self;
}

- (KTLKugouLocalLyricsResult *)lyricsForTitle:(NSString *)title error:(NSError **)error {
    return [self lyricsForTitle:title duration:0 error:error];
}

- (KTLKugouLocalLyricsResult *)lyricsForTitle:(NSString *)title
                                      duration:(NSTimeInterval)duration
                                         error:(NSError **)error {
    return [self lyricsForTitle:title artist:@"" duration:duration error:error];
}

+ (NSString *)normalizedIdentity:(NSString *)value {
    NSMutableCharacterSet *allowed = [NSCharacterSet.letterCharacterSet mutableCopy];
    [allowed formUnionWithCharacterSet:NSCharacterSet.decimalDigitCharacterSet];
    NSArray *parts = [value.lowercaseString componentsSeparatedByCharactersInSet:allowed.invertedSet];
    return [parts componentsJoinedByString:@""];
}

- (KTLKugouLocalLyricsResult *)lyricsForTitle:(NSString *)title
                                        artist:(NSString *)artist
                                      duration:(NSTimeInterval)duration
                                         error:(NSError **)error {
    NSString *wantedTitle = [KTLKugouLocalLyricsProvider normalizedIdentity:title];
    NSString *wantedArtist = [KTLKugouLocalLyricsProvider normalizedIdentity:artist];
    KTLKugouLocalLyricsResult *best = nil;
    NSTimeInterval bestDifference = DBL_MAX;
    NSDate *bestDate = NSDate.distantPast;
    for (NSURL *directory in self.lyricsDirectories) {
        NSArray<NSURL *> *files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:directory
            includingPropertiesForKeys:@[NSURLContentModificationDateKey]
                           options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
        for (NSURL *fileURL in files) {
            if (![fileURL.pathExtension.lowercaseString isEqual:@"krc"]) continue;
            NSString *stem = fileURL.lastPathComponent.stringByDeletingPathExtension;
            NSRange hashSeparator = [stem rangeOfString:@"_" options:NSBackwardsSearch];
            if (hashSeparator.location == NSNotFound) continue;
            stem = [stem substringToIndex:hashSeparator.location];
            NSRange artistSeparator = [stem rangeOfString:@" - "];
            if (artistSeparator.location == NSNotFound) continue;
            NSString *fileArtist = [stem substringToIndex:artistSeparator.location];
            NSString *fileTitle = [stem substringFromIndex:NSMaxRange(artistSeparator)];
            if (![[KTLKugouLocalLyricsProvider normalizedIdentity:fileTitle] isEqual:wantedTitle]) continue;
            if (wantedArtist.length > 0 &&
                ![[KTLKugouLocalLyricsProvider normalizedIdentity:fileArtist] isEqual:wantedArtist]) continue;

            NSData *data = [NSData dataWithContentsOfURL:fileURL options:NSDataReadingMappedIfSafe error:error];
            NSString *decoded = data ? [KTLKRCDecoder decodeData:data error:error] : nil;
            if (!decoded) continue;
            NSArray *lines = [KTLKRCParser parseString:decoded];
            if (lines.count == 0) continue;
            NSTimeInterval lastLyricEnd = 0;
            for (NSDictionary<NSString *, id> *line in lines) {
                NSTimeInterval end = [line[@"endTime"] respondsToSelector:@selector(doubleValue)]
                    ? [line[@"endTime"] doubleValue] : [line[@"time"] doubleValue];
                lastLyricEnd = MAX(lastLyricEnd, end);
            }
            BOOL compatible = [KTLLyricsTimingPolicy isLastLyricEndTime:lastLyricEnd
                                            compatibleWithTrackDuration:duration];
            NSTimeInterval difference = duration > 0 ? fabs(duration - lastLyricEnd) : 0;
            if (!compatible) difference += 10000;
            NSDate *date = nil;
            [fileURL getResourceValue:&date forKey:NSURLContentModificationDateKey error:nil];
            date = date ?: NSDate.distantPast;
            if (best && (difference > bestDifference ||
                         (difference == bestDifference && [date compare:bestDate] != NSOrderedDescending))) continue;
            KTLKugouLocalLyricsResult *candidate = [KTLKugouLocalLyricsResult new];
            candidate.artist = fileArtist;
            candidate.title = fileTitle;
            candidate.lines = lines;
            candidate.karaokeLines = [KTLKRCParser parseKaraokeString:decoded];
            candidate.sourceURL = fileURL;
            candidate.lastLyricEnd = lastLyricEnd;
            candidate.timingCompatible = compatible;
            best = candidate;
            bestDifference = difference;
            bestDate = date;
        }
    }
    return best;
}

@end
