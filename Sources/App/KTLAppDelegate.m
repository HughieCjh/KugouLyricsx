#import "KTLAppDelegate.h"
#import "../Media/KTLMediaRemoteClient.h"
#import "../Media/KTLNowPlaying.h"
#import "../Media/KTLMediaRemoteObserver.h"
#import "../Media/KTLKugouAccessibilityPositionProvider.h"
#import "../Lyrics/KTLKugouLocalLyricsProvider.h"
#import "../Lyrics/KTLRemoteLyricsService.h"
#import "../Core/KTLLyricTimeline.h"
#import "../Core/KTLKeepAwakePolicy.h"
#import "../Core/KTLLiveLyricDetector.h"
#import "../Core/KTLKaraokeTimeline.h"
#import "../Core/KTLAdaptiveTimingModel.h"
#import "../Core/KTLPlaybackStateResolver.h"
#import <IOKit/pwr_mgt/IOPMLib.h>

static NSString *const KTLKeepDisplayAwakePreferenceKey = @"KTLKeepDisplayAwakeWhilePlaying";
static NSString *const KTLLyricOffsetPreferenceKey = @"KTLLyricOffset";
static NSString *const KTLShowNextLyricPreferenceKey = @"KTLShowAlternatingNextLyric";

static BOOL KTLApplicationIsKugou(NSRunningApplication *application) {
    NSString *identifier = application.bundleIdentifier.lowercaseString ?: @"";
    return [identifier containsString:@"kugou"] || [identifier containsString:@"kgmusic"];
}

@interface KTLAppDelegate ()
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenuItem *statusMenuItem;
@property(nonatomic, strong) NSMenuItem *keepAwakeMenuItem;
@property(nonatomic, strong) NSMenuItem *showNextLyricMenuItem;
@property(nonatomic, strong) NSMenuItem *accessibilityPositionMenuItem;
@property(nonatomic, strong) NSTextField *lyricOffsetLabel;
@property(nonatomic, strong) NSSlider *lyricOffsetSlider;
@property(nonatomic, strong) KTLTouchBarController *touchBarController;
@property(nonatomic, strong) KTLMediaRemoteClient *mediaClient;
@property(nonatomic, strong) KTLMediaRemoteObserver *mediaObserver;
@property(nonatomic, strong) KTLKugouAccessibilityPositionProvider *accessibilityPositionProvider;
@property(nonatomic, strong) KTLKugouLocalLyricsProvider *localLyricsProvider;
@property(nonatomic, strong) KTLRemoteLyricsService *remoteLyricsService;
@property(nonatomic, strong, nullable) KTLLyricTimeline *timeline;
@property(nonatomic, strong, nullable) KTLLyricTimeline *karaokeTimeline;
@property(nonatomic, strong, nullable) KTLKugouLocalLyricsResult *localLyricsCandidate;
@property(nonatomic, strong) KTLLiveLyricDetector *liveLyricDetector;
@property(nonatomic, strong) KTLAdaptiveTimingModel *adaptiveTimingModel;
@property(nonatomic, strong) KTLPlaybackStateResolver *playbackStateResolver;
@property(nonatomic, strong, nullable) KTLNowPlaying *nowPlaying;
@property(nonatomic, strong, nullable) NSDictionary<NSString *, id> *karaokePresentation;
@property(nonatomic, copy) NSString *lastLiveLyricText;
@property(nonatomic, assign) NSTimeInterval liveLyricAnchorElapsed;
@property(nonatomic, copy, nullable) NSString *liveTextOverride;
@property(nonatomic, assign) BOOL hasShownRealLiveLyric;
@property(nonatomic, assign) BOOL reconcileLiveAnchorFromTimeline;
@property(nonatomic, strong) NSDate *snapshotDate;
@property(nonatomic, copy) NSString *activeTrackKey;
@property(nonatomic, copy) NSString *fetchingTrackKey;
@property(nonatomic, assign) NSTimeInterval lyricOffset;
@property(nonatomic, assign) BOOL showNextLyric;
@property(nonatomic, copy) NSString *dualActivePresentationKey;
@property(nonatomic, assign) BOOL dualCurrentOnLeft;
@property(nonatomic, copy) NSString *lastRenderedPresentationKey;
@property(nonatomic, assign) NSTimeInterval lastRenderedRelativeTime;
@property(nonatomic, strong) NSTimer *displayTimer;
@property(nonatomic) dispatch_source_t pollingTimer;
@property(nonatomic) dispatch_queue_t pollingQueue;
@property(nonatomic, assign) BOOL keepDisplayAwakeWhilePlaying;
@property(nonatomic, assign) BOOL hasDisplaySleepAssertion;
@property(nonatomic, assign) BOOL displaySleepAssertionFailed;
@property(nonatomic, assign) IOPMAssertionID displaySleepAssertionID;
@property(nonatomic, assign) BOOL kugouIsFrontmost;
@end

