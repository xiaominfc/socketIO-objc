#import <Foundation/Foundation.h>

#import "SocketEngineClient.h"
#import "SocketIOClientStatus.h"
#import "SocketParsable.h"
#import "SocketEngineSpec.h"
#import "SocketPacket.h"
#import "SocketAnyEvent.h"
#import "SocketEventHandler.h"
#import "SocketAckManager.h"
#import "SocketPacket.h"
#import "SocketEngine.h"

@class SocketEventHandler;

@interface SocketIOClient : SocketParsable<SocketEngineClient, SocketParsable>

@property (nonatomic, copy, nonnull) NSURL *socketURL;

@property (nonatomic, copy, nonnull) SocketEngine *engine;
@property (nonatomic)  SocketIOClientStatus status;

@property (nonatomic) BOOL forceNew;
//@property (nonatomic, copy, nullable) NSString *nsp;
@property (nonatomic, copy, nullable) NSMutableDictionary *config;
@property (nonatomic) BOOL reconnects;

@property (nonatomic) int reconnectWait;


@property(nonatomic, strong, nullable) dispatch_queue_t ackQueue;
@property(nonatomic, strong, nullable) dispatch_queue_t emitQueue;
@property(nonatomic, strong, nullable) dispatch_queue_t parseQueue;


@property(nonatomic, strong, nullable) void(^anyHandler)(SocketAnyEvent* _Nullable);
@property (nonatomic) int currentReconnectAttempt;

@property(nonatomic, strong, nullable) NSMutableArray<SocketEventHandler*>* handlers;
@property(nonatomic, strong, nullable) SocketAckManager *ackHandlers;

@property (nonatomic) BOOL reconnecting;
//@property (nonatomic, copy, nonnull) NSMutableArray<SocketPacket*> *waitingPackets;

@property(nonatomic) int currentAck;
@property(nonatomic, strong, nullable)dispatch_queue_t handleQueue;
@property(nonatomic) int reconnectAttempts;

- (void)emitAck:(int)ack with:(nullable NSArray*) items;
- (instancetype _Nonnull)initWithSocketURL:(NSURL *_Nonnull)url config:(NSDictionary *_Nullable)config;
-(NSUUID* _Nullable) on:(NSString* _Nullable) event callback:(NormalCallback) callback;
-(void)emit:(NSString* _Nullable) event items:(NSArray* _Nullable) items;
-(void)send:(NSString* _Nullable) message;
- (void) connect;
@end
