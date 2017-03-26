#import "SocketIOClientSpec.h"

@implementation SocketIOClientSpec
{

}

@synthesize nsp = _nsp;
@synthesize waitingPackets = _waitingPackets;

- (void) didError:(NSString*) reason {
    
    NSMutableArray *arrayout = [NSMutableArray array];
    [arrayout addObject:reason];
    
    //DefaultSocketLogger.Logger.error("%@", type: "SocketIOClient", args: reason)
    [self handleEvent:@"error" data:arrayout isInternalMessage:true withAck:-1];
}

@end