@implementation KTLAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    NSApplication.sharedApplication.activationPolicy = NSApplicationActivationPolicyAccessory;
    self.activeTrackKey = @"";
    self.fetchingTrackKey = @"";
    self.snapshotDate = NSDate.date;
    self.lastLiveLyricText = @"";
    self.dualActivePresentationKey = @"";
    self.lastRenderedPresentationKey = @"";
    self.dualCurrentOnLeft = YES;
    self.liveLyricDetector = [KTLLiveLyricDetector new];
    self.adaptiveTimingModel = [KTLAdaptiveTimingModel new];
    self.playbackStateResolver = [KTLPlaybackStateResolver new];
    self.kugouIsFrontmost = KTLApplicationIsKugou(
        NSWorkspace.sharedWorkspace.frontmostApplication);
    self.keepDisplayAwakeWhilePlaying = [NSUserDefaults.standardUserDefaults
        boolForKey:KTLKeepDisplayAwakePreferenceKey];
    self.lyricOffset = MIN(3.0, MAX(-3.0, [NSUserDefaults.standardUserDefaults
        doubleForKey:KTLLyricOffsetPreferenceKey]));
    self.showNextLyric = [NSUserDefaults.standardUserDefaults
        boolForKey:KTLShowNextLyricPreferenceKey];
    self.displaySleepAssertionID = kIOPMNullAssertionID;

    NSURL *resources = NSBundle.mainBundle.resourceURL;
    self.mediaClient = [[KTLMediaRemoteClient alloc] initWithResourcesDirectory:resources];
    self.accessibilityPositionProvider = [KTLKugouAccessibilityPositionProvider new];
    __weak typeof(self) weakSelf = self;
    self.mediaObserver = [[KTLMediaRemoteObserver alloc]
        initWithResourcesDirectory:resources
                           handler:^(KTLNowPlaying *state) {
        if (state.isKugou) [weakSelf applyObservedSnapshot:state];
    }];
    NSString *lyricsPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Containers/com.kugou.mac.Music/Data/Documents/Caches/kgLyric"];
    self.localLyricsProvider = [[KTLKugouLocalLyricsProvider alloc]
        initWithLyricsDirectory:[NSURL fileURLWithPath:lyricsPath]];
    self.remoteLyricsService = [KTLRemoteLyricsService new];

    self.touchBarController = [KTLTouchBarController new];
    self.touchBarController.delegate = self;
    [self configureStatusMenu];
    [self.touchBarController show];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self
                                                        selector:@selector(frontmostApplicationDidChange:)
                                                            name:NSWorkspaceDidActivateApplicationNotification
                                                          object:nil];
    [self startPolling];
    [self.mediaObserver start];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (![self.accessibilityPositionProvider isAuthorized]) {
            [self.accessibilityPositionProvider requestAuthorization];
            [self updateAccessibilityPositionMenuItem];
        }
    });
}

- (void)configureStatusMenu {
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"♪";
    self.statusItem.button.toolTip = @"KugouLyricsx";

    NSMenu *menu = [NSMenu new];
    self.statusMenuItem = [[NSMenuItem alloc] initWithTitle:@"等待酷狗播放" action:nil keyEquivalent:@""];
    self.statusMenuItem.enabled = NO;
    [menu addItem:self.statusMenuItem];
    [menu addItem:NSMenuItem.separatorItem];
    [menu addItemWithTitle:@"显示 Touch Bar" action:@selector(showTouchBar:) keyEquivalent:@""];
    self.showNextLyricMenuItem = [[NSMenuItem alloc]
        initWithTitle:@"左右双句歌词"
               action:@selector(toggleShowNextLyric:)
        keyEquivalent:@""];
    self.showNextLyricMenuItem.state = self.showNextLyric
        ? NSControlStateValueOn
        : NSControlStateValueOff;
    [menu addItem:self.showNextLyricMenuItem];
    self.accessibilityPositionMenuItem = [[NSMenuItem alloc]
        initWithTitle:@"酷狗进度同步：检查授权中"
               action:@selector(requestAccessibilityPositionAuthorization:)
        keyEquivalent:@""];
    self.accessibilityPositionMenuItem.target = self;
    [menu addItem:self.accessibilityPositionMenuItem];
    [self updateAccessibilityPositionMenuItem];
    self.keepAwakeMenuItem = [[NSMenuItem alloc]
        initWithTitle:@"播放时保持主屏幕常亮"
               action:@selector(toggleKeepAwake:)
        keyEquivalent:@""];
    self.keepAwakeMenuItem.state = self.keepDisplayAwakeWhilePlaying
        ? NSControlStateValueOn
        : NSControlStateValueOff;
    [menu addItem:self.keepAwakeMenuItem];

    NSView *offsetView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 270, 58)];
    self.lyricOffsetLabel = [NSTextField labelWithString:@""];
    self.lyricOffsetLabel.frame = NSMakeRect(12, 34, 246, 18);
    self.lyricOffsetLabel.alignment = NSTextAlignmentCenter;
    self.lyricOffsetLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    [offsetView addSubview:self.lyricOffsetLabel];
    NSTextField *laterLabel = [NSTextField labelWithString:@"延后"];
    laterLabel.frame = NSMakeRect(12, 9, 38, 18);
    laterLabel.font = [NSFont systemFontOfSize:10];
    [offsetView addSubview:laterLabel];
    NSTextField *earlierLabel = [NSTextField labelWithString:@"提前"];
    earlierLabel.frame = NSMakeRect(222, 9, 38, 18);
    earlierLabel.alignment = NSTextAlignmentRight;
    earlierLabel.font = [NSFont systemFontOfSize:10];
    [offsetView addSubview:earlierLabel];
    self.lyricOffsetSlider = [NSSlider sliderWithValue:self.lyricOffset
                                              minValue:-3.0
                                              maxValue:3.0
                                                target:self
                                                action:@selector(lyricOffsetSliderChanged:)];
    self.lyricOffsetSlider.frame = NSMakeRect(50, 7, 172, 20);
    self.lyricOffsetSlider.continuous = YES;
    self.lyricOffsetSlider.numberOfTickMarks = 25;
    self.lyricOffsetSlider.allowsTickMarkValuesOnly = NO;
    [offsetView addSubview:self.lyricOffsetSlider];
    NSMenuItem *offsetItem = [NSMenuItem new];
    offsetItem.view = offsetView;
    [menu addItem:offsetItem];
    [menu addItemWithTitle:@"歌词提前 0.25 秒" action:@selector(lyricsEarlier:) keyEquivalent:@""];
    [menu addItemWithTitle:@"歌词延后 0.25 秒" action:@selector(lyricsLater:) keyEquivalent:@""];
    [menu addItemWithTitle:@"重置歌词偏移" action:@selector(resetOffset:) keyEquivalent:@""];
    [menu addItem:NSMenuItem.separatorItem];
    [menu addItemWithTitle:@"退出" action:@selector(quit:) keyEquivalent:@"q"];
    for (NSMenuItem *item in menu.itemArray) if (item.action) item.target = self;
    self.statusItem.menu = menu;
    [self updateLyricOffsetControls];
}

