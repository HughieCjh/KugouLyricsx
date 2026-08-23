#import "KTLKRCDecoder.h"
#import <zlib.h>

static NSString *const KTLKRCErrorDomain = @"KugouLyricsx.KRC";
static const uint8_t KTLKRCKey[16] = {
    0x40, 0x47, 0x61, 0x77, 0x5E, 0x32, 0x74, 0x47,
    0x51, 0x36, 0x31, 0x2D, 0xCE, 0xD2, 0x6E, 0x69
};

@implementation KTLKRCDecoder

+ (NSString *)decodeData:(NSData *)data error:(NSError **)error {
    const uint8_t header[] = {'k', 'r', 'c', '1'};
    if (data.length <= 4 || memcmp(data.bytes, header, 4) != 0) {
        if (error) *error = [NSError errorWithDomain:KTLKRCErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: @"不是有效的 KRC 文件"}];
        return nil;
    }

    NSUInteger encryptedLength = data.length - 4;
    NSMutableData *compressed = [NSMutableData dataWithLength:encryptedLength];
    const uint8_t *input = (const uint8_t *)data.bytes + 4;
    uint8_t *decoded = compressed.mutableBytes;
    for (NSUInteger i = 0; i < encryptedLength; i++) decoded[i] = input[i] ^ KTLKRCKey[i % 16];

    z_stream stream = {0};
    stream.next_in = compressed.mutableBytes;
    stream.avail_in = (uInt)compressed.length;
    if (inflateInit(&stream) != Z_OK) {
        if (error) *error = [NSError errorWithDomain:KTLKRCErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"无法初始化 KRC 解压器"}];
        return nil;
    }

    NSMutableData *plain = [NSMutableData data];
    uint8_t buffer[4096];
    int status = Z_OK;
    while (status == Z_OK) {
        stream.next_out = buffer;
        stream.avail_out = sizeof(buffer);
        status = inflate(&stream, Z_NO_FLUSH);
        NSUInteger produced = sizeof(buffer) - stream.avail_out;
        if (produced > 0) [plain appendBytes:buffer length:produced];
    }
    inflateEnd(&stream);

    if (status != Z_STREAM_END) {
        if (error) *error = [NSError errorWithDomain:KTLKRCErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"KRC 数据已损坏或格式不兼容"}];
        return nil;
    }

    NSString *result = [[NSString alloc] initWithData:plain encoding:NSUTF8StringEncoding];
    if (!result && error) *error = [NSError errorWithDomain:KTLKRCErrorDomain code:4 userInfo:@{NSLocalizedDescriptionKey: @"KRC 歌词不是 UTF-8 文本"}];
    return result;
}

@end

@implementation KTLKRCParser

+ (BOOL)isMetadataText:(NSString *)text time:(NSTimeInterval)time duration:(NSTimeInterval)duration {
    if (duration > 0 && duration < 0.08) return YES;
    if (time < 10 && [text containsString:@" - "]) return YES;
    NSArray<NSString *> *prefixes = @[
        @"作词", @"作曲", @"改编词曲", @"词：", @"词:", @"曲：", @"曲:", @"编曲", @"制作人",
        @"制作：", @"制作:", @"混音", @"母带", @"和声", @"录音", @"吉他", @"贝斯",
        @"钢琴", @"鼓：", @"鼓:", @"Program", @"合音", @"音乐总监", @"音响总监",
        @"灯光设计", @"乐队统筹", @"监制", @"统筹", @"企划", @"出品", @"发行",
        @"封面", @"OP：", @"OP:", @"SP：", @"SP:"
    ];
    for (NSString *prefix in prefixes) {
        if ([text hasPrefix:prefix]) return YES;
    }
    if (time < 30 && ([text containsString:@"："] || [text containsString:@":"] ||
                      [text containsString:@"@"] || [text containsString:@"/"])) return YES;
    return NO;
}

+ (NSArray<NSDictionary<NSString *, id> *> *)parseString:(NSString *)source {
    NSArray<NSDictionary<NSString *, id> *> *allLines = [self parseKaraokeString:source];
    return [allLines filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *line, NSDictionary *bindings) {
        (void)bindings;
        return ![line[@"metadata"] boolValue];
    }]];
}

