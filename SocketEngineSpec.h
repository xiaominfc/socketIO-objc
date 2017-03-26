#import <Foundation/Foundation.h>
#import "SocketEngineClient.h"
#import "SocketEnginePacketType.h"
#import "WebSocket.h"
#import "SocketTypes.h"



@protocol SocketEngineSpec <NSObject>

@property (nonatomic, nullable, readwrite, retain) id<SocketEngineClient> client;
@property (nonatomic) BOOL closed;
@property (nonatomic, readwrite) BOOL connected;
@property (nonatomic, nullable) NSDictionary *connectParams;
@property (nonatomic) BOOL doubleEncodeUTF8;
@property (nonatomic, nullable) NSArray<NSHTTPCookie *> *cookies;
@property (nonatomic, nullable) NSDictionary *extraHeaders;

@property (nonatomic) BOOL fastUpgrade;
@property (nonatomic) BOOL forcePolling;
@property (nonatomic) BOOL forceWebsockets;
@property (nonatomic, strong, nullable) dispatch_queue_t parseQueue;


@property (nonatomic) BOOL polling;
@property (nonatomic) BOOL probing;

@property (nonatomic, strong, nullable) dispatch_queue_t emitQueue;
@property (nonatomic, strong, nullable) dispatch_queue_t handleQueue;

@property (nonatomic, nullable) NSString *sid;
@property (nonatomic, nullable, readwrite, copy) NSString *socketPath;
@property (nonatomic, nullable) NSURL *urlPolling;
@property (nonatomic, nullable) NSURL *urlWebSocket;

@property (nonatomic, readonly, nullable) NSURL *urlPollingWithSid;
@property (nonatomic, readonly, nullable) NSURL *urlWebSocketWithSid;

@property (nonatomic) BOOL websocket;
@property (nonatomic, nullable) WebSocket *ws;

@optional

-(void) send:(NSString *_Nullable) msg withData:(NSArray *_Nullable) datas;

-(BinaryContainer*) createBinaryDataForSend:(NSData *_Nullable) data;

- (void) connect;
- (void) didError:(NSString *_Nullable) reason;
- (void) disconnect:(NSString *_Nullable) reason;
- (void) doFastUpgrade;
- (void) flushWaitingForPostToWebSocket;
- (void) parseEngineData:(NSData *_Nonnull) data;
- (void) parseEngineMessage:(NSString *_Nonnull) message fromPolling:(BOOL)fromPolling;
- (void) write:(NSString *_Nonnull) msg withType:(enum SocketEnginePacketType)type withData:(NSArray<NSData*> *_Nonnull) data;
@end

@interface SocketEngineSpec : NSObject <SocketEngineSpec>

@end