- (void)startPolling {
    self.pollingQueue = dispatch_queue_create("com.hughie.KugouLyricsx.polling", DISPATCH_QUEUE_SERIAL);
    self.pollingTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.pollingQueue);
    dispatch_source_set_timer(self.pollingTimer, DISPATCH_TIME_NOW, NSEC_PER_SEC, NSEC_PER_MSEC * 100);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.pollingTimer, ^{
        typeof(self) self = weakSelf;
        if (!self) return;
        NSError *error = nil;
        KTLNowPlaying *state = [self.mediaClient snapshotWithError:&error];
        NSNumber *accessibilityElapsed = self.kugouIsFrontmost
            ? [self.accessibilityPositionProvider
                currentElapsedTimeForExpectedDuration:state.duration]
            : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateAccessibilityPositionMenuItem];
            if (state.isKugou) {
                [self applyAccessibilityElapsed:accessibilityElapsed toSnapshot:state];
                [self applySnapshot:state];
            }
            else if (!state || !state.isKugou) [self applyIdleState:error];
        });
    });
    dispatch_resume(self.pollingTimer);

    self.displayTimer = [NSTimer timerWithTimeInterval:(1.0 / 30.0)
                                                target:self
                                              selector:@selector(updateDisplayedLyric:)
                                              userInfo:nil
                                               repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.displayTimer forMode:NSRunLoopCommonModes];
}

- (void)applyAccessibilityElapsed:(NSNumber *)accessibilityElapsed
                       toSnapshot:(KTLNowPlaying *)state {
    if (!self.kugouIsFrontmost || !accessibilityElapsed || !state.isKugou) return;
    NSTimeInterval elapsed = accessibilityElapsed.doubleValue;
    if (!self.nowPlaying || ![self.activeTrackKey isEqual:[self trackKeyForState:state]]) {
        [state applyConfirmedElapsed:elapsed];
        return;
    }

    NSTimeInterval estimatedElapsed = [self estimatedElapsed];
    NSTimeInterval resolvedElapsed = [KTLKugouAccessibilityPositionProvider
        shouldAdoptElapsed:elapsed estimatedElapsed:estimatedElapsed]
        ? elapsed
        : estimatedElapsed;
    [state applyConfirmedElapsed:resolvedElapsed];
}

- (void)updateAccessibilityPositionMenuItem {
    if (!self.accessibilityPositionMenuItem) return;
    BOOL authorized = self.accessibilityPositionProvider.isAuthorized;
    self.accessibilityPositionMenuItem.title = authorized
        ? @"酷狗进度同步：已启用"
        : @"酷狗进度同步：点击授权辅助功能";
    self.accessibilityPositionMenuItem.state = authorized
        ? NSControlStateValueOn
        : NSControlStateValueOff;
}

