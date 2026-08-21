#import <AppKit/AppKit.h>
#import "KTLAppDelegate.h"

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        KTLAppDelegate *delegate = [KTLAppDelegate new];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
