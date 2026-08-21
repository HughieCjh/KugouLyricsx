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
- (void)dismiss;
- (void)updateLyric:(NSString *)lyric playing:(BOOL)playing;
@end

NS_ASSUME_NONNULL_END