- (void)requestAccessibilityPositionAuthorization:(id)sender {
    (void)sender;
    BOOL authorized = [self.accessibilityPositionProvider requestAuthorization];
    [self updateAccessibilityPositionMenuItem];
    if (authorized) return;
    NSURL *settingsURL = [NSURL URLWithString:
        @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    if (settingsURL) [NSWorkspace.sharedWorkspace openURL:settingsURL];
}

- (void)applySnapshot:(KTLNowPlaying *)state {
    NSString *trackKey = [self trackKeyForState:state];
    BOOL trackChanged = ![self.activeTrackKey isEqual:trackKey];
    NSTimeInterval previousElapsed = [self estimatedElapsed];
    BOOL seeked = !trackChanged && self.nowPlaying && state.hasElapsed &&
        fabs(state.elapsed - previousElapsed) > 1.25;
    if (trackChanged || seeked) [self.playbackStateResolver reset];
    state.reportedPlaying = [self.playbackStateResolver
        resolvedPlayingForReportedPlaying:state.reportedPlaying
                                    elapsed:state.elapsed];
    self.nowPlaying = state;
    self.snapshotDate = NSDate.date;
    if (trackChanged) {
        [self.adaptiveTimingModel resetForNewTrack];
        self.liveTextOverride = nil;
        self.hasShownRealLiveLyric = NO;
        self.reconcileLiveAnchorFromTimeline = YES;
        [self resetDualLyricState];
        self.activeTrackKey = trackKey;
        self.fetchingTrackKey = @"";
        self.timeline = nil;
        self.karaokeTimeline = nil;
        self.karaokePresentation = nil;
        self.lastLiveLyricText = @"";
        NSError *error = nil;
        self.localLyricsCandidate = [self.localLyricsProvider lyricsForTitle:state.title
                                                                    duration:state.duration
                                                                       error:&error];
        if (self.localLyricsCandidate.karaokeLines.count > 0) {
            self.karaokeTimeline = [[KTLLyricTimeline alloc]
                initWithLines:self.localLyricsCandidate.karaokeLines];
        }
        [self.liveLyricDetector resetWithKnownLines:self.localLyricsCandidate.karaokeLines ?: @[]];
        [self.liveLyricDetector observeMediaText:state.artist ?: @""];
        [self updateKaraokePresentationIfNeeded];

        if (self.liveLyricDetector.isActive) {
            self.statusMenuItem.title = [NSString stringWithFormat:@"%@（酷狗实时歌词）", state.title];
        } else if (self.localLyricsCandidate.timingCompatible) {
            self.timeline = [[KTLLyricTimeline alloc] initWithLines:self.localLyricsCandidate.lines];
            self.statusMenuItem.title = [NSString stringWithFormat:@"%@ — %@",
                                         self.localLyricsCandidate.artist,
                                         state.title];
        } else {
            NSString *reason = self.localLyricsCandidate
                ? @"本地歌词版本不匹配，正在重新查找"
                : @"等待歌词";
            self.statusMenuItem.title = [NSString stringWithFormat:@"%@（%@）", state.title, reason];
            [self beginRemoteLyricsFetchForState:state];
        }
    } else {
        if (seeked) {
            [self.adaptiveTimingModel cancelPendingMeasurement];
            self.liveTextOverride = nil;
            if (state.elapsed < 20.0) self.hasShownRealLiveLyric = NO;
            self.reconcileLiveAnchorFromTimeline = YES;
            self.lastLiveLyricText = @"";
            [self resetDualLyricState];
        }
        BOOL wasActive = self.liveLyricDetector.isActive;
        [self.liveLyricDetector observeMediaText:state.artist ?: @""];
        [self updateKaraokePresentationIfNeeded];
        if (!wasActive && self.liveLyricDetector.isActive) {
            self.statusMenuItem.title = [NSString stringWithFormat:@"%@（酷狗实时歌词）", state.title];
        }
    }
    [self updateDisplayedLyric:nil];
    [self synchronizeDisplaySleepAssertion];
    if (trackChanged || seeked) [self restoreTouchBarAfterTrackChange];
}

- (void)applyObservedSnapshot:(KTLNowPlaying *)state {
    if (self.kugouIsFrontmost && self.nowPlaying) {
        state = [KTLNowPlaying foregroundSafeObservedState:state
                                              currentState:self.nowPlaying
                                          estimatedElapsed:[self estimatedElapsed]];
    }
    if (state) [self applySnapshot:state];
}

- (NSString *)trackKeyForState:(KTLNowPlaying *)state {
    return [NSString stringWithFormat:@"%@|%.1f", state.title, state.duration];
}

- (void)restoreTouchBarAfterTrackChange {
    if (self.kugouIsFrontmost) {
        [self.touchBarController refresh];
        return;
    }
    [self.touchBarController showAndRefresh];
    __weak typeof(self) weakSelf = self;
    for (NSNumber *delay in @[@0.35, @0.9, @1.8]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [weakSelf.touchBarController showAndRefresh];
        });
    }
}

- (void)frontmostApplicationDidChange:(NSNotification *)notification {
    NSRunningApplication *activatedApplication = notification.userInfo[NSWorkspaceApplicationKey];
    BOOL wasKugouFrontmost = self.kugouIsFrontmost;
    self.kugouIsFrontmost = KTLApplicationIsKugou(activatedApplication);
    if (!self.nowPlaying.isKugou) return;
    if (self.kugouIsFrontmost) {
        [self updateDisplayedLyric:nil];
        return;
    }
    if (wasKugouFrontmost) {
        self.reconcileLiveAnchorFromTimeline = YES;
        self.lastLiveLyricText = @"";
    }
    [self restoreTouchBarAfterTrackChange];
}

- (void)beginRemoteLyricsFetchForState:(KTLNowPlaying *)state {
    NSString *requestedTrackKey = [self trackKeyForState:state];
    if ([self.fetchingTrackKey isEqual:requestedTrackKey]) return;
    self.fetchingTrackKey = requestedTrackKey;
    __weak typeof(self) weakSelf = self;
    [self.remoteLyricsService fetchLyricsForTitle:state.title duration:state.duration completion:^(KTLRemoteLyricsResult *result) {
        typeof(self) self = weakSelf;
        if (!self || ![self.activeTrackKey isEqual:requestedTrackKey]) return;
        self.fetchingTrackKey = @"";
        if (!result || self.liveLyricDetector.isActive) return;
        self.timeline = [[KTLLyricTimeline alloc] initWithLines:result.lines];
        self.statusMenuItem.title = [NSString stringWithFormat:@"%@ — %@（%@）",
                                     result.artist.length ? result.artist : @"未知歌手",
                                     state.title,
                                     result.sourceName];
    }];
}

