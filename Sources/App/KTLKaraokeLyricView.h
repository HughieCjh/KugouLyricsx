#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KTLKaraokeLyricView : NSView
- (void)updateText:(NSString *)text
   completedLength:(NSUInteger)completedLength
  characterFraction:(CGFloat)characterFraction;
- (void)updateText:(NSString *)text
          nextText:(NSString *)nextText
   completedLength:(NSUInteger)completedLength
  characterFraction:(CGFloat)characterFraction
          dualLine:(BOOL)dualLine
     currentOnLeft:(BOOL)currentOnLeft;
@end

NS_ASSUME_NONNULL_END
