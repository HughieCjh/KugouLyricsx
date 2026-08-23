#import "KTLTouchBarController.h"
#import "KTLKaraokeLyricView.h"
#import <dlfcn.h>
#import <objc/message.h>

static NSTouchBarItemIdentifier const KTLTrayIdentifier = @"com.hughie.KugouLyricsx.tray";
static NSTouchBarItemIdentifier const KTLPreviousIdentifier = @"com.hughie.KugouLyricsx.previous";
static NSTouchBarItemIdentifier const KTLLyricIdentifier = @"com.hughie.KugouLyricsx.lyric";
static NSTouchBarItemIdentifier const KTLToggleIdentifier = @"com.hughie.KugouLyricsx.toggle";
static NSTouchBarItemIdentifier const KTLNextIdentifier = @"com.hughie.KugouLyricsx.next";

typedef void (*KTLSetControlStripPresence)(NSString *, BOOL);
typedef void (*KTLShowsCloseBox)(BOOL);

typedef NS_ENUM(NSUInteger, KTLMediaIcon) {
    KTLMediaIconPrevious,
    KTLMediaIconPlay,
    KTLMediaIconPause,
    KTLMediaIconNext
};

@interface KTLTouchBarController ()
@property(nonatomic, strong) NSTouchBar *touchBar;
@property(nonatomic, strong) NSCustomTouchBarItem *trayItem;
@property(nonatomic, strong) KTLKaraokeLyricView *lyricView;
@property(nonatomic, strong) NSButton *toggleButton;
@end

@implementation KTLTouchBarController

- (instancetype)init {
    self = [super init];
    if (self) [self configureTouchBar];
    return self;
}

- (void)configureTouchBar {
    self.touchBar = [NSTouchBar new];
    self.touchBar.delegate = self;
    self.touchBar.defaultItemIdentifiers = @[
        KTLPreviousIdentifier,
        NSTouchBarItemIdentifierFlexibleSpace,
        KTLLyricIdentifier,
        NSTouchBarItemIdentifierFlexibleSpace,
        KTLToggleIdentifier,
        KTLNextIdentifier
    ];
    self.touchBar.principalItemIdentifier = KTLLyricIdentifier;

    self.trayItem = [[NSCustomTouchBarItem alloc] initWithIdentifier:KTLTrayIdentifier];
    self.trayItem.view = [NSButton buttonWithTitle:@"♪" target:self action:@selector(showFromTray:)];

    void *handle = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_LAZY);
    if (handle) {
        KTLShowsCloseBox showsCloseBox = (KTLShowsCloseBox)dlsym(handle, "DFRSystemModalShowsCloseBoxWhenFrontMost");
        KTLSetControlStripPresence setPresence = (KTLSetControlStripPresence)dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier");
        if (showsCloseBox) showsCloseBox(YES);
        if (setPresence) setPresence(KTLTrayIdentifier, YES);
    }

    SEL addTraySelector = NSSelectorFromString(@"addSystemTrayItem:");
    if ([NSTouchBarItem respondsToSelector:addTraySelector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(NSTouchBarItem.class, addTraySelector, self.trayItem);
    }
}

