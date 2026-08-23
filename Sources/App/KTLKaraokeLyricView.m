#import "KTLKaraokeLyricView.h"

@interface KTLKaraokeLyricView ()
@property(nonatomic, copy) NSString *text;
@property(nonatomic, copy) NSString *nextText;
@property(nonatomic, assign) NSUInteger completedLength;
@property(nonatomic, assign) CGFloat characterFraction;
@property(nonatomic, strong) NSFont *font;
@property(nonatomic, strong) NSFont *dualFont;
@property(nonatomic, assign) BOOL dualLine;
@property(nonatomic, assign) BOOL currentOnLeft;
@end

@implementation KTLKaraokeLyricView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _text = @"等待酷狗播放";
        _nextText = @"";
        _font = [NSFont systemFontOfSize:15 weight:NSFontWeightMedium];
        _dualFont = [NSFont systemFontOfSize:14.0 weight:NSFontWeightMedium];
        _currentOnLeft = YES;
        self.wantsLayer = YES;
        [self setAccessibilityRole:NSAccessibilityStaticTextRole];
        [self setAccessibilityLabel:_text];
    }
    return self;
}

- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }

- (void)updateText:(NSString *)text
   completedLength:(NSUInteger)completedLength
  characterFraction:(CGFloat)characterFraction {
    [self updateText:text
            nextText:@""
     completedLength:completedLength
    characterFraction:characterFraction
            dualLine:NO
       currentOnLeft:YES];
}

- (void)updateText:(NSString *)text
          nextText:(NSString *)nextText
   completedLength:(NSUInteger)completedLength
  characterFraction:(CGFloat)characterFraction
          dualLine:(BOOL)dualLine
     currentOnLeft:(BOOL)currentOnLeft {
    NSString *value = text ?: @"";
    NSString *nextValue = nextText ?: @"";
    NSUInteger safeLength = MIN(completedLength, value.length);
    CGFloat safeFraction = MIN(1.0, MAX(0.0, characterFraction));
    if ([self.text isEqualToString:value] && [self.nextText isEqualToString:nextValue] &&
        self.completedLength == safeLength && fabs(self.characterFraction - safeFraction) < 0.001 &&
        self.dualLine == dualLine && self.currentOnLeft == currentOnLeft) return;
    self.text = value;
    self.nextText = nextValue;
    self.completedLength = safeLength;
    self.characterFraction = safeFraction;
    self.dualLine = dualLine;
    self.currentOnLeft = currentOnLeft;
    NSString *accessibilityText = dualLine && nextValue.length > 0
        ? [NSString stringWithFormat:@"当前歌词：%@，下一句：%@", value, nextValue]
        : value;
    [self setAccessibilityLabel:accessibilityText];
    self.needsDisplay = YES;
    [self displayIfNeeded];
}

- (NSDictionary<NSAttributedStringKey, id> *)attributesWithColor:(NSColor *)color font:(NSFont *)font {
    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.alignment = NSTextAlignmentCenter;
    style.lineBreakMode = NSLineBreakByTruncatingTail;
    return @{ NSFontAttributeName: font,
              NSForegroundColorAttributeName: color,
              NSParagraphStyleAttributeName: style };
}

- (CGFloat)highlightWidthWithAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes {
    if (self.completedLength >= self.text.length) {
        return [self.text sizeWithAttributes:attributes].width;
    }
    NSString *completed = [self.text substringToIndex:self.completedLength];
    CGFloat width = [completed sizeWithAttributes:attributes].width;
    if (self.characterFraction <= 0 || self.completedLength >= self.text.length) return width;
    NSRange characterRange = [self.text rangeOfComposedCharacterSequenceAtIndex:self.completedLength];
    NSString *character = [self.text substringWithRange:characterRange];
    return width + [character sizeWithAttributes:attributes].width * self.characterFraction;
}

- (NSRect)verticallyCenteredTextRectForRect:(NSRect)rect font:(NSFont *)font {
    CGFloat lineHeight = ceil(font.ascender - font.descender + font.leading);
    return NSMakeRect(NSMinX(rect), NSMinY(rect) + MAX(0, floor((NSHeight(rect) - lineHeight) / 2.0)),
                      NSWidth(rect), lineHeight + 2.0);
}

- (void)drawText:(NSString *)text inRect:(NSRect)rect font:(NSFont *)font color:(NSColor *)color {
    NSDictionary *attributes = [self attributesWithColor:color font:font];
    NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:text attributes:attributes];
    NSStringDrawingOptions options = NSStringDrawingTruncatesLastVisibleLine |
                                     NSStringDrawingUsesLineFragmentOrigin;
    [attributed drawWithRect:[self verticallyCenteredTextRectForRect:rect font:font] options:options];
}

- (void)drawHighlightedCurrentTextInRect:(NSRect)rect font:(NSFont *)font {
    NSColor *baseColor = [NSColor colorWithWhite:0.68 alpha:1.0];
    NSColor *highlightColor = [NSColor colorWithSRGBRed:0.18 green:0.52 blue:0.96 alpha:1.0];
    [self drawText:self.text inRect:rect font:font color:baseColor];
    NSDictionary *highlightAttributes = [self attributesWithColor:highlightColor font:font];

    CGFloat naturalWidth = [self.text sizeWithAttributes:highlightAttributes].width;
    CGFloat textStart = NSMinX(rect) + MAX(0, floor((NSWidth(rect) - naturalWidth) / 2.0));
    CGFloat highlightWidth = MIN(NSMaxX(rect) - textStart,
                                 [self highlightWidthWithAttributes:highlightAttributes]);
    if (highlightWidth <= 0) return;
    [NSGraphicsContext saveGraphicsState];
    NSRectClip(NSMakeRect(textStart, NSMinY(rect), highlightWidth, NSHeight(rect)));
    [self drawText:self.text inRect:rect font:font color:highlightColor];
    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    if (!self.dualLine) {
        [self drawHighlightedCurrentTextInRect:self.bounds font:self.font];
        return;
    }

    CGFloat gap = 20.0;
    CGFloat laneWidth = MAX(0, floor((NSWidth(self.bounds) - gap) / 2.0));
    NSRect leftRect = NSMakeRect(0, 0, laneWidth, NSHeight(self.bounds));
    NSRect rightRect = NSMakeRect(laneWidth + gap, 0, laneWidth, NSHeight(self.bounds));
    NSRect activeRect = self.currentOnLeft ? leftRect : rightRect;
    NSRect previewRect = self.currentOnLeft ? rightRect : leftRect;
    [self drawHighlightedCurrentTextInRect:activeRect font:self.dualFont];
    [self drawText:self.nextText
            inRect:previewRect
              font:self.dualFont
             color:[NSColor colorWithWhite:0.48 alpha:1.0]];
}

@end
