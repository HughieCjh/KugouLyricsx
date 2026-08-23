#import "KTLRemoteLyricsService.h"
#import "../Core/KTLLRCParser.h"

@implementation KTLRemoteLyricsResult
@end

@implementation KTLRemoteLyricsService

- (void)fetchLyricsForTitle:(NSString *)title
                   duration:(NSTimeInterval)duration
                 completion:(KTLRemoteLyricsCompletion)completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        KTLRemoteLyricsResult *result = [self fetchNeteaseTitle:title duration:duration];
        if (!result) result = [self fetchLRCLIBTitle:title duration:duration];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(result); });
    });
}

- (nullable id)JSONForURL:(NSURL *)URL {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.timeoutInterval = 8;
    [request setValue:@"Mozilla/5.0 KugouLyricsx/0.3" forHTTPHeaderField:@"User-Agent"];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSData *responseData = nil;
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request
                                                              completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        (void)response;
        if (!error) responseData = data;
        dispatch_semaphore_signal(semaphore);
    }];
    [task resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 9 * NSEC_PER_SEC));
    if (!responseData) {
        [task cancel];
        return nil;
    }
    return [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
}

- (NSString *)escaped:(NSString *)value {
    NSCharacterSet *allowed = NSCharacterSet.URLQueryAllowedCharacterSet;
    return [value stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

- (KTLRemoteLyricsResult *)fetchNeteaseTitle:(NSString *)title duration:(NSTimeInterval)duration {
    (void)duration;
    NSString *URLString = [NSString stringWithFormat:
        @"https://music.163.com/api/search/get/web?csrf_token=&s=%@&type=1&offset=0&total=true&limit=8",
        [self escaped:title]];
    NSDictionary *search = [self JSONForURL:[NSURL URLWithString:URLString]];
    NSArray *songs = [search[@"result"][@"songs"] isKindOfClass:NSArray.class] ? search[@"result"][@"songs"] : nil;
    NSDictionary *selected = nil;
    for (NSDictionary *song in songs) {
        NSString *name = [song[@"name"] isKindOfClass:NSString.class] ? song[@"name"] : @"";
        if ([name localizedCaseInsensitiveCompare:title] == NSOrderedSame) { selected = song; break; }
    }
    if (!selected) selected = songs.firstObject;
    NSNumber *songID = selected[@"id"];
    if (!songID) return nil;

    NSString *lyricURL = [NSString stringWithFormat:@"https://music.163.com/api/song/lyric?id=%@&lv=1&kv=1&tv=-1", songID];
    NSDictionary *payload = [self JSONForURL:[NSURL URLWithString:lyricURL]];
    NSString *lyric = [payload[@"lrc"][@"lyric"] isKindOfClass:NSString.class] ? payload[@"lrc"][@"lyric"] : nil;
    NSArray *lines = lyric ? [KTLLRCParser parseString:lyric] : @[];
    if (lines.count == 0) return nil;

    NSArray *artists = [selected[@"artists"] isKindOfClass:NSArray.class] ? selected[@"artists"] : @[];
    NSString *artist = [artists.firstObject[@"name"] isKindOfClass:NSString.class] ? artists.firstObject[@"name"] : @"";
    KTLRemoteLyricsResult *result = [KTLRemoteLyricsResult new];
    result.artist = artist;
    result.sourceName = @"网易云音乐";
    result.lines = lines;
    return result;
}

- (KTLRemoteLyricsResult *)fetchLRCLIBTitle:(NSString *)title duration:(NSTimeInterval)duration {
    NSString *URLString = [NSString stringWithFormat:@"https://lrclib.net/api/search?track_name=%@", [self escaped:title]];
    NSArray *items = [self JSONForURL:[NSURL URLWithString:URLString]];
    if (![items isKindOfClass:NSArray.class]) return nil;

    NSDictionary *best = nil;
    NSTimeInterval bestDifference = DBL_MAX;
    for (NSDictionary *item in items) {
        NSString *synced = [item[@"syncedLyrics"] isKindOfClass:NSString.class] ? item[@"syncedLyrics"] : @"";
        if (synced.length == 0) continue;
        NSString *name = [item[@"trackName"] isKindOfClass:NSString.class] ? item[@"trackName"] : @"";
        if ([name rangeOfString:title options:NSCaseInsensitiveSearch].location == NSNotFound &&
            [title rangeOfString:name options:NSCaseInsensitiveSearch].location == NSNotFound) continue;
        NSTimeInterval difference = duration > 0 ? fabs([item[@"duration"] doubleValue] - duration) : 0;
        if (difference < bestDifference) { best = item; bestDifference = difference; }
    }
    if (!best || (duration > 0 && bestDifference > 8)) return nil;
    NSArray *lines = [KTLLRCParser parseString:best[@"syncedLyrics"]];
    if (lines.count == 0) return nil;

    KTLRemoteLyricsResult *result = [KTLRemoteLyricsResult new];
    result.artist = [best[@"artistName"] isKindOfClass:NSString.class] ? best[@"artistName"] : @"";
    result.sourceName = @"LRCLIB";
    result.lines = lines;
    return result;
}

@end
