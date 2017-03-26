#import "SocketAckEmitter.h"

@implementation SocketAckEmitter
{
    
}

- (instancetype)initWithAckNum:(SocketIOClient*) socket ackNum:(int)ackNum{
    if(self = [super init]) {
        self.socket = socket;
        self.ackNum = ackNum;
    }
    return self;
}

-(void) with:(NSArray*) items{
    if( _ackNum == -1 ){
        return;
    }
    [self.socket emitAck:self.ackNum with:items];
}
@end
