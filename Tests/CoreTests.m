#import <Foundation/Foundation.h>
#import "../Sources/Core/KTLLRCParser.h"
#import "../Sources/Core/KTLLyricTimeline.h"
#import "../Sources/Core/KTLTrack.h"
#import "../Sources/Core/KTLLyricsCache.h"
#import "../Sources/Core/KTLKeepAwakePolicy.h"
#import "../Sources/Core/KTLLyricsTimingPolicy.h"
#import "../Sources/Core/KTLLiveLyricDetector.h"
#import "../Sources/Core/KTLKaraokeTimeline.h"
#import "../Sources/Core/KTLAdaptiveTimingModel.h"
#import "../Sources/Core/KTLPlaybackStateResolver.h"
#import "../Sources/Media/KTLNowPlaying.h"
#import "../Sources/Lyrics/KTLKRCDecoder.h"
#import "../Sources/Lyrics/KTLKugouLocalLyricsProvider.h"
#import "../Sources/Lyrics/KTLRemoteLyricsService.h"
#import <zlib.h>

static void Assert(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

@interface KTLRemoteLyricsService (Testing)
+ (nullable NSDictionary *)bestNeteaseSongFromItems:(NSArray<NSDictionary *> *)items
                                               title:(NSString *)title
                                            duration:(NSTimeInterval)duration;
@end

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

        KTLLyricTimeline *timedTimeline = [[KTLLyricTimeline alloc] initWithLines:@[
            @{ @"time": @1.0, @"endTime": @2.0, @"text": @"第一句" },
            @{ @"time": @5.0, @"endTime": @6.0, @"text": @"第二句" }
        ]];
        Assert([timedTimeline lineAtTime:1.5] != nil, @"timed KRC line should display during its duration");
        Assert([timedTimeline lineAtTime:3.0] == nil, @"instrumental gap should not retain the previous lyric");
        Assert([timedTimeline lineAtTime:5.5] != nil, @"next timed line should display at its own start");

        Assert(![KTLLyricsTimingPolicy isLastLyricEndTime:168.079
                                     compatibleWithTrackDuration:282.754],
               @"a 168-second lyric must not be applied to a 283-second track");
        Assert([KTLLyricsTimingPolicy isLastLyricEndTime:264
                                    compatibleWithTrackDuration:282.754],
               @"a normal outro after the last lyric should remain compatible");
        Assert([KTLLyricsTimingPolicy isLastLyricEndTime:168
                                    compatibleWithTrackDuration:0],
               @"unknown track duration should not reject local lyrics");

        KTLLiveLyricDetector *knownLyricDetector = [KTLLiveLyricDetector new];
        [knownLyricDetector resetWithKnownLines:@[
            @{ @"time": @10, @"text": @"我明白你的回答 温柔的对话" }
        ]];
        [knownLyricDetector observeMediaText:@"温柔的对话"];
        Assert(knownLyricDetector.active, @"a media field contained in known lyrics should activate live mode");
        Assert([knownLyricDetector.currentLyric isEqual:@"温柔的对话"],
               @"live detector should expose the current Kugou lyric");
        [knownLyricDetector observeMediaText:@""];
        Assert([knownLyricDetector.currentLyric isEqual:@""],
               @"blank live text should create a blank instrumental interval");

        KTLLiveLyricDetector *stableArtistDetector = [KTLLiveLyricDetector new];
        [stableArtistDetector resetWithKnownLines:@[]];
        [stableArtistDetector observeMediaText:@"吴半首"];
        [stableArtistDetector observeMediaText:@"吴半首"];
        [stableArtistDetector observeMediaText:@"吴半首"];
        Assert(!stableArtistDetector.active, @"a stable artist name must not be mistaken for live lyrics");

        KTLLiveLyricDetector *changingTextDetector = [KTLLiveLyricDetector new];
        [changingTextDetector resetWithKnownLines:@[]];
        [changingTextDetector observeMediaText:@"第一条动态文本"];
        [changingTextDetector observeMediaText:@"第二条动态文本"];
        Assert(!changingTextDetector.active, @"one metadata correction is not enough to activate live lyrics");
        [changingTextDetector observeMediaText:@"第三条动态文本"];
        Assert(changingTextDetector.active, @"repeated media text changes should activate live lyrics");

        NSDictionary *shortVersion = @{ @"id": @1, @"name": @"你", @"duration": @168079 };
        NSDictionary *matchingVersion = @{ @"id": @2, @"name": @"你", @"duration": @282500 };
        NSDictionary *selectedVersion = [KTLRemoteLyricsService bestNeteaseSongFromItems:@[
            shortVersion,
            matchingVersion
        ] title:@"你" duration:282.754];
        Assert([selectedVersion[@"id"] isEqual:@2],
               @"remote fallback should choose the same-duration version of a same-title song");
        Assert([KTLRemoteLyricsService bestNeteaseSongFromItems:@[shortVersion]
                                                           title:@"你"
                                                        duration:282.754] == nil,
               @"remote fallback should reject a severely mismatched same-title version");

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

        KTLPlaybackStateResolver *playbackResolver = [KTLPlaybackStateResolver new];
        Assert([playbackResolver resolvedPlayingForReportedPlaying:YES elapsed:10.0],
               @"playing should pass through before any pause is observed");
        Assert(![playbackResolver resolvedPlayingForReportedPlaying:NO elapsed:12.0],
               @"an explicit pause should stop the resolved playback clock immediately");
        Assert(![playbackResolver resolvedPlayingForReportedPlaying:YES elapsed:12.0],
               @"a stale playing event at the same position must not undo a pause");
        Assert(![playbackResolver resolvedPlayingForReportedPlaying:YES elapsed:12.1],
               @"tiny position jitter must not be mistaken for resumed playback");
        Assert([playbackResolver resolvedPlayingForReportedPlaying:YES elapsed:12.3],
               @"real forward position movement should release the pause latch");
        Assert(![playbackResolver resolvedPlayingForReportedPlaying:NO elapsed:20.0],
               @"a later pause should latch again");
        [playbackResolver noteUserRequestedResume];
        Assert([playbackResolver resolvedPlayingForReportedPlaying:YES elapsed:20.0],
               @"an explicit resume request should accept the next playing event immediately");
        Assert(![playbackResolver resolvedPlayingForReportedPlaying:NO elapsed:30.0],
               @"pause should still work after an explicit resume");
        [playbackResolver reset];
        Assert([playbackResolver resolvedPlayingForReportedPlaying:YES elapsed:0.0],
               @"track changes and seeks should clear playback-state history");

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
        NSArray *firstSegments = krcLines[0][@"segments"];
        Assert(firstSegments.count == 2, @"KRC word segments should be preserved");
        Assert([firstSegments[0][@"text"] isEqual:@"你"], @"segment text should be preserved");
        Assert([firstSegments[0][@"range"] rangeValue].location == 0 &&
               [firstSegments[1][@"range"] rangeValue].location == 1,
               @"segment ranges should address the rendered lyric text");
        Assert(fabs([firstSegments[1][@"offset"] doubleValue] - 0.5) < 0.001,
               @"segment offsets should be converted to seconds");
        Assert(fabs([firstSegments[1][@"duration"] doubleValue] - 0.5) < 0.001,
               @"segment durations should be converted to seconds");

        NSString *metadataKRC = @"[156,1473]<0,1473,0>你 (dadada~ 风轻轻) - 吴半首\n"
            "[1630,415]<0,415,0>作词：测试\n"
            "[2046,10]<0,10,0>制作人：测试\n"
            "[16828,5824]<0,5824,0>风轻轻 我听见你声音";
        NSArray *cleanKrcLines = [KTLKRCParser parseString:metadataKRC];
        Assert(cleanKrcLines.count == 1, @"KRC title and production credits should be filtered");
        Assert(fabs([cleanKrcLines[0][@"duration"] doubleValue] - 5.824) < 0.001,
               @"KRC line duration should be preserved");
        Assert(fabs([cleanKrcLines[0][@"endTime"] doubleValue] - 22.652) < 0.001,
               @"KRC line end time should be available for instrumental gaps");

        NSArray *allKrcLines = [KTLKRCParser parseKaraokeString:metadataKRC];
        Assert(allKrcLines.count == 4, @"karaoke parsing should retain Kugou title and credit rows");
        Assert([allKrcLines[1][@"text"] isEqual:@"作词：测试"],
               @"live Kugou credit text should remain matchable for karaoke display");
        NSDictionary *metadataPresentation = [KTLKaraokeTimeline
            presentationForLiveText:@"作词：测试"
                               lines:allKrcLines];
        Assert([metadataPresentation[@"metadata"] boolValue],
               @"a matched credit must retain its metadata classification");

        NSArray *observedCreditLines = [KTLKRCParser parseKaraokeString:
            @"[1622,500]<0,500,0>改编词曲：汪苏泷\n"
             "[2622,500]<0,500,0>Child/侯舒扬/金若晨\n"
             "[4639,500]<0,500,0>音乐总监：刘卓@维伴音乐\n"
             "[14689,500]<0,500,0>灯光设计：田为钧/卢晓伟\n"
             "[15689,3000]<0,3000,0>如果上天有旨意"];
        Assert([observedCreditLines[0][@"metadata"] boolValue] &&
               [observedCreditLines[1][@"metadata"] boolValue] &&
               [observedCreditLines[2][@"metadata"] boolValue] &&
               [observedCreditLines[3][@"metadata"] boolValue],
               @"the real credit formats published by Kugou should be classified as metadata");
        Assert(![observedCreditLines[4][@"metadata"] boolValue],
               @"the first real sung line after the credits must remain displayable");

        NSArray *predictionWithCredits = [KTLKRCParser parseKaraokeString:
            @"[0,1000]<0,1000,0>如果上天有旨意\n"
             "[1000,500]<0,500,0>作词：测试\n"
             "[1500,1000]<0,1000,0>我想那一定是你"];
        NSDictionary *predictionAfterCredits = [KTLKaraokeTimeline
            nextPresentationAfterPresentation:predictionWithCredits.firstObject
                                        lines:predictionWithCredits];
        Assert([predictionAfterCredits[@"text"] isEqual:@"我想那一定是你"],
               @"next-lyric prediction must skip author and production credit rows");

        NSArray *matchingLines = [KTLKRCParser parseKaraokeString:
            @"[1000,2400]<0,400,0>我明白<400,600,0>你的回答 <1000,1400,0>温柔的对话"];
        NSDictionary *matched = [KTLKaraokeTimeline presentationForLiveText:@"温柔的对话"
                                                                      lines:matchingLines];
        Assert([matched[@"text"] isEqual:@"温柔的对话"], @"substring matching should keep Kugou's visible text");
        NSArray *matchedSegments = matched[@"segments"];
        Assert(matchedSegments.count == 1, @"substring matching should clip unrelated KRC segments");
        Assert([matchedSegments[0][@"range"] rangeValue].location == 0,
               @"clipped segment range should be relative to visible text");
        Assert([matched[@"sourceIndex"] unsignedIntegerValue] == 0,
               @"a live match should retain its KRC row for next-line prediction");
        NSDictionary *nextFragment = [KTLKaraokeTimeline nextFragmentAfterPresentation:matched
                                                                                  lines:matchingLines];
        Assert(nextFragment == nil, @"a suffix match at the end of a KRC row should have no same-row successor");

        NSDictionary *firstFragment = [KTLKaraokeTimeline presentationForLiveText:@"我明白你的回答"
                                                                            lines:matchingLines];
        NSDictionary *remainingFragment = [KTLKaraokeTimeline nextFragmentAfterPresentation:firstFragment
                                                                                       lines:matchingLines];
        Assert([remainingFragment[@"text"] isEqual:@"温柔的对话"],
               @"a Kugou phrase split inside one KRC row should predict the remaining phrase");
        NSDictionary *followingRow = [KTLKaraokeTimeline nextPresentationAfterPresentation:remainingFragment
                                                                                      lines:@[
            matchingLines.firstObject,
            [KTLKRCParser parseKaraokeString:@"[4000,1000]<0,1000,0>爱情其实没有办法"].firstObject
        ]];
        Assert([followingRow[@"text"] isEqual:@"爱情其实没有办法"],
               @"dual lyric preview should advance to the following KRC row after a row suffix");
        Assert([followingRow[@"sourceIndex"] unsignedIntegerValue] == 1,
               @"following-row preview should preserve its ordered source index");
        NSArray *splitPreviewLines = [KTLKRCParser parseKaraokeString:
            @"[0,1000]<0,1000,0>上一句\n[1000,2000]<0,900,0>我明白你的回答 <900,1100,0>温柔的对话"];
        NSDictionary *splitPreview = [KTLKaraokeTimeline
            nextPresentationAfterPresentation:splitPreviewLines.firstObject
                                        lines:splitPreviewLines];
        Assert([splitPreview[@"text"] isEqual:@"我明白你的回答"],
               @"next-row preview should use only the first whitespace-separated Kugou phrase");

        NSArray *advanceLines = [KTLKRCParser parseKaraokeString:
            @"[0,1000]<0,1000,0>当前句\n[1000,1000]<0,1000,0>下一句"];
        KTLLyricTimeline *advanceTimeline = [[KTLLyricTimeline alloc] initWithLines:advanceLines];
        Assert([[[advanceTimeline lineAtTime:1.05] objectForKey:@"text"] isEqual:@"下一句"],
               @"positive lyric offset should be able to select and pre-enter the next KRC line");
        NSDictionary *offsetNextLine = [KTLKaraokeTimeline
            nextPresentationAfterPresentation:advanceLines.firstObject
                                        lines:advanceLines];
        NSDictionary *offsetNextProgress = [KTLKaraokeTimeline highlightForLine:offsetNextLine
                                                                   relativeTime:0.25];
        Assert([offsetNextProgress[@"completedLength"] unsignedIntegerValue] == 0 &&
               fabs([offsetNextProgress[@"characterFraction"] doubleValue] - 0.75) < 0.001,
               @"an early line transition should immediately begin the next line's blue word progress");

        NSDictionary *progressLine = [KTLKRCParser parseKaraokeString:
            @"[1000,2000]<0,500,0>你<500,1500,0>好"].firstObject;
        NSDictionary *beforeProgress = [KTLKaraokeTimeline highlightForLine:progressLine relativeTime:-0.1];
        Assert([beforeProgress[@"completedLength"] unsignedIntegerValue] == 0 &&
               [beforeProgress[@"characterFraction"] doubleValue] == 0,
               @"karaoke highlight should be empty before the line starts");
        NSDictionary *firstWordProgress = [KTLKaraokeTimeline highlightForLine:progressLine relativeTime:0.25];
        Assert([firstWordProgress[@"completedLength"] unsignedIntegerValue] == 0 &&
               fabs([firstWordProgress[@"characterFraction"] doubleValue] - 0.5) < 0.001,
               @"karaoke highlight should move through the active character");
        NSDictionary *secondWordProgress = [KTLKaraokeTimeline highlightForLine:progressLine relativeTime:1.25];
        Assert([secondWordProgress[@"completedLength"] unsignedIntegerValue] == 1 &&
               fabs([secondWordProgress[@"characterFraction"] doubleValue] - 0.5) < 0.001,
               @"karaoke highlight should preserve completed characters and animate the next one");
        NSDictionary *finishedProgress = [KTLKaraokeTimeline highlightForLine:progressLine relativeTime:3.0];
        Assert([finishedProgress[@"completedLength"] unsignedIntegerValue] == 2,
               @"karaoke highlight should finish the whole lyric after its duration");

        NSArray *adaptiveLines = [KTLKRCParser parseKaraokeString:
            @"[0,2000]<0,1000,0>甲<1000,1000,0>乙\n[2000,1000]<0,1000,0>下一句"];
        NSDictionary *adaptivePhrase = adaptiveLines.firstObject;
        NSDictionary *adaptiveNext = adaptiveLines.lastObject;
        KTLAdaptiveTimingModel *adaptiveTiming = [KTLAdaptiveTimingModel new];
        Assert(fabs([adaptiveTiming scaleForPresentationKey:@"phrase-a"] - 1.0) < 0.001,
               @"an unseen phrase should use the original KRC speed");
        [adaptiveTiming observePresentation:adaptivePhrase key:@"phrase-a" playbackTime:10.0];
        [adaptiveTiming observePresentation:adaptiveNext key:@"phrase-b" playbackTime:13.0];
        Assert(fabs([adaptiveTiming scaleForPresentationKey:@"phrase-a"] - 1.5) < 0.001,
               @"a three-second live phrase should slow a two-second KRC phrase by 1.5x");

        [adaptiveTiming observePresentation:adaptivePhrase key:@"phrase-a" playbackTime:20.0];
        [adaptiveTiming observePresentation:adaptiveNext key:@"phrase-b" playbackTime:22.0];
        Assert(fabs([adaptiveTiming scaleForPresentationKey:@"phrase-a"] - 1.325) < 0.001,
               @"repeat observations should be smoothed instead of making karaoke speed jump");

        KTLAdaptiveTimingModel *blankBoundaryTiming = [KTLAdaptiveTimingModel new];
        [blankBoundaryTiming observePresentation:adaptivePhrase key:@"phrase-a" playbackTime:10.0];
        [blankBoundaryTiming observePresentation:nil key:@"" playbackTime:13.0];
        Assert(fabs([blankBoundaryTiming scaleForPresentationKey:@"phrase-a"] - 1.5) < 0.001,
               @"a real blank interval should still close and measure the preceding phrase");

        KTLAdaptiveTimingModel *outlierTiming = [KTLAdaptiveTimingModel new];
        [outlierTiming observePresentation:adaptivePhrase key:@"phrase-a" playbackTime:10.0];
        [outlierTiming observePresentation:adaptiveNext key:@"phrase-b" playbackTime:14.0];
        Assert(fabs([outlierTiming scaleForPresentationKey:@"phrase-a"] - 1.0) < 0.001,
               @"an implausible live-to-KRC duration ratio should be ignored");

        KTLAdaptiveTimingModel *seekTiming = [KTLAdaptiveTimingModel new];
        [seekTiming observePresentation:adaptivePhrase key:@"phrase-a" playbackTime:10.0];
        [seekTiming cancelPendingMeasurement];
        [seekTiming observePresentation:adaptiveNext key:@"phrase-b" playbackTime:13.0];
        Assert(fabs([seekTiming scaleForPresentationKey:@"phrase-a"] - 1.0) < 0.001,
               @"seeking should cancel the interrupted phrase sample");
        [seekTiming observePresentation:adaptivePhrase key:@"phrase-a" playbackTime:20.0];
        [seekTiming observePresentation:adaptiveNext key:@"phrase-b" playbackTime:23.0];
        Assert(fabs([seekTiming scaleForPresentationKey:@"phrase-a"] - 1.5) < 0.001,
               @"valid observations after a seek should still be learned");
        [seekTiming resetForNewTrack];
        Assert(fabs([seekTiming scaleForPresentationKey:@"phrase-a"] - 1.0) < 0.001,
               @"changing tracks should discard phrase timing learned for the previous song");

        NSLog(@"PASS: all core tests");
    }
    return 0;
}
