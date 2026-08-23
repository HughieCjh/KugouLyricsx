#import "KTLKugouLocalLyricsProvider.h"
#import "KTLKRCDecoder.h"
#import "../Core/KTLLyricsTimingPolicy.h"

@implementation KTLKugouLocalLyricsResult
@end

@interface KTLKugouLocalLyricsProvider ()
@property(nonatomic, strong) NSURL *lyricsDirectory;
@end

@implementation KTLKugouLocalLyricsProvider

- (instancetype)initWithLyricsDirectory:(NSURL *)lyricsDirectory {
    self = [super init];
    if (self) _lyricsDirectory = lyricsDirectory;
    return self;
}

- (KTLKugouLocalLyricsResult *)lyricsForTitle:(NSString *)title error:(NSError **)error {
    return [self lyricsForTitle:title duration:0 error:error];
}

- (KTLKugouLocalLyricsResult *)lyricsForTitle:(NSString *)title
                                      duration:(NSTimeInterval)duration
                                         error:(NSError **)error {
    NSArray<NSURL *> *files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:self.lyricsDirectory
                                                          includingPropertiesForKeys:@[NSURLContentModificationDateKey]
                                                                             options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                               error:error];
    if (!files) return nil;

    NSString *needle = [NSString stringWithFormat:@" - %@_", title];
    NSPredicate *matchesTitle = [NSPredicate predicateWithBlock:^BOOL(NSURL *url, NSDictionary *bindings) {
        (void)bindings;
        return [url.pathExtension.lowercaseString isEqual:@"krc"] && [url.lastPathComponent containsString:needle];
    }];
    NSArray<NSURL *> *matches = [[files filteredArrayUsingPredicate:matchesTitle]
        sortedArrayUsingComparator:^NSComparisonResult(NSURL *left, NSURL *right) {
            NSDate *leftDate = nil;
            NSDate *rightDate = nil;
            [left getResourceValue:&leftDate forKey:NSURLContentModificationDateKey error:nil];
            [right getResourceValue:&rightDate forKey:NSURLContentModificationDateKey error:nil];
            return [rightDate ?: NSDate.distantPast compare:leftDate ?: NSDate.distantPast];
        }];
    NSURL *fileURL = matches.firstObject;
    if (!fileURL) return nil;

    NSData *data = [NSData dataWithContentsOfURL:fileURL options:NSDataReadingMappedIfSafe error:error];
    if (!data) return nil;
    NSString *decoded = [KTLKRCDecoder decodeData:data error:error];
    if (!decoded) return nil;
    NSArray *lines = [KTLKRCParser parseString:decoded];
    NSArray *karaokeLines = [KTLKRCParser parseKaraokeString:decoded];
    if (lines.count == 0) return nil;

    NSString *stem = fileURL.lastPathComponent.stringByDeletingPathExtension;
    NSRange hashSeparator = [stem rangeOfString:@"_" options:NSBackwardsSearch];
    if (hashSeparator.location != NSNotFound) stem = [stem substringToIndex:hashSeparator.location];
    NSRange artistSeparator = [stem rangeOfString:@" - "];

    KTLKugouLocalLyricsResult *result = [KTLKugouLocalLyricsResult new];
    result.artist = artistSeparator.location == NSNotFound ? @"" : [stem substringToIndex:artistSeparator.location];
    result.title = artistSeparator.location == NSNotFound ? title : [stem substringFromIndex:NSMaxRange(artistSeparator)];
    result.lines = lines;
    result.karaokeLines = karaokeLines;
    result.sourceURL = fileURL;
    NSTimeInterval lastLyricEnd = 0;
    for (NSDictionary<NSString *, id> *line in lines) {
        NSTimeInterval end = [line[@"endTime"] respondsToSelector:@selector(doubleValue)]
            ? [line[@"endTime"] doubleValue]
            : [line[@"time"] doubleValue];
        lastLyricEnd = MAX(lastLyricEnd, end);
    }
    result.lastLyricEnd = lastLyricEnd;
    result.timingCompatible = [KTLLyricsTimingPolicy isLastLyricEndTime:lastLyricEnd
                                             compatibleWithTrackDuration:duration];
    return result;
}

@end
