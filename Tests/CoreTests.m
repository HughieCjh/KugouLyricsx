#import <Foundation/Foundation.h>
#import "../Sources/Core/KTLLRCParser.h"
#import "../Sources/Core/KTLLyricTimeline.h"
#import "../Sources/Core/KTLTrack.h"
#import "../Sources/Core/KTLLyricsCache.h"
#import "../Sources/Core/KTLKeepAwakePolicy.h"
#import "../Sources/Media/KTLNowPlaying.h"
#import "../Sources/Lyrics/KTLKRCDecoder.h"
#import "../Sources/Lyrics/KTLKugouLocalLyricsProvider.h"
#import <zlib.h>

static void Assert(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static NSData *EncodeKRCForTest(NSString *plainText) {
    NSData *input = [plainText dataUsingEncoding:NSUTF8StringEncoding];
    uLongf compressedSize = compressBound(input.length);
    NSMutableData *compressed = [NSMutableData dataWithLength:compressedSize];
    int status = compress(compressed.mutableBytes, &compressedSize, input.bytes, (uLong)input.length);
    Assert(status == Z_OK, @"test fixture compression should succeed");
    compressed.length = compressedSize;
    const uint8_t key[16] = {0x40,0x47,0x61,0x77,0x5E,0x32,0x74,0x47,0x51,0x36,0x31,0x2D,0xCE,0xD2,0x6E,0x69};
    NSMutableData *encoded = [NSMutableData dataWithBytes:"krc1" length:4];
    NSMutableData *body = [compressed mutableCopy];
    uint8_t *bytes = body.mutableBytes;
    for (NSUInteger i = 0; i < body.length; i++) bytes[i] ^= key[i % 16];
    [encoded appendData:body];
    return encoded;
}

int main(void) {
    @autoreleasepool {
        NSString *source = @"[ar:歌手]\n[00:01.50][00:03.250]第一句\n[offset:250]\n[00:05]<00:05>第<00:05.2>二句";
        NSArray *lines = [KTLLRCParser parseString:source];
        Assert(lines.count == 3, @"LRC should expand multiple timestamps");
        Assert(fabs([lines[0][@"time"] doubleValue] - 1.5) < 0.001, @"fraction should parse");
        Assert([lines[2][@"text"] isEqual:@"第二句"], @"enhanced tags should be removed");

        KTLLyricTimeline *timeline = [[KTLLyricTimeline alloc] initWithLines:lines];
        Assert([timeline lineAtTime:1.4] == nil, @"timeline should be empty before first line");
        Assert([[[timeline lineAtTime:4.9] objectForKey:@"text"] isEqual:@"第一句"], @"timeline should pick latest line");

        KTLTrack *track = [[KTLTrack alloc] initWithTitle:@"夜曲（Live）" artist:@"周杰伦" duration:226.4];
        Assert([track.normalizedTitle isEqual:@"夜曲"], @"title suffix should be removed");
        Assert(track.cacheKey.length == 64, @"cache key should be SHA-256");

        NSURL *cacheURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"KTLCoreTests"]];
        KTLLyricsCache *cache = [[KTLLyricsCache alloc] initWithDirectoryURL:cacheURL];
        NSError *error = nil;
        Assert([cache storeLyrics:@"[00:01]测试" forTrack:track error:&error], @"cache write should succeed");
        Assert([[cache lyricsForTrack:track] isEqual:@"[00:01]测试"], @"cache should round-trip");

        KTLNowPlaying *state = [KTLNowPlaying nowPlayingFromDictionary:@{
            @"title": @"夜曲",
            @"artist": @"周杰伦",
            @"duration": @226,
            @"elapsed": @10,
            @"playbackRate": @1,
            @"playing": @YES,
            @"bundleIdentifier": @"com.kugou.mac",
            @"appName": @"酷狗音乐"
        }];
        Assert(state.isKugou, @"Kugou identity should be recognized");
        Assert(state.isPlaying, @"positive playback rate should mean playing");

        KTLNowPlaying *mediaControlState = [KTLNowPlaying nowPlayingFromDictionary:@{
            @"title": @"你",
            @"elapsed": @1,
            @"elapsedTime": @10,
            @"elapsedTimeNow": @23.75,
            @"playing": @YES
        }];
        Assert(fabs(mediaControlState.elapsed - 23.75) < 0.001,
               @"live media-control elapsedTimeNow should take precedence");

        KTLNowPlaying *mediaControlFallbackState = [KTLNowPlaying nowPlayingFromDictionary:@{
            @"title": @"你",
            @"elapsedTime": @18.5,
            @"playing": @YES
        }];
        Assert(fabs(mediaControlFallbackState.elapsed - 18.5) < 0.001,
               @"media-control elapsedTime should be accepted when live position is absent");

        KTLNowPlaying *seekPrimary = [KTLNowPlaying nowPlayingFromDictionary:@{
            @"title": @"拖动测试",
            @"artist": @"测试歌手",
            @"duration": @240,
            @"elapsedTimeNow": @42,
            @"playing": @YES
        }];
        KTLNowPlaying *seekPosition = [KTLNowPlaying nowPlayingFromDictionary:@{
            @"title": @"拖动测试",
            @"artist": @"测试歌手",
            @"duration": @240,
            @"elapsed": @137,
            @"playing": @YES
        }];
        KTLNowPlaying *seekResult = [KTLNowPlaying reconciledPrimary:seekPrimary
                                                      positionSource:seekPosition];
        Assert(fabs(seekResult.elapsed - 137) < 0.001,
               @"direct playback position should correct stale progress after seeking");

        KTLNowPlaying *otherTrackPosition = [KTLNowPlaying nowPlayingFromDictionary:@{
            @"title": @"另一首歌",
            @"elapsed": @9
        }];
        [KTLNowPlaying reconciledPrimary:seekPrimary positionSource:otherTrackPosition];
        Assert(fabs(seekPrimary.elapsed - 137) < 0.001,
               @"a racing snapshot from another track must not change the position");

        KTLNowPlaying *missingPosition = [KTLNowPlaying nowPlayingFromDictionary:@{
            @"title": @"拖动测试",
            @"elapsed": NSNull.null
        }];
        [KTLNowPlaying reconciledPrimary:seekPrimary positionSource:missingPosition];
        Assert(fabs(seekPrimary.elapsed - 137) < 0.001,
               @"a missing position must not reset lyrics to the beginning");

        KTLNowPlaying *transitionState = [KTLNowPlaying nowPlayingFromDictionary:@{
            @"title": @"切歌中",
            @"duration": NSNull.null,
            @"elapsed": NSNull.null,
            @"playbackRate": NSNull.null
        }];
        Assert(transitionState.duration == 0 && transitionState.elapsed == 0,
               @"null numeric fields during track changes should be safe");

        KTLNowPlaying *pausedState = [KTLNowPlaying nowPlayingFromDictionary:@{
            @"title": @"暂停测试",
            @"playbackRate": @1,
            @"playing": @NO
        }];
        Assert(!pausedState.isPlaying, @"explicit playing flag should override stale playback rate");

        Assert([KTLKeepAwakePolicy shouldPreventDisplaySleepWithPreferenceEnabled:YES
                                                                          isKugou:YES
                                                                         isPlaying:YES],
               @"enabled preference should keep the display awake during Kugou playback");
        Assert(![KTLKeepAwakePolicy shouldPreventDisplaySleepWithPreferenceEnabled:NO
                                                                           isKugou:YES
                                                                          isPlaying:YES],
               @"disabled preference should preserve normal display sleep");
        Assert(![KTLKeepAwakePolicy shouldPreventDisplaySleepWithPreferenceEnabled:YES
                                                                           isKugou:YES
                                                                          isPlaying:NO],
               @"paused Kugou playback should release the display assertion");
        Assert(![KTLKeepAwakePolicy shouldPreventDisplaySleepWithPreferenceEnabled:YES
                                                                           isKugou:NO
                                                                          isPlaying:YES],
               @"another media player should not keep the display awake");

        NSString *krcText = @"[0,1000]<0,500,0>你<500,500,0>好\n[1000,1000]<0,1000,0>世界";
        NSString *decodedKRC = [KTLKRCDecoder decodeData:EncodeKRCForTest(krcText) error:&error];
        Assert([decodedKRC isEqual:krcText], @"KRC should decrypt and inflate");
        NSArray *krcLines = [KTLKRCParser parseString:decodedKRC];
        Assert(krcLines.count == 2, @"KRC lines should parse");
        Assert([krcLines[0][@"text"] isEqual:@"你好"], @"KRC word timing tags should be removed");

        NSLog(@"PASS: all core tests");
    }
    return 0;
}
