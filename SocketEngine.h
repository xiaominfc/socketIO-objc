#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SocketEnginePollable.h"
#import "SocketEngineWebsocket.h"
#import "SocketTypes.h"

@interface SocketEngine: SocketEnginePollable<SocketEnginePollable, NSURLSessionDelegate, SocketEngineWebsocket>

/*
@property (nonatomic, strong, nullable) dispatch_queue_t emitQueue;
@property (nonatomic, strong, nullable) dispatch_queue_t handleQueue;
@property (nonatomic, strong, nullable) dispatch_queue_t parseQueue;


@property (nonatomic, nullable) NSDictionary *connectParams;

@property (nonatomic, copy, nullable) NSMutableArray<NSString*> *postWait;
@property (nonatomic) BOOL waitingForPoll;
@property (nonatomic) BOOL waitingForPost;

@property (nonatomic) BOOL closed;
@property (nonatomic) BOOL connected;
@property (nonatomic, nullable) NSArray<NSHTTPCookie *> *cookies;
@property (nonatomic) BOOL doubleEncodeUTF8;
@property (nonatomic, nullable) NSDictionary *extraHeaders;
@property (nonatomic) BOOL fastUpgrade;
@property (nonatomic) BOOL forcePolling;
@property (nonatomic) BOOL forceWebsockets;

@property (nonatomic) BOOL polling;
@property (nonatomic) BOOL probing;

@property (nonatomic, nullable) NSString *sid;
@property (nonatomic, nullable, copy) NSString *socketPath;
@property (nonatomic, nullable) NSURL *urlPolling;
@property (nonatomic, nullable) NSURL *urlWebSocket;
@property (nonatomic) BOOL websocket;
@property (nonatomic, copy, nullable) WebSocket *ws;
@property (nonatomic, nullable) SocketEngineClient *client;
*/
@property (nonatomic) BOOL invalidated;
@property (nonatomic, strong, nullable) NSURLSession *session;
 
@property(nonatomic, weak, nullable)id<NSURLSessionDelegate> sessionDelegate;

@property (nonatomic, nullable) NSURL *url;

@property (nonatomic) double pingInterval;
@property (nonatomic) double pingTimeout;

@property (nonatomic, nullable) ProbeWaitQueue* probeWait;

//@property (nonatomic, readonly, nullable) NSURL *urlPollingWithSid;


@property (nonatomic) NSInteger pongsMissed;
@property (nonatomic) NSInteger pongsMissedMax;

@property (nonatomic) BOOL secure;
@property (nonatomic, nullable) SSLSecurity *security;
@property (nonatomic) BOOL selfSigned;
@property (nonatomic) BOOL voipEnabled;

-(instancetype) initWithOption:(id<SocketEngineClient>) client url:(NSURL*) url config:(NSMutableDictionary*) config;

@end