- (NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier {
    (void)touchBar;
    NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
    if ([identifier isEqual:KTLPreviousIdentifier]) {
        item.view = [self mediaButtonWithIcon:KTLMediaIconPrevious
                           accessibilityLabel:@"上一曲"
                                         action:@selector(previous:)];
    } else if ([identifier isEqual:KTLLyricIdentifier]) {
        self.lyricView = [[KTLKaraokeLyricView alloc] initWithFrame:NSMakeRect(0, 0, 280, 30)];
        [self.lyricView.widthAnchor constraintGreaterThanOrEqualToConstant:280].active = YES;
        item.view = self.lyricView;
    } else if ([identifier isEqual:KTLToggleIdentifier]) {
        self.toggleButton = [self mediaButtonWithIcon:KTLMediaIconPlay
                                   accessibilityLabel:@"播放"
                                                 action:@selector(toggle:)];
        item.view = self.toggleButton;
    } else if ([identifier isEqual:KTLNextIdentifier]) {
        item.view = [self mediaButtonWithIcon:KTLMediaIconNext
                           accessibilityLabel:@"下一曲"
                                         action:@selector(next:)];
    } else {
        return nil;
    }
    return item;
}

- (NSButton *)mediaButtonWithIcon:(KTLMediaIcon)icon
               accessibilityLabel:(NSString *)accessibilityLabel
                             action:(SEL)action {
    NSButton *button = [NSButton buttonWithImage:[self renderedMediaIcon:icon]
                                          target:self
                                          action:action];
    button.imagePosition = NSImageOnly;
    button.imageScaling = NSImageScaleProportionallyDown;
    button.bezelStyle = NSBezelStyleTexturedRounded;
    button.toolTip = accessibilityLabel;
    button.accessibilityLabel = accessibilityLabel;
    [button.widthAnchor constraintEqualToConstant:44.0].active = YES;
    return button;
}

- (NSImage *)renderedMediaIcon:(KTLMediaIcon)icon {
    NSSize size = NSMakeSize(22.0, 22.0);
    NSInteger scale = 2;
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:(NSInteger)ceil(size.width * scale)
                      pixelsHigh:(NSInteger)ceil(size.height * scale)
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSCalibratedRGBColorSpace
                     bytesPerRow:0
                    bitsPerPixel:0];
    bitmap.size = size;

    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    NSRect imageRect = NSMakeRect(0, 0, size.width, size.height);
    [NSColor.clearColor setFill];
    NSRectFillUsingOperation(imageRect, NSCompositingOperationCopy);

    NSBezierPath *path = [NSBezierPath bezierPath];
    path.lineWidth = 2.0;
    path.lineCapStyle = NSLineCapStyleRound;
    path.lineJoinStyle = NSLineJoinStyleRound;
    switch (icon) {
        case KTLMediaIconPrevious:
            [path moveToPoint:NSMakePoint(4.0, 4.0)];
            [path lineToPoint:NSMakePoint(4.0, 18.0)];
            [path moveToPoint:NSMakePoint(17.0, 4.0)];
            [path lineToPoint:NSMakePoint(7.0, 11.0)];
            [path lineToPoint:NSMakePoint(17.0, 18.0)];
            [path closePath];
            break;
        case KTLMediaIconPlay:
            [path moveToPoint:NSMakePoint(6.0, 4.0)];
            [path lineToPoint:NSMakePoint(17.0, 11.0)];
            [path lineToPoint:NSMakePoint(6.0, 18.0)];
            [path closePath];
            break;
        case KTLMediaIconPause:
            [path moveToPoint:NSMakePoint(8.0, 5.0)];
            [path lineToPoint:NSMakePoint(8.0, 17.0)];
            [path moveToPoint:NSMakePoint(14.0, 5.0)];
            [path lineToPoint:NSMakePoint(14.0, 17.0)];
            break;
        case KTLMediaIconNext:
            [path moveToPoint:NSMakePoint(5.0, 4.0)];
            [path lineToPoint:NSMakePoint(15.0, 11.0)];
            [path lineToPoint:NSMakePoint(5.0, 18.0)];
            [path closePath];
            [path moveToPoint:NSMakePoint(18.0, 4.0)];
            [path lineToPoint:NSMakePoint(18.0, 18.0)];
            break;
    }
    [NSColor.whiteColor setStroke];
    [path stroke];
    [NSGraphicsContext restoreGraphicsState];

    NSImage *rendered = [[NSImage alloc] initWithSize:size];
    [rendered addRepresentation:bitmap];
    rendered.template = NO;
    return rendered;
}

- (void)showFromTray:(id)sender { (void)sender; [self show]; }
- (void)previous:(id)sender { (void)sender; [self.delegate touchBarDidRequestPrevious]; }
- (void)toggle:(id)sender { (void)sender; [self.delegate touchBarDidRequestTogglePlayback]; }
- (void)next:(id)sender { (void)sender; [self.delegate touchBarDidRequestNext]; }

- (void)show {
    SEL selector = NSSelectorFromString(@"presentSystemModalTouchBar:systemTrayItemIdentifier:");
    if (![NSTouchBar respondsToSelector:selector]) {
        selector = NSSelectorFromString(@"presentSystemModalFunctionBar:systemTrayItemIdentifier:");
    }
    if ([NSTouchBar respondsToSelector:selector]) {
        ((void (*)(id, SEL, id, id))objc_msgSend)(NSTouchBar.class, selector, self.touchBar, KTLTrayIdentifier);
    }
}

- (void)dismiss {
    SEL selector = NSSelectorFromString(@"dismissSystemModalTouchBar:");
    if (![NSTouchBar respondsToSelector:selector]) selector = NSSelectorFromString(@"dismissSystemModalFunctionBar:");
    if ([NSTouchBar respondsToSelector:selector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(NSTouchBar.class, selector, self.touchBar);
    }
}

- (void)updateLyric:(NSString *)lyric playing:(BOOL)playing {
    NSString *value = lyric ?: @"";
    [self updateLyric:value completedLength:value.length characterFraction:0 playing:playing];
}

- (void)updateLyric:(NSString *)lyric
    completedLength:(NSUInteger)completedLength
   characterFraction:(CGFloat)characterFraction
             playing:(BOOL)playing {
    [self updateLyric:lyric
            nextLyric:@""
      completedLength:completedLength
     characterFraction:characterFraction
            dualLine:NO
       currentOnLeft:YES
               playing:playing];
}

- (void)updateLyric:(NSString *)lyric
          nextLyric:(NSString *)nextLyric
    completedLength:(NSUInteger)completedLength
   characterFraction:(CGFloat)characterFraction
          dualLine:(BOOL)dualLine
     currentOnLeft:(BOOL)currentOnLeft
             playing:(BOOL)playing {
    [self.lyricView updateText:lyric
                      nextText:nextLyric
               completedLength:completedLength
              characterFraction:characterFraction
                      dualLine:dualLine
                 currentOnLeft:currentOnLeft];
    NSString *label = playing ? @"暂停" : @"播放";
    self.toggleButton.image = [self renderedMediaIcon:(playing
        ? KTLMediaIconPause
        : KTLMediaIconPlay)];
    self.toggleButton.toolTip = label;
    self.toggleButton.accessibilityLabel = label;
}

@end
