#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol KTLTouchBarControllerDelegate <NSObject>
- (void)touchBarDidRequestPrevious;
- (void)touchBarDidRequestTogglePlayback;
- (void)touchBarDidRequestNext;
@end

@interface KTLTouchBarController : NSObject <NSTouchBarDelegate>
@property(nonatomic, weak) id<KTLTouchBarControllerDelegate> delegate;
- (void)show;
- (void)refresh;
- (void)showAndRefresh;
- (void)dismiss;
- (void)updateLyric:(NSString *)lyric playing:(BOOL)playing;
- (void)updateLyric:(NSString *)lyric
    completedLength:(NSUInteger)completedLength
   characterFraction:(CGFloat)characterFraction
             playing:(BOOL)playing;
- (void)updateLyric:(NSString *)lyric
          nextLyric:(NSString *)nextLyric
    completedLength:(NSUInteger)completedLength
   characterFraction:(CGFloat)characterFraction
          dualLine:(BOOL)dualLine
     currentOnLeft:(BOOL)currentOnLeft
             playing:(BOOL)playing;
@end

NS_ASSUME_NONNULL_END
