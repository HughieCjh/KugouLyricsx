#import "KTLAppDelegate.h"
#import "../Media/KTLMediaRemoteClient.h"
#import "../Media/KTLNowPlaying.h"
#import "../Lyrics/KTLKugouLocalLyricsProvider.h"
#import "../Lyrics/KTLRemoteLyricsService.h"
#import "../Core/KTLLyricTimeline.h"
#import "../Core/KTLKeepAwakePolicy.h"
#import <IOKit/pwr_mgt/IOPMLib.h>

static NSString *const KTLKeepDisplayAwakePreferenceKey = @"KTLKeepDisplayAwakeWhilePlaying";

@interface KTLAppDelegate ()
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenuItem *statusMenuItem;
@property(nonatomic, strong) NSMenuItem *keepAwakeMenuItem;
@property(nonatomic, strong) KTLTouchBarController *touchBarController;
@property(nonatomic, strong) KTLMediaRemoteClient *mediaClient;
@property(nonatomic, strong) KTLKugouLocalLyricsProvider *localLyricsProvider;
@property(nonatomic, strong) KTLRemoteLyricsService *remoteLyricsService;
@property(nonatomic, strong, nullable) KTLLyricTimeline *timeline;
@property(nonatomic, strong, nullable) KTLNowPlaying *nowPlaying;
@property(nonatomic, strong) NSDate *snapshotDate;
@property(nonatomic, copy) NSString *loadedTitle;
@property(nonatomic, copy) NSString *fetchingTitle;
@property(nonatomic, assign) NSTimeInterval lyricOffset;
@property(nonatomic, strong) NSTimer *displayTimer;
@property(nonatomic) dispatch_source_t pollingTimer;
@property(nonatomic) dispatch_queue_t pollingQueue;
@property(nonatomic, assign) BOOL keepDisplayAwakeWhilePlaying;
@property(nonatomic, assign) BOOL hasDisplaySleepAssertion;
@property(nonatomic, assign) BOOL displaySleepAssertionFailed;
@property(nonatomic, assign) IOPMAssertionID displaySleepAssertionID;
@end

@implementation KTLAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    NSApplication.sharedApplication.activationPolicy = NSApplicationActivationPolicyAccessory;
    self.loadedTitle = @"";
    self.fetchingTitle = @"";
    self.snapshotDate = NSDate.date;
    self.keepDisplayAwakeWhilePlaying = [NSUserDefaults.standardUserDefaults
        boolForKey:KTLKeepDisplayAwakePreferenceKey];
    self.displaySleepAssertionID = kIOPMNullAssertionID;

    NSURL *resources = NSBundle.mainBundle.resourceURL;
    self.mediaClient = [[KTLMediaRemoteClient alloc] initWithResourcesDirectory:resources];
    NSString *lyricsPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Containers/com.kugou.mac.Music/Data/Documents/Caches/kgLyric"];
    self.localLyricsProvider = [[KTLKugouLocalLyricsProvider alloc]
        initWithLyricsDirectory:[NSURL fileURLWithPath:lyricsPath]];
    self.remoteLyricsService = [KTLRemoteLyricsService new];

    self.touchBarController = [KTLTouchBarController new];
    self.touchBarController.delegate = self;
    [self configureStatusMenu];
    [self.touchBarController show];
    [self startPolling];
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
    self.keepAwakeMenuItem = [[NSMenuItem alloc]
        initWithTitle:@"播放时保持主屏幕常亮"
               action:@selector(toggleKeepAwake:)
        keyEquivalent:@""];
    self.keepAwakeMenuItem.state = self.keepDisplayAwakeWhilePlaying
        ? NSControlStateValueOn
        : NSControlStateValueOff;
    [menu addItem:self.keepAwakeMenuItem];
    [menu addItemWithTitle:@"歌词提前 0.25 秒" action:@selector(lyricsEarlier:) keyEquivalent:@""];
    [menu addItemWithTitle:@"歌词延后 0.25 秒" action:@selector(lyricsLater:) keyEquivalent:@""];
    [menu addItemWithTitle:@"重置歌词偏移" action:@selector(resetOffset:) keyEquivalent:@""];
    [menu addItem:NSMenuItem.separatorItem];
    [menu addItemWithTitle:@"退出" action:@selector(quit:) keyEquivalent:@"q"];
    for (NSMenuItem *item in menu.itemArray) if (item.action) item.target = self;
    self.statusItem.menu = menu;
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
        dispatch_async(dispatch_get_main_queue(), ^{
            if (state.isKugou) [self applySnapshot:state];
            else if (!state || !state.isKugou) [self applyIdleState:error];
        });
    });
    dispatch_resume(self.pollingTimer);

    self.displayTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                        target:self
                                                      selector:@selector(updateDisplayedLyric:)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)applySnapshot:(KTLNowPlaying *)state {
    BOOL trackChanged = ![self.loadedTitle isEqual:state.title];
    self.nowPlaying = state;
    self.snapshotDate = NSDate.date;
    if (![self.loadedTitle isEqual:state.title] || !self.timeline) {
        NSError *error = nil;
        KTLKugouLocalLyricsResult *lyrics = [self.localLyricsProvider lyricsForTitle:state.title error:&error];
        if (lyrics) {
            self.timeline = [[KTLLyricTimeline alloc] initWithLines:lyrics.lines];
            self.loadedTitle = state.title;
            self.statusMenuItem.title = [NSString stringWithFormat:@"%@ — %@", lyrics.artist, state.title];
        } else {
            self.timeline = nil;
            self.statusMenuItem.title = [NSString stringWithFormat:@"%@（等待歌词）", state.title];
            [self beginRemoteLyricsFetchForState:state];
        }
    }
    [self updateDisplayedLyric:nil];
    [self synchronizeDisplaySleepAssertion];
    if (trackChanged) [self restoreTouchBarAfterTrackChange];
}

