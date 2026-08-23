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

+ (NSArray<NSDictionary<NSString *, id> *> *)parseString:(NSString *)source {
    NSRegularExpression *lineRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\[(\\d+),(\\d+)\\](.*)$" options:0 error:nil];
    NSRegularExpression *wordRegex = [NSRegularExpression regularExpressionWithPattern:@"<-?\\d+,-?\\d+(?:,-?\\d+)?>" options:0 error:nil];
    NSMutableArray *lines = [NSMutableArray array];
    [source enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        (void)stop;
        NSTextCheckingResult *match = [lineRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
        if (!match) return;
        NSTimeInterval time = [[line substringWithRange:[match rangeAtIndex:1]] doubleValue] / 1000.0;
        NSString *text = [line substringWithRange:[match rangeAtIndex:3]];
        text = [wordRegex stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@""];
        text = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (text.length > 0) [lines addObject:@{ @"time": @(time), @"text": text }];
    }];
    return lines;
}

@end
