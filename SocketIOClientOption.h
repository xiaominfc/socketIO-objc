#import <Foundation/Foundation.h>
#import <Security/Security.h>

#import "SSLSecurity.h"

typedef NS_ENUM(NSInteger, SocketIOClientStatus) {
    NotConnected = 0,
    Disconnected = 1,
    Connecting =2,
    Connected = 3
};

@interface SocketIOClientOption : NSObject

@property (nonatomic, assign) NSInteger placeholders;

@property (nonatomic, nullable)   NSMutableDictionary *connectParams;
@property (nonatomic, strong)   NSMutableDictionary *cookies;
@property (nonatomic, assign) BOOL doubleEncodeUTF8;
@property (nonatomic, copy)   NSMutableDictionary *extraHeaders;
@property (nonatomic, assign) BOOL forceNew;
@property (nonatomic, assign) BOOL forcePolling;
@property (nonatomic, assign) BOOL forceWebsockets;

//@property (nonatomic, assign) DispatchQueue handleQueue;

@property (nonatomic, assign) BOOL log;

@property (nonatomic, copy)   NSString *nsp;
@property (nonatomic, copy)   NSString *path;
@property (nonatomic, assign) BOOL reconnects;
@property (nonatomic, assign) NSInteger reconnectAttempts;
@property (nonatomic, assign) NSInteger reconnectWait;

@property (nonatomic, assign) BOOL secure;
@property (nonatomic, copy) SSLSecurity *security;
@property (nonatomic, assign) BOOL selfSigned;

@property(nonatomic,weak, nullable)id<NSURLSessionDelegate> sessionDelegate;


@property (nonatomic, assign) BOOL voipEnabled;

@end
