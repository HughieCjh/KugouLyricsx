#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KTLKugouLocalLyricsResult : NSObject
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *artist;
@property(nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *lines;
@property(nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *karaokeLines;
@property(nonatomic, strong) NSURL *sourceURL;
@property(nonatomic, assign) NSTimeInterval lastLyricEnd;
@property(nonatomic, assign) BOOL timingCompatible;
@end


@interface KTLKugouLocalLyricsProvider : NSObject
- (instancetype)initWithLyricsDirectory:(NSURL *)lyricsDirectory;
- (nullable KTLKugouLocalLyricsResult *)lyricsForTitle:(NSString *)title error:(NSError **)error;
- (nullable KTLKugouLocalLyricsResult *)lyricsForTitle:(NSString *)title
                                              duration:(NSTimeInterval)duration
                                                 error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