- (void)applyIdleState:(NSError *)error {
    self.nowPlaying = nil;
    self.timeline = nil;
    self.karaokeTimeline = nil;
    self.localLyricsCandidate = nil;
    self.karaokePresentation = nil;
    self.lastLiveLyricText = @"";
    self.liveTextOverride = nil;
    self.hasShownRealLiveLyric = NO;
    self.reconcileLiveAnchorFromTimeline = NO;
    [self resetDualLyricState];
    self.activeTrackKey = @"";
    self.fetchingTrackKey = @"";
    [self.liveLyricDetector resetWithKnownLines:@[]];
    [self.adaptiveTimingModel resetForNewTrack];
    [self.playbackStateResolver reset];
    NSString *message = error ? @"无法读取酷狗播放状态" : @"等待酷狗播放";
    self.statusMenuItem.title = message;
    [self.touchBarController updateLyric:message playing:NO];
    [self synchronizeDisplaySleepAssertion];
}

- (void)updateDisplayedLyric:(NSTimer *)timer {
    (void)timer;
    if (!self.nowPlaying) return;
    NSTimeInterval elapsed = self.nowPlaying.elapsed;
    if (self.nowPlaying.isPlaying) elapsed += -self.snapshotDate.timeIntervalSinceNow;
    NSString *text = nil;
    NSDictionary<NSString *, id> *highlight = nil;
    NSDictionary<NSString *, id> *currentPresentation = nil;
    NSTimeInterval renderedRelativeTime = 0;
    BOOL hasRenderedRelativeTime = NO;
    BOOL useForegroundTimeline = self.kugouIsFrontmost &&
        self.localLyricsCandidate.timingCompatible && self.karaokeTimeline != nil;
    if (useForegroundTimeline) {
        NSTimeInterval playbackTime = elapsed + self.lyricOffset;
        NSDictionary *line = [self.karaokeTimeline lineAtTime:playbackTime];
        BOOL metadata = [line[@"metadata"] boolValue];
        if (!line || (metadata && self.hasShownRealLiveLyric)) {
            line = [self.karaokeTimeline nextLineAfterTime:playbackTime
                                          excludingMetadata:YES];
            metadata = NO;
        }
        if (metadata) {
            text = self.hasShownRealLiveLyric ? @"" : line[@"text"] ?: @"";
        } else if (line) {
            NSString *lineText = [line[@"text"] isKindOfClass:NSString.class]
                ? line[@"text"]
                : @"";
            NSUInteger sourceIndex = [self.localLyricsCandidate.karaokeLines
                indexOfObjectIdenticalTo:line];
            if (sourceIndex == NSNotFound) {
                sourceIndex = [self.localLyricsCandidate.karaokeLines indexOfObject:line];
            }
            NSMutableDictionary *presentation = [line mutableCopy];
            if (sourceIndex != NSNotFound) presentation[@"sourceIndex"] = @(sourceIndex);
            if (!presentation[@"sourceRange"]) {
                presentation[@"sourceRange"] = [NSValue valueWithRange:NSMakeRange(0, lineText.length)];
            }
            text = lineText;
            currentPresentation = presentation;
            renderedRelativeTime = playbackTime - [line[@"time"] doubleValue];
            hasRenderedRelativeTime = YES;
            highlight = [KTLKaraokeTimeline highlightForLine:presentation
                                                 relativeTime:renderedRelativeTime];
            if (lineText.length > 0) self.hasShownRealLiveLyric = YES;
        } else {
            text = @"";
        }
    } else if (self.liveLyricDetector.isActive) {
        text = self.liveTextOverride ?: self.liveLyricDetector.currentLyric;
        [self updateKaraokePresentationIfNeeded];
        text = self.liveTextOverride ?: self.liveLyricDetector.currentLyric;
        if (self.karaokePresentation) {
            NSDictionary *displayLine = self.karaokePresentation;
            NSArray *segments = self.karaokePresentation[@"segments"];
            NSTimeInterval firstOffset = segments.count > 0 ? [segments[0][@"offset"] doubleValue] : 0;
            NSString *presentationKey = [self presentationKey:self.karaokePresentation
                                                 fallbackText:text ?: @""];
            double scale = [self.adaptiveTimingModel scaleForPresentationKey:presentationKey];
            NSTimeInterval relativeTime = firstOffset +
                (elapsed - self.liveLyricAnchorElapsed + self.lyricOffset) / scale;

            if (displayLine == self.karaokePresentation) {
                NSArray *baseSegments = self.karaokePresentation[@"segments"];
                NSDictionary *lastSegment = baseSegments.lastObject;
                NSTimeInterval fragmentEnd = [lastSegment[@"offset"] doubleValue] +
                    [lastSegment[@"duration"] doubleValue];
                if (lastSegment && relativeTime >= fragmentEnd) {
                    NSArray *karaokeLines = self.localLyricsCandidate.karaokeLines ?: @[];
                    NSDictionary *nextLine = [KTLKaraokeTimeline
                        nextFragmentAfterPresentation:self.karaokePresentation
                                                lines:karaokeLines];
                    if (!nextLine && self.lyricOffset > 0.001) {
                        nextLine = [KTLKaraokeTimeline
                            nextPresentationAfterPresentation:self.karaokePresentation
                                                        lines:karaokeLines];
                    }
                    if (nextLine) {
                        BOOL sameSourceRow = [nextLine[@"sourceIndex"] isEqual:self.karaokePresentation[@"sourceIndex"]];
                        if (!sameSourceRow) {
                            NSString *currentKey = [self presentationKey:self.karaokePresentation
                                                           fallbackText:self.karaokePresentation[@"text"] ?: @""];
                            double currentScale = [self.adaptiveTimingModel
                                scaleForPresentationKey:currentKey];
                            NSArray *nextSegments = nextLine[@"segments"];
                            NSTimeInterval nextFirstOffset = nextSegments.count > 0
                                ? [nextSegments[0][@"offset"] doubleValue]
                                : 0;
                            NSString *nextKey = [self presentationKey:nextLine
                                                        fallbackText:nextLine[@"text"] ?: @""];
                            double nextScale = [self.adaptiveTimingModel
                                scaleForPresentationKey:nextKey];
                            NSTimeInterval realOverflow = MAX(0, relativeTime - fragmentEnd) * currentScale;
                            relativeTime = nextFirstOffset + realOverflow / nextScale;
                        }
                        displayLine = nextLine;
                    }
                }
            }
            text = displayLine[@"text"] ?: text;
            highlight = [KTLKaraokeTimeline highlightForLine:displayLine relativeTime:relativeTime];
            currentPresentation = displayLine;
            renderedRelativeTime = relativeTime;
            hasRenderedRelativeTime = YES;
        } else if (self.liveTextOverride != nil) {
            highlight = @{ @"completedLength": @0, @"characterFraction": @0 };
        }
    } else if (self.timeline) {
        NSDictionary *line = [self.timeline lineAtTime:elapsed + self.lyricOffset];
        text = line[@"text"] ?: @"";
        if (line) {
            currentPresentation = line;
            highlight = [KTLKaraokeTimeline highlightForLine:line
                                                 relativeTime:elapsed + self.lyricOffset - [line[@"time"] doubleValue]];
            renderedRelativeTime = elapsed + self.lyricOffset - [line[@"time"] doubleValue];
            hasRenderedRelativeTime = YES;
        }
    } else {
        text = self.nowPlaying.title;
    }
    if (currentPresentation && hasRenderedRelativeTime) {
        self.lastRenderedPresentationKey = [self presentationKey:currentPresentation fallbackText:text ?: @""];
        self.lastRenderedRelativeTime = renderedRelativeTime;
    } else {
        self.lastRenderedPresentationKey = @"";
        self.lastRenderedRelativeTime = 0;
    }
    if (self.showNextLyric) {
        NSDictionary *nextPresentation = currentPresentation[@"sourceIndex"]
            ? [KTLKaraokeTimeline nextPresentationAfterPresentation:currentPresentation
                                                               lines:self.localLyricsCandidate.karaokeLines ?: @[]]
            : nil;
        NSString *nextText = [nextPresentation[@"text"] isKindOfClass:NSString.class]
            ? nextPresentation[@"text"]
            : @"";
        NSString *presentationKey = [self presentationKey:currentPresentation fallbackText:text ?: @""];
        [self updateDualSideForPresentationKey:presentationKey];
        NSUInteger completedLength = highlight
            ? [highlight[@"completedLength"] unsignedIntegerValue]
            : text.length;
        CGFloat characterFraction = highlight
            ? [highlight[@"characterFraction"] doubleValue]
            : 0;
        [self.touchBarController updateLyric:text ?: @""
                                    nextLyric:nextText
                              completedLength:completedLength
                             characterFraction:characterFraction
                                    dualLine:YES
                               currentOnLeft:self.dualCurrentOnLeft
                                       playing:self.nowPlaying.isPlaying];
    } else if (highlight) {
        [self.touchBarController updateLyric:text
                             completedLength:[highlight[@"completedLength"] unsignedIntegerValue]
                            characterFraction:[highlight[@"characterFraction"] doubleValue]
                                      playing:self.nowPlaying.isPlaying];
    } else {
        [self.touchBarController updateLyric:text playing:self.nowPlaying.isPlaying];
    }
}

