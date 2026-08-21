#import "KTLNowPlaying.h"

@implementation KTLNowPlaying

+ (double)safeDoubleFromValue:(id)value {
    return [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 0;
}

+ (double)firstDoubleFromDictionary:(NSDictionary *)dictionary keys:(NSArray<NSString *> *)keys {
    for (NSString *key in keys) {
        id value = dictionary[key];
        if ([value respondsToSelector:@selector(doubleValue)]) return [value doubleValue];
    }
    return 0;
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
    state.elapsed = [self firstDoubleFromDictionary:dictionary
                                               keys:@[@"elapsedTimeNow", @"elapsedTime", @"elapsed"]];
    state.playbackRate = [self safeDoubleFromValue:dictionary[@"playbackRate"]];
    id playing = dictionary[@"playing"];
    state.reportedPlaying = [playing respondsToSelector:@selector(boolValue)]
        ? [playing boolValue]
        : state.playbackRate > 0.001;
    return state;
}

- (BOOL)isPlaying { return self.reportedPlaying; }

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
        @"playbackRate": @(self.playbackRate),
        @"bundleIdentifier": self.bundleIdentifier ?: @"",
        @"appName": self.appName ?: @"",
        @"isKugou": @(self.isKugou)
    };
}

@end
