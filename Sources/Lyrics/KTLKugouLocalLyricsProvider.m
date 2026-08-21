#import "KTLKugouLocalLyricsProvider.h"
#import "KTLKRCDecoder.h"

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
    if (lines.count == 0) return nil;

    NSString *stem = fileURL.lastPathComponent.stringByDeletingPathExtension;
    NSRange hashSeparator = [stem rangeOfString:@"_" options:NSBackwardsSearch];
    if (hashSeparator.location != NSNotFound) stem = [stem substringToIndex:hashSeparator.location];
    NSRange artistSeparator = [stem rangeOfString:@" - "];

    KTLKugouLocalLyricsResult *result = [KTLKugouLocalLyricsResult new];
    result.artist = artistSeparator.location == NSNotFound ? @"" : [stem substringToIndex:artistSeparator.location];
    result.title = artistSeparator.location == NSNotFound ? title : [stem substringFromIndex:NSMaxRange(artistSeparator)];
    result.lines = lines;
    result.sourceURL = fileURL;
    return result;
}

@end
