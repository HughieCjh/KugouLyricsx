#import "KTLMediaRemoteObserver.h"
#import "KTLNowPlaying.h"

@interface KTLMediaRemoteObserver ()
@property(nonatomic, strong) NSURL *resourcesDirectory;
@property(nonatomic, copy) KTLMediaRemoteObserverHandler handler;
@property(nonatomic, strong, nullable) NSTask *task;
@property(nonatomic, strong, nullable) NSPipe *outputPipe;
@property(nonatomic, strong) NSMutableData *buffer;
@property(nonatomic, assign) BOOL stopped;
@end

@implementation KTLMediaRemoteObserver

- (instancetype)initWithResourcesDirectory:(NSURL *)resourcesDirectory
                                    handler:(KTLMediaRemoteObserverHandler)handler {
    self = [super init];
    if (self) {
        _resourcesDirectory = resourcesDirectory;
        _handler = [handler copy];
        _buffer = [NSMutableData data];
        _stopped = YES;
    }
    return self;
}

- (void)start {
    self.stopped = NO;
    if (self.task.running) return;
    NSURL *toolURL = [self.resourcesDirectory URLByAppendingPathComponent:@"MediaControl/bin/media-control"];
    if (![NSFileManager.defaultManager isExecutableFileAtPath:toolURL.path]) return;

    NSTask *task = [NSTask new];
    task.executableURL = toolURL;
    task.arguments = @[@"stream", @"--no-diff", @"--no-artwork", @"--debounce=0"];
    NSPipe *outputPipe = [NSPipe pipe];
    task.standardOutput = outputPipe;
    task.standardError = [NSPipe pipe];
    self.task = task;
    self.outputPipe = outputPipe;
    [self.buffer setLength:0];

    __weak typeof(self) weakSelf = self;
    outputPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *handle) {
        NSData *data = handle.availableData;
        if (data.length > 0) [weakSelf consumeData:data];
    };
    task.terminationHandler = ^(NSTask *finishedTask) {
        (void)finishedTask;
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (!self) return;
            self.outputPipe.fileHandleForReading.readabilityHandler = nil;
            self.task = nil;
            self.outputPipe = nil;
            if (!self.stopped) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{ [weakSelf start]; });
            }
        });
    };
    NSError *error = nil;
    if (![task launchAndReturnError:&error]) {
        outputPipe.fileHandleForReading.readabilityHandler = nil;
        self.task = nil;
        self.outputPipe = nil;
    }
}

- (void)consumeData:(NSData *)data {
    @synchronized (self.buffer) {
        [self.buffer appendData:data];
        const uint8_t *bytes = self.buffer.bytes;
        NSUInteger consumed = 0;
        for (NSUInteger index = 0; index < self.buffer.length; index++) {
            if (bytes[index] != '\n') continue;
            NSData *lineData = [self.buffer subdataWithRange:NSMakeRange(consumed, index - consumed)];
            consumed = index + 1;
            [self consumeLineData:lineData];
        }
        if (consumed > 0) [self.buffer replaceBytesInRange:NSMakeRange(0, consumed) withBytes:NULL length:0];
    }
}

- (void)consumeLineData:(NSData *)lineData {
    if (lineData.length == 0) return;
    NSDictionary *event = [NSJSONSerialization JSONObjectWithData:lineData options:0 error:nil];
    NSDictionary *payload = [event[@"payload"] isKindOfClass:NSDictionary.class] ? event[@"payload"] : nil;
    if (payload.count == 0) return;
    KTLNowPlaying *state = [KTLNowPlaying nowPlayingFromDictionary:payload];
    if (state.title.length == 0) return;
    dispatch_async(dispatch_get_main_queue(), ^{ self.handler(state); });
}

- (void)stop {
    self.stopped = YES;
    self.outputPipe.fileHandleForReading.readabilityHandler = nil;
    if (self.task.running) [self.task terminate];
    self.task = nil;
    self.outputPipe = nil;
}

- (void)dealloc {
    [self stop];
}

@end
