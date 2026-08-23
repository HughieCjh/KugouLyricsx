#import "KTLNowPlaying.h"

@interface KTLNowPlaying ()
@property(nonatomic, assign, readwrite) BOOL hasElapsed;
@end

@implementation KTLNowPlaying

+ (double)safeDoubleFromValue:(id)value {
    return [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 0;
}

+ (BOOL)firstDoubleFromDictionary:(NSDictionary *)dictionary
                             keys:(NSArray<NSString *> *)keys
                            value:(double *)result {
    for (NSString *key in keys) {
        id value = dictionary[key];
        if ([value respondsToSelector:@selector(doubleValue)]) {
            if (result) *result = [value doubleValue];
            return YES;
        }
    }
    if (result) *result = 0;
    return NO;
}

+ (instancetype)nowPlayingFromDictionary:(NSDictionary *)dictionary {
    NSString *title = [dictionary[@"title"] isKindOfClass:NSString.class] ? dictionary[@"title"] : @"";
    if (title.length == 0) return nil;
    KTLNowPlaying *state = [KTLNowPlaying new];
    state.title = title;
    state.artist = [dictionary[@"artist"] isKindOfClass:NSString.class] ? dictionary[@"artist"] : @"";
    state.album = [dictionary[@"album"] isKindOfClass:NSString.class] ? dictionary[@"album"] : @"";
    state.bundleIdentifier = [dictionary[@"bundleIdentifier"] isKindOfClass:NSString.class] ? dictionary[@"bundleIdentifier"] : @"";
    state.appName = [dictionary[@"appName"] isKindOfClass:NSString.class] ? dictionary[@"appName"] : @"";
    state.duration = [self safeDoubleFromValue:dictionary[@"duration"]];
    double elapsed = 0;
    state.hasElapsed = [self firstDoubleFromDictionary:dictionary
                                                  keys:@[@"elapsedTimeNow", @"elapsedTime", @"elapsed"]
                                                 value:&elapsed];
    state.elapsed = elapsed;
    state.playbackRate = [self safeDoubleFromValue:dictionary[@"playbackRate"]];
    id playing = dictionary[@"playing"];
    state.reportedPlaying = [playing respondsToSelector:@selector(boolValue)]
        ? [playing boolValue]
        : state.playbackRate > 0.001;
    return state;
}

+ (instancetype)reconciledPrimary:(KTLNowPlaying *)primary
                    positionSource:(KTLNowPlaying *)positionSource {
    if (!primary) return positionSource;
    if (!positionSource || !positionSource.hasElapsed) return primary;

    BOOL sameTitle = [primary.title isEqualToString:positionSource.title];
    BOOL compatibleDuration = primary.duration <= 0 || positionSource.duration <= 0 ||
        fabs(primary.duration - positionSource.duration) < 4.0;
    if (sameTitle && compatibleDuration) {
        primary.elapsed = MAX(0, positionSource.elapsed);
        primary.hasElapsed = YES;
    }
    return primary;
}

+ (instancetype)foregroundSafeObservedState:(KTLNowPlaying *)observed
                                 currentState:(KTLNowPlaying *)currentState
                             estimatedElapsed:(NSTimeInterval)estimatedElapsed {
    if (!observed || !currentState ||
        ![observed.title isEqualToString:currentState.title]) return observed;

    if (observed.duration <= 0 && currentState.duration > 0) {
        observed.duration = currentState.duration;
    }
    if (observed.bundleIdentifier.length == 0) {
        observed.bundleIdentifier = currentState.bundleIdentifier;
    }
    if (observed.appName.length == 0) observed.appName = currentState.appName;

    BOOL staleClock = !observed.hasElapsed || !isfinite(observed.elapsed) ||
        fabs(observed.elapsed - estimatedElapsed) > 1.25;
    if (staleClock) {
        observed.elapsed = MAX(0, estimatedElapsed);
        observed.hasElapsed = YES;
        observed.playbackRate = currentState.playbackRate;
        observed.reportedPlaying = currentState.isPlaying;
    }
    return observed;
}

- (BOOL)isPlaying { return self.reportedPlaying; }

- (void)applyConfirmedElapsed:(NSTimeInterval)elapsed {
    if (!isfinite(elapsed)) return;
    self.elapsed = MAX(0, elapsed);
    self.hasElapsed = YES;
}

- (BOOL)isKugou {
    NSString *identity = [[NSString stringWithFormat:@"%@ %@", self.bundleIdentifier, self.appName] lowercaseString];
    return [identity containsString:@"kugou"] || [identity containsString:@"kgmusic"] || [identity containsString:@"酷狗"];
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"title": self.title ?: @"",
        @"artist": self.artist ?: @"",
        @"album": self.album ?: @"",
        @"duration": @(self.duration),
        @"elapsed": @(self.elapsed),
        @"hasElapsed": @(self.hasElapsed),
        @"playbackRate": @(self.playbackRate),
        @"bundleIdentifier": self.bundleIdentifier ?: @"",
        @"appName": self.appName ?: @"",
        @"isKugou": @(self.isKugou)
    };
}

@end