- (void)restoreTouchBarAfterTrackChange {
    [self.touchBarController show];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf.touchBarController show];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf.touchBarController show];
    });
}

- (void)beginRemoteLyricsFetchForState:(KTLNowPlaying *)state {
    if ([self.fetchingTitle isEqual:state.title]) return;
    self.fetchingTitle = state.title;
    NSString *requestedTitle = state.title;
    __weak typeof(self) weakSelf = self;
    [self.remoteLyricsService fetchLyricsForTitle:state.title duration:state.duration completion:^(KTLRemoteLyricsResult *result) {
        typeof(self) self = weakSelf;
        if (!self || ![self.nowPlaying.title isEqual:requestedTitle]) return;
        self.fetchingTitle = @"";
        if (!result) return;
        self.timeline = [[KTLLyricTimeline alloc] initWithLines:result.lines];
        self.loadedTitle = requestedTitle;
        self.statusMenuItem.title = [NSString stringWithFormat:@"%@ — %@（%@）",
                                     result.artist.length ? result.artist : @"未知歌手",
                                     requestedTitle,
                                     result.sourceName];
    }];
}

- (void)applyIdleState:(NSError *)error {
    self.nowPlaying = nil;
    self.timeline = nil;
    self.loadedTitle = @"";
    self.fetchingTitle = @"";
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
    NSDictionary *line = [self.timeline lineAtTime:elapsed + self.lyricOffset];
    NSString *text = line[@"text"] ?: self.nowPlaying.title;
    [self.touchBarController updateLyric:text playing:self.nowPlaying.isPlaying];
}

- (void)sendCommand:(KTLMediaCommand)command {
    dispatch_async(self.pollingQueue, ^{ [self.mediaClient sendCommand:command error:nil]; });
    [self restoreTouchBarAfterTrackChange];
}

- (void)touchBarDidRequestPrevious { [self sendCommand:KTLMediaCommandPrevious]; }
- (void)touchBarDidRequestTogglePlayback { [self sendCommand:KTLMediaCommandTogglePlayPause]; }
- (void)touchBarDidRequestNext { [self sendCommand:KTLMediaCommandNext]; }

- (void)showTouchBar:(id)sender { (void)sender; [self.touchBarController show]; }
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

- (void)lyricsEarlier:(id)sender { (void)sender; self.lyricOffset += 0.25; }
- (void)lyricsLater:(id)sender { (void)sender; self.lyricOffset -= 0.25; }
- (void)resetOffset:(id)sender { (void)sender; self.lyricOffset = 0; }
- (void)quit:(id)sender { (void)sender; [NSApplication.sharedApplication terminate:nil]; }

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    if (self.pollingTimer) dispatch_source_cancel(self.pollingTimer);
    [self.displayTimer invalidate];
    [self releaseDisplaySleepAssertion];
    [self.touchBarController dismiss];
}

@end
