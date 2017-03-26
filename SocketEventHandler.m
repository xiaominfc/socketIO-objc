#import "SocketEventHandler.h"

@implementation SocketEventHandler : NSObject
{
    
}

- (void)executeCallback:(NSArray*) items withAck:(int) ack withSocket:(SocketIOClient*) socket{

    SocketAckEmitter *socketEmitter = [[SocketAckEmitter alloc] initWithAckNum:socket ackNum:ack];
    self.callback(items, socketEmitter);
}

@end
