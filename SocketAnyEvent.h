#import <Foundation/Foundation.h>

@interface SocketAnyEvent : NSObject

@property (nonatomic, copy, nullable) NSString *event;
@property (nonatomic, copy, nullable) NSArray *items;
@property (nonatomic, copy, readonly, nonnull) NSString *description;

-(instancetype _Nonnull)init:(NSString* _Nonnull) event items:(NSArray* _Nullable) items;

@end
