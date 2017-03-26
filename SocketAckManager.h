#import <Foundation/Foundation.h>
#import "SocketTypes.h"

@interface SocketAck : NSObject

@property (nonatomic, assign) int ack;
@property (nonatomic, copy, nullable) AckCallback callback;

@end

@interface SocketAckManager : NSObject

@property (nonatomic, copy, nullable) NSMutableDictionary* acks ;

-(void) addAck:(int) ack callback:(AckCallback _Nullable) callback;

-(void) executeAck:(int) ack items:(NSArray *_Nullable) items onQueue:(dispatch_queue_t _Nullable) onQueue;

-(void) timeoutAck:(int) ack onQueue:(dispatch_queue_t _Nullable) onQueue;

@end
