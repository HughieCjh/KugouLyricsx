#import "KTLMediaRemoteClient.h"
#import "KTLNowPlaying.h"

static NSString *const KTLErrorDomain = @"KugouLyricsx.MediaRemote";

@interface KTLMediaRemoteClient ()
@property(nonatomic, strong) NSURL *resourcesDirectory;
@end

@implementation KTLMediaRemoteClient

- (instancetype)initWithResourcesDirectory:(NSURL *)resourcesDirectory {
    self = [super init];
    if (self) _resourcesDirectory = resourcesDirectory;
    return self;
}

- (nullable NSData *)runMediaControlArguments:(NSArray<NSString *> *)arguments error:(NSError **)error {
    NSURL *toolURL = [self.resourcesDirectory URLByAppendingPathComponent:@"MediaControl/bin/media-control"];
    if (![NSFileManager.defaultManager isExecutableFileAtPath:toolURL.path]) return nil;
    NSTask *task = [NSTask new];
    task.executableURL = toolURL;
    task.arguments = arguments;
    NSPipe *outputPipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];
    task.standardOutput = outputPipe;
    task.standardError = errorPipe;
    NSError *launchError = nil;
    if (![task launchAndReturnError:&launchError]) {
        if (error) *error = launchError;
        return nil;
    }
    [task waitUntilExit];
    NSData *output = [outputPipe.fileHandleForReading readDataToEndOfFile];
    if (task.terminationStatus != 0) {
        NSData *errorData = [errorPipe.fileHandleForReading readDataToEndOfFile];
        NSString *message = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding] ?: @"媒体控制命令失败";
        if (error) *error = [NSError errorWithDomain:KTLErrorDomain code:task.terminationStatus userInfo:@{NSLocalizedDescriptionKey: message}];
        return nil;
    }
    return output;
}

- (nullable NSData *)runScriptNamed:(NSString *)name arguments:(NSArray<NSString *> *)arguments error:(NSError **)error {
    NSURL *scriptURL = [self.resourcesDirectory URLByAppendingPathComponent:name];
    if (![NSFileManager.defaultManager fileExistsAtPath:scriptURL.path]) {
        if (error) *error = [NSError errorWithDomain:KTLErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"找不到媒体桥接脚本"}];
        return nil;
    }

    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/osascript"];
    NSMutableArray *taskArguments = [NSMutableArray arrayWithObjects:@"-l", @"JavaScript", scriptURL.path, nil];
    [taskArguments addObjectsFromArray:arguments];
    task.arguments = taskArguments;
    NSPipe *outputPipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];
    task.standardOutput = outputPipe;
    task.standardError = errorPipe;

    NSError *launchError = nil;
    if (![task launchAndReturnError:&launchError]) {
        if (error) *error = launchError;
        return nil;
    }
    [task waitUntilExit];
    NSData *output = [outputPipe.fileHandleForReading readDataToEndOfFile];
    if (task.terminationStatus != 0) {
        NSData *errorData = [errorPipe.fileHandleForReading readDataToEndOfFile];
        NSString *message = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding] ?: @"无法读取系统正在播放";
        if (error) *error = [NSError errorWithDomain:KTLErrorDomain code:task.terminationStatus userInfo:@{NSLocalizedDescriptionKey: message}];
        return nil;
    }
    return output;
}

- (KTLNowPlaying *)snapshotWithError:(NSError **)error {
    __block NSData *primaryData = nil;
    __block NSData *positionData = nil;
    __block NSError *primaryError = nil;
    __block NSError *positionError = nil;

    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
    dispatch_group_async(group, queue, ^{
        primaryData = [self runMediaControlArguments:@[@"get", @"--now", @"--no-artwork"]
                                               error:&primaryError];
    });
    dispatch_group_async(group, queue, ^{
        positionData = [self runScriptNamed:@"now-playing.js" arguments:@[] error:&positionError];
    });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    NSError *primaryParseError = nil;
    NSError *positionParseError = nil;
    NSDictionary *primaryDictionary = primaryData.length > 0
        ? [NSJSONSerialization JSONObjectWithData:primaryData options:0 error:&primaryParseError]
        : nil;
    NSDictionary *positionDictionary = positionData.length > 0
        ? [NSJSONSerialization JSONObjectWithData:positionData options:0 error:&positionParseError]
        : nil;
    KTLNowPlaying *primary = [primaryDictionary isKindOfClass:NSDictionary.class]
        ? [KTLNowPlaying nowPlayingFromDictionary:primaryDictionary]
        : nil;
    KTLNowPlaying *positionSource = [positionDictionary isKindOfClass:NSDictionary.class]
        ? [KTLNowPlaying nowPlayingFromDictionary:positionDictionary]
        : nil;
    KTLNowPlaying *result = [KTLNowPlaying reconciledPrimary:primary positionSource:positionSource];
    if (!result && error) {
        *error = primaryError ?: positionError ?: primaryParseError ?: positionParseError;
    }
    return result;
}

- (BOOL)sendCommand:(KTLMediaCommand)command error:(NSError **)error {
    NSDictionary<NSNumber *, NSString *> *names = @{
        @(KTLMediaCommandPlay): @"play",
        @(KTLMediaCommandPause): @"pause",
        @(KTLMediaCommandTogglePlayPause): @"toggle-play-pause",
        @(KTLMediaCommandStop): @"stop",
        @(KTLMediaCommandNext): @"next-track",
        @(KTLMediaCommandPrevious): @"previous-track"
    };
    NSString *name = names[@(command)];
    NSData *data = name ? [self runMediaControlArguments:@[name] error:error] : nil;
    if (!data) {
        data = [self runScriptNamed:@"media-command.js"
                          arguments:@[[NSString stringWithFormat:@"%ld", (long)command]]
                              error:error];
    }
    return data != nil;
}

@end
