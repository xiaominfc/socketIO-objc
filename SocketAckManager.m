#import "SocketAckManager.h"

@implementation SocketAck
{
    
}

- (instancetype)init:(int)ack{
    if(self = [super init]) {
        self.ack = ack;
    }
    return self;
}

- (instancetype)initWithCallback:(int)ack callback:(AckCallback)callback{
    if(self = [super init]) {
        self.ack = ack;
        self.callback = callback;
    }
    return self;
}

-(BOOL) isGreater:(SocketAck*)lhs rhs:(SocketAck*)rhs{
    return lhs.ack < rhs.ack;
}

-(BOOL) isEqual:(SocketAck*)lhs rhs:(SocketAck*)rhs{
    return lhs.ack == rhs.ack;
}


@end

@implementation SocketAckManager
{
    
}

-(instancetype) init{
    if(self = [super init]) {
        self.acks = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(void) addAck:(int) ack callback:(AckCallback) callback{
    SocketAck *socketAck = [[SocketAck alloc] initWithCallback:ack callback:callback];
    NSString *key =  [NSString stringWithFormat:@"%d",ack];
    [self.acks setObject:socketAck forKey:key];
    
}

-(void) executeAck:(int) ack items:(NSArray*) items onQueue:(dispatch_queue_t) onQueue{
    
    NSString *key =  [NSString stringWithFormat:@"%d",ack];
    SocketAck *socketAck = self.acks[key];
    
    
    dispatch_async(onQueue ,^{
        if( socketAck != NULL ){
            socketAck.callback(items);
            
            [self.acks removeObjectForKey:key];
        }
    });
}

-(void) timeoutAck:(int) ack onQueue:(dispatch_queue_t) onQueue{
    
    NSString *key =  [NSString stringWithFormat:@"%d",ack];
    SocketAck *socketAck = self.acks[key];
    
    dispatch_async(onQueue ,^{
        if( socketAck != NULL ){
            NSArray *response = @[@"NO ACK"];
            socketAck.callback(response);
            
            [self.acks removeObjectForKey:key];
        }
    });
}


@end
