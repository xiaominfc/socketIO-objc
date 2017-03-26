#import <Foundation/Foundation.h>
#import "SocketIOClient.h"

@class SocketIOClient;

@interface SocketAckEmitter : NSObject

@property (nonatomic, strong) SocketIOClient *socket;
@property (nonatomic, assign) int ackNum;

- (instancetype)initWithAckNum:(SocketIOClient*) socket ackNum:(int)ackNum;

- (void)with:(NSArray*) items;

@end