- (NSString *)presentationKey:(NSDictionary<NSString *, id> *)presentation
                  fallbackText:(NSString *)fallbackText {
    if (!presentation) return fallbackText ?: @"";
    NSString *text = [presentation[@"text"] isKindOfClass:NSString.class]
        ? presentation[@"text"]
        : fallbackText ?: @"";
    NSNumber *sourceIndex = presentation[@"sourceIndex"];
    NSValue *sourceRangeValue = presentation[@"sourceRange"];
    if (sourceRangeValue) {
        NSRange range = sourceRangeValue.rangeValue;
        return [NSString stringWithFormat:@"%@:%lu:%lu:%@", sourceIndex ?: @(-1),
                                          (unsigned long)range.location,
                                          (unsigned long)range.length,
                                          text];
    }
    return [NSString stringWithFormat:@"%@:%@", sourceIndex ?: @(-1), text];
}

- (void)updateDualSideForPresentationKey:(NSString *)presentationKey {
    if (presentationKey.length == 0 || [presentationKey isEqualToString:self.dualActivePresentationKey]) return;
    if (self.dualActivePresentationKey.length > 0) self.dualCurrentOnLeft = !self.dualCurrentOnLeft;
    self.dualActivePresentationKey = presentationKey;
}

- (void)resetDualLyricState {
    self.dualActivePresentationKey = @"";
    self.dualCurrentOnLeft = YES;
    self.lastRenderedPresentationKey = @"";
    self.lastRenderedRelativeTime = 0;
}

