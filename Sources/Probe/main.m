#import <Foundation/Foundation.h>
#import "../Media/KTLMediaRemoteClient.h"
#import "../Media/KTLNowPlaying.h"
#import "../Lyrics/KTLKugouLocalLyricsProvider.h"
#import "../Core/KTLLyricTimeline.h"
#import "../Core/KTLLiveLyricDetector.h"
#import "../Core/KTLKaraokeTimeline.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *resourcesPath = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : @"Resources";
        KTLMediaRemoteClient *client = [[KTLMediaRemoteClient alloc]
            initWithResourcesDirectory:[NSURL fileURLWithPath:resourcesPath]];
        NSError *error = nil;
        KTLNowPlaying *state = [client snapshotWithError:&error];
        if (error) {
            fprintf(stderr, "%s\n", error.localizedDescription.UTF8String);
            return 1;
        }
        if (!state) {
            printf("{\"status\":\"idle\"}\n");
            return 2;
        }
        NSMutableDictionary *report = [state.dictionaryRepresentation mutableCopy];
        NSString *lyricsPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Containers/com.kugou.mac.Music/Data/Documents/Caches/kgLyric"];
        KTLKugouLocalLyricsProvider *provider = [[KTLKugouLocalLyricsProvider alloc]
            initWithLyricsDirectory:[NSURL fileURLWithPath:lyricsPath]];
        KTLKugouLocalLyricsResult *lyrics = [provider lyricsForTitle:state.title
                                                           duration:state.duration
                                                              error:nil];
        if (lyrics) {
            KTLLyricTimeline *timeline = [[KTLLyricTimeline alloc] initWithLines:lyrics.lines];
            KTLLiveLyricDetector *detector = [KTLLiveLyricDetector new];
            [detector resetWithKnownLines:lyrics.karaokeLines];
            [detector observeMediaText:state.artist ?: @""];
            report[@"resolvedArtist"] = lyrics.artist;
            report[@"currentLyric"] = [timeline lineAtTime:state.elapsed][@"text"] ?: @"";
            report[@"lyricLineCount"] = @(lyrics.lines.count);
            report[@"lyricsSource"] = lyrics.sourceURL.path;
            report[@"lastLyricEnd"] = @(lyrics.lastLyricEnd);
            report[@"timingCompatible"] = @(lyrics.timingCompatible);
            report[@"liveLyricsDetected"] = @(detector.isActive);
            report[@"liveLyric"] = detector.currentLyric;
            NSDictionary *karaoke = [KTLKaraokeTimeline presentationForLiveText:state.artist ?: @""
                                                                             lines:lyrics.karaokeLines];
            report[@"karaokeMatched"] = @(karaoke != nil);
            report[@"karaokeSegmentCount"] = @([karaoke[@"segments"] count]);
        }
        NSData *json = [NSJSONSerialization dataWithJSONObject:report
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
        fwrite(json.bytes, 1, json.length, stdout);
        printf("\n");
        return state.isKugou ? 0 : 3;
    }
}
