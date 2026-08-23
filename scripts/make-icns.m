#import <Foundation/Foundation.h>
#include <arpa/inet.h>

static void AppendFourCC(NSMutableData *output, NSString *value) {
    NSData *bytes = [value dataUsingEncoding:NSASCIIStringEncoding];
    [output appendData:bytes];
}

static void AppendUInt32(NSMutableData *output, uint32_t value) {
    uint32_t bigEndianValue = htonl(value);
    [output appendBytes:&bigEndianValue length:sizeof(bigEndianValue)];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) {
            fprintf(stderr, "usage: make-icns ICONSET_DIR OUTPUT.icns\n");
            return 2;
        }

        NSString *iconsetPath = [NSString stringWithUTF8String:argv[1]];
        NSString *outputPath = [NSString stringWithUTF8String:argv[2]];
        NSArray<NSArray<NSString *> *> *entries = @[
            @[@"icp4", @"icon_16x16.png"],
            @[@"ic11", @"icon_16x16@2x.png"],
            @[@"icp5", @"icon_32x32.png"],
            @[@"ic12", @"icon_32x32@2x.png"],
            @[@"ic07", @"icon_128x128.png"],
            @[@"ic13", @"icon_128x128@2x.png"],
            @[@"ic08", @"icon_256x256.png"],
            @[@"ic14", @"icon_256x256@2x.png"],
            @[@"ic09", @"icon_512x512.png"],
            @[@"ic10", @"icon_512x512@2x.png"]
        ];

        NSMutableData *output = [NSMutableData data];
        AppendFourCC(output, @"icns");
        AppendUInt32(output, 0);

        for (NSArray<NSString *> *entry in entries) {
            NSString *imagePath = [iconsetPath stringByAppendingPathComponent:entry[1]];
            NSData *imageData = [NSData dataWithContentsOfFile:imagePath];
            if (!imageData) {
                fprintf(stderr, "missing icon image: %s\n", imagePath.fileSystemRepresentation);
                return 3;
            }
            AppendFourCC(output, entry[0]);
            AppendUInt32(output, (uint32_t)(imageData.length + 8));
            [output appendData:imageData];
        }

        uint32_t totalLength = htonl((uint32_t)output.length);
        [output replaceBytesInRange:NSMakeRange(4, 4) withBytes:&totalLength];
        NSError *error = nil;
        if (![output writeToFile:outputPath options:NSDataWritingAtomic error:&error]) {
            fprintf(stderr, "%s\n", error.localizedDescription.UTF8String);
            return 4;
        }
    }
    return 0;
}
