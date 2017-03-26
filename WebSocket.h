#import <Foundation/Foundation.h>
#import <Security/Security.h>

#import "SSLSecurity.h"

@class WebSocket;

@protocol WebSocketDelegate <NSObject>

@optional

-(void)websocketDidDisconnect:(nonnull WebSocket*)socket error:(nullable NSError*)error;
-(void)websocketDidConnect:(nonnull WebSocket*)socket;

-(void)websocket:(nonnull WebSocket*)socket didReceiveMessage:(nonnull NSString*)string;

-(void)websocket:(nonnull WebSocket*)socket didReceiveData:(nullable NSData*)data;

@end

@protocol WebSocketPongDelegate <NSObject>

@optional
-(void)websocket:(nonnull WebSocket*)socket didReceivePong:(nullable NSData*)data;

@end

@interface WebSocket : NSObject <NSStreamDelegate>
    
typedef NS_ENUM(uint8_t, OpCode) {
    OpContinueFrame = 0x0,
    TextFrame = 0x1,
    BinaryFrame = 0x2,
    ConnectionClose = 0x8,
    OpPing = 0x8,
    OpPong = 0xA
};

typedef NS_ENUM(uint16_t, CloseCode) {
    Normal = 1000,
    GoingAway = 1001,
    ProtocolError = 1002,
    ProtocolUnhandledType = 1003,
    NoStatusReceived = 1005,
    Encoding = 1007,
    PolicyViolated = 1008,
    MessageTooBig = 1009
};

typedef NS_ENUM(uint16_t, InternalErrorCode) {
    OutputStreamWriteError = 1
};


@property(nonatomic, weak, nullable) dispatch_queue_t callbackQueue;


@property(nonatomic,weak, nullable)id<WebSocketDelegate> delegate;
@property(nonatomic,weak, nullable)id<WebSocketPongDelegate> pongDelegate;
@property(nonatomic, readonly, nonnull) NSURL *url;

- (nonnull instancetype)initWithURL:(nonnull NSURL *)url protocols:(nullable NSArray*)protocols;

- (void)connect;

- (void)disconnect;

- (void)disconnect:(NSTimeInterval) forceTimeout closeCode:(UInt16) closeCode;

- (void)writeData:(nonnull NSData*)data;

- (void)writeString:(nonnull NSString*)string;

- (void)writePing:(nonnull NSData*)data;

-(void) addHeader:(CFHTTPMessageRef) urlRequset key:(NSString *)key val:(NSString *)val;

@property(nonatomic, strong, nullable)void (^onConnect)(void);

@property(nonatomic, strong, nullable)void (^onDisconnect)(NSError*_Nullable);

@property(nonatomic, strong, nullable)void (^onText)(NSString*_Nullable);

@property(nonatomic, strong, nullable)void (^onData)(NSData*_Nullable);

@property(nonatomic, strong, nullable)void (^onPong)(NSData*_Nullable);

@property(nonatomic, strong, nullable)NSMutableDictionary *headers;
@property(nonatomic, assign) BOOL voipEnabled;
@property(nonatomic, assign) BOOL disableSSLCertValidation;
@property(nonatomic, strong, nullable)SSLSecurity *security;

@property(nonatomic, strong, nullable)NSString *origin;
@property(nonatomic, assign, readonly)BOOL isConnected;

@property(nonatomic, strong, nullable)dispatch_queue_t queue;

@end
