#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KTLRemoteLyricsResult : NSObject
@property(nonatomic, copy) NSString *artist;
@property(nonatomic, copy) NSString *sourceName;
@property(nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *lines;
@end

typedef void (^KTLRemoteLyricsCompletion)(KTLRemoteLyricsResult * _Nullable result);

@interface KTLRemoteLyricsService : NSObject
- (void)fetchLyricsForTitle:(NSString *)title
                     artist:(NSString *)artist
                   duration:(NSTimeInterval)duration
                 completion:(KTLRemoteLyricsCompletion)completion;
@end

NS_ASSUME_NONNULL_END