+ (NSArray<NSDictionary<NSString *, id> *> *)parseKaraokeString:(NSString *)source {
    NSRegularExpression *lineRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\[(\\d+),(\\d+)\\](.*)$" options:0 error:nil];
    NSRegularExpression *wordRegex = [NSRegularExpression regularExpressionWithPattern:@"<(-?\\d+),(-?\\d+)(?:,-?\\d+)?>" options:0 error:nil];
    NSMutableArray *lines = [NSMutableArray array];
    [source enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        (void)stop;
        NSTextCheckingResult *match = [lineRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
        if (!match) return;
        NSTimeInterval time = [[line substringWithRange:[match rangeAtIndex:1]] doubleValue] / 1000.0;
        NSTimeInterval duration = [[line substringWithRange:[match rangeAtIndex:2]] doubleValue] / 1000.0;
        NSString *body = [line substringWithRange:[match rangeAtIndex:3]];
        NSArray<NSTextCheckingResult *> *wordMatches = [wordRegex matchesInString:body options:0 range:NSMakeRange(0, body.length)];
        NSMutableString *plainText = [NSMutableString string];
        NSMutableArray<NSDictionary<NSString *, id> *> *segments = [NSMutableArray array];
        for (NSUInteger index = 0; index < wordMatches.count; index++) {
            NSTextCheckingResult *wordMatch = wordMatches[index];
            NSUInteger textStart = NSMaxRange(wordMatch.range);
            NSUInteger textEnd = index + 1 < wordMatches.count
                ? wordMatches[index + 1].range.location
                : body.length;
            if (textEnd < textStart) continue;
            NSString *wordText = [body substringWithRange:NSMakeRange(textStart, textEnd - textStart)];
            NSRange outputRange = NSMakeRange(plainText.length, wordText.length);
            [plainText appendString:wordText];
            if (wordText.length > 0) {
                [segments addObject:@{
                    @"text": wordText,
                    @"range": [NSValue valueWithRange:outputRange],
                    @"offset": @([[body substringWithRange:[wordMatch rangeAtIndex:1]] doubleValue] / 1000.0),
                    @"duration": @([[body substringWithRange:[wordMatch rangeAtIndex:2]] doubleValue] / 1000.0)
                }];
            }
        }
        if (wordMatches.count == 0) [plainText appendString:body];

        NSString *text = [plainText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSRange trimmedRange = text.length > 0 ? [plainText rangeOfString:text] : NSMakeRange(NSNotFound, 0);
        if (trimmedRange.location != NSNotFound && trimmedRange.location > 0) {
            NSMutableArray *adjusted = [NSMutableArray array];
            for (NSDictionary *segment in segments) {
                NSRange range = [segment[@"range"] rangeValue];
                NSRange intersection = NSIntersectionRange(range, trimmedRange);
                if (intersection.length == 0) continue;
                NSMutableDictionary *copy = [segment mutableCopy];
                copy[@"range"] = [NSValue valueWithRange:NSMakeRange(intersection.location - trimmedRange.location,
                                                                      intersection.length)];
                copy[@"text"] = [plainText substringWithRange:intersection];
                [adjusted addObject:copy];
            }
            segments = adjusted;
        }
        NSTimeInterval segmentEnd = 0;
        for (NSDictionary<NSString *, id> *segment in segments) {
            NSTimeInterval end = [segment[@"offset"] doubleValue] +
                MAX(0, [segment[@"duration"] doubleValue]);
            segmentEnd = MAX(segmentEnd, end);
        }
        NSTimeInterval effectiveDuration = duration;
        if (segmentEnd > 0 && duration > segmentEnd + 15.0) {
            effectiveDuration = segmentEnd;
        }
        if (text.length > 0) {
            [lines addObject:@{
                @"time": @(time),
                @"duration": @(effectiveDuration),
                @"endTime": @(time + effectiveDuration),
                @"text": text,
                @"segments": segments,
                @"metadata": @([self isMetadataText:text time:time duration:effectiveDuration]),
                @"sourceIndex": @(lines.count)
            }];
        }
    }];
    return lines;
}

@end