- (void)updateKaraokePresentationIfNeeded {
    if (!self.liveLyricDetector.isActive) return;
    NSString *liveText = self.liveLyricDetector.currentLyric ?: @"";
    if ([liveText isEqualToString:self.lastLiveLyricText]) return;
    self.lastLiveLyricText = liveText;
    NSDictionary *matchedPresentation = [KTLKaraokeTimeline presentationForLiveText:liveText
                                                                                lines:self.localLyricsCandidate.karaokeLines ?: @[]];
    NSString *resolvedArtist = [self.localLyricsCandidate.artist
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    BOOL matchesResolvedArtist = liveText.length > 0 && resolvedArtist.length > 0 &&
        [liveText compare:resolvedArtist options:NSCaseInsensitiveSearch] == NSOrderedSame;
    BOOL isMetadata = [matchedPresentation[@"metadata"] boolValue] || matchesResolvedArtist;
    if (isMetadata) {
        self.liveTextOverride = self.hasShownRealLiveLyric ? @"" : liveText;
    } else {
        self.liveTextOverride = nil;
        if (liveText.length > 0) self.hasShownRealLiveLyric = YES;
    }
    NSDictionary *newPresentation = isMetadata ? nil : matchedPresentation;
    NSTimeInterval estimatedElapsed = [self estimatedElapsed];
    NSString *newKey = [self presentationKey:newPresentation fallbackText:liveText];
    BOOL reconcilingAfterTrackChangeOrSeek = self.reconcileLiveAnchorFromTimeline;
    if (reconcilingAfterTrackChangeOrSeek) {
        [self.adaptiveTimingModel cancelPendingMeasurement];
    } else {
        [self.adaptiveTimingModel observePresentation:newPresentation
                                                  key:newKey
                                         playbackTime:estimatedElapsed];
    }
    BOOL continuesPredictedPhrase = newPresentation &&
        [newKey isEqualToString:self.lastRenderedPresentationKey];
    if (continuesPredictedPhrase) {
        NSArray *segments = newPresentation[@"segments"];
        NSTimeInterval firstOffset = segments.count > 0 ? [segments[0][@"offset"] doubleValue] : 0;
        double scale = [self.adaptiveTimingModel scaleForPresentationKey:newKey];
        self.liveLyricAnchorElapsed = estimatedElapsed + self.lyricOffset -
            (self.lastRenderedRelativeTime - firstOffset) * scale;
    } else if (reconcilingAfterTrackChangeOrSeek &&
               self.localLyricsCandidate.timingCompatible && newPresentation) {
        NSArray *segments = newPresentation[@"segments"];
        NSTimeInterval firstOffset = segments.count > 0 ? [segments[0][@"offset"] doubleValue] : 0;
        self.liveLyricAnchorElapsed = [newPresentation[@"time"] doubleValue] + firstOffset;
    } else {
        self.liveLyricAnchorElapsed = estimatedElapsed;
    }
    self.reconcileLiveAnchorFromTimeline = NO;
    self.karaokePresentation = newPresentation;
}

- (NSTimeInterval)estimatedElapsed {
    if (!self.nowPlaying) return 0;
    NSTimeInterval elapsed = self.nowPlaying.elapsed;
    if (self.nowPlaying.isPlaying) elapsed += -self.snapshotDate.timeIntervalSinceNow;
    return elapsed;
}

- (void)sendCommand:(KTLMediaCommand)command {
    if (command == KTLMediaCommandTogglePlayPause && self.nowPlaying) {
        NSTimeInterval elapsed = [self estimatedElapsed];
        BOOL resuming = !self.nowPlaying.isPlaying;
        if (resuming) {
            [self.playbackStateResolver noteUserRequestedResume];
        } else {
            [self.playbackStateResolver resolvedPlayingForReportedPlaying:NO elapsed:elapsed];
        }
        self.nowPlaying.elapsed = elapsed;
        self.nowPlaying.reportedPlaying = resuming;
        self.snapshotDate = NSDate.date;
        [self updateDisplayedLyric:nil];
    }
    dispatch_async(self.pollingQueue, ^{ [self.mediaClient sendCommand:command error:nil]; });
    [self restoreTouchBarAfterTrackChange];
}

- (void)touchBarDidRequestPrevious { [self sendCommand:KTLMediaCommandPrevious]; }
- (void)touchBarDidRequestTogglePlayback { [self sendCommand:KTLMediaCommandTogglePlayPause]; }
- (void)touchBarDidRequestNext { [self sendCommand:KTLMediaCommandNext]; }

- (void)showTouchBar:(id)sender { (void)sender; [self.touchBarController show]; }
- (void)toggleShowNextLyric:(id)sender {
    (void)sender;
    self.showNextLyric = !self.showNextLyric;
    [NSUserDefaults.standardUserDefaults setBool:self.showNextLyric
                                          forKey:KTLShowNextLyricPreferenceKey];
    self.showNextLyricMenuItem.state = self.showNextLyric
        ? NSControlStateValueOn
        : NSControlStateValueOff;
    [self resetDualLyricState];
    [self updateDisplayedLyric:nil];
    [self.touchBarController show];
}

- (void)toggleKeepAwake:(id)sender {
    (void)sender;
    self.keepDisplayAwakeWhilePlaying = !self.keepDisplayAwakeWhilePlaying;
    [NSUserDefaults.standardUserDefaults setBool:self.keepDisplayAwakeWhilePlaying
                                          forKey:KTLKeepDisplayAwakePreferenceKey];
    self.keepAwakeMenuItem.state = self.keepDisplayAwakeWhilePlaying
        ? NSControlStateValueOn
        : NSControlStateValueOff;
    self.displaySleepAssertionFailed = NO;
    [self synchronizeDisplaySleepAssertion];
    if (self.keepDisplayAwakeWhilePlaying) [self.touchBarController show];
}

- (void)synchronizeDisplaySleepAssertion {
    BOOL shouldPreventSleep = [KTLKeepAwakePolicy
        shouldPreventDisplaySleepWithPreferenceEnabled:self.keepDisplayAwakeWhilePlaying
                                               isKugou:self.nowPlaying.isKugou
                                              isPlaying:self.nowPlaying.isPlaying];
    self.keepAwakeMenuItem.title = @"播放时保持主屏幕常亮";
    if (shouldPreventSleep == self.hasDisplaySleepAssertion) return;

    if (!shouldPreventSleep) {
        [self releaseDisplaySleepAssertion];
        self.displaySleepAssertionFailed = NO;
        return;
    }
    if (self.displaySleepAssertionFailed) {
        self.keepAwakeMenuItem.title = @"播放时保持主屏幕常亮（不可用）";
        return;
    }

    IOPMAssertionID assertionID = kIOPMNullAssertionID;
    IOReturn result = IOPMAssertionCreateWithName(
        kIOPMAssertionTypePreventUserIdleDisplaySleep,
        kIOPMAssertionLevelOn,
        CFSTR("Displaying Kugou lyrics on the Touch Bar"),
        &assertionID);
    if (result == kIOReturnSuccess) {
        self.displaySleepAssertionID = assertionID;
        self.hasDisplaySleepAssertion = YES;
    } else {
        self.displaySleepAssertionFailed = YES;
        self.keepAwakeMenuItem.title = @"播放时保持主屏幕常亮（不可用）";
    }
}

- (void)releaseDisplaySleepAssertion {
    if (!self.hasDisplaySleepAssertion) return;
    IOPMAssertionRelease(self.displaySleepAssertionID);
    self.displaySleepAssertionID = kIOPMNullAssertionID;
    self.hasDisplaySleepAssertion = NO;
}

- (void)setLyricOffsetAndRefresh:(NSTimeInterval)offset {
    self.lyricOffset = MIN(3.0, MAX(-3.0, offset));
    [NSUserDefaults.standardUserDefaults setDouble:self.lyricOffset forKey:KTLLyricOffsetPreferenceKey];
    [self updateLyricOffsetControls];
    [self updateDisplayedLyric:nil];
}

- (void)updateLyricOffsetControls {
    self.lyricOffsetSlider.doubleValue = self.lyricOffset;
    if (fabs(self.lyricOffset) < 0.025) {
        self.lyricOffsetLabel.stringValue = @"歌词同步：当前（0.00 秒）";
    } else if (self.lyricOffset > 0) {
        self.lyricOffsetLabel.stringValue = [NSString stringWithFormat:@"歌词同步：提前 %.2f 秒", self.lyricOffset];
    } else {
        self.lyricOffsetLabel.stringValue = [NSString stringWithFormat:@"歌词同步：延后 %.2f 秒", -self.lyricOffset];
    }
}

- (void)lyricOffsetSliderChanged:(NSSlider *)sender {
    NSTimeInterval rounded = round(sender.doubleValue * 20.0) / 20.0;
    [self setLyricOffsetAndRefresh:rounded];
}

- (void)lyricsEarlier:(id)sender { (void)sender; [self setLyricOffsetAndRefresh:self.lyricOffset + 0.25]; }
- (void)lyricsLater:(id)sender { (void)sender; [self setLyricOffsetAndRefresh:self.lyricOffset - 0.25]; }
- (void)resetOffset:(id)sender { (void)sender; [self setLyricOffsetAndRefresh:0]; }
- (void)quit:(id)sender { (void)sender; [NSApplication.sharedApplication terminate:nil]; }

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    if (self.pollingTimer) dispatch_source_cancel(self.pollingTimer);
    [self.mediaObserver stop];
    [self.displayTimer invalidate];
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
    [self releaseDisplaySleepAssertion];
    [self.touchBarController dismiss];
}

@end
