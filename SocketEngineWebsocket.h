#import <Foundation/Foundation.h>
#import "SocketEngineSpec.h"
#import "WebSocket.h"

@protocol SocketEngineWebsocket <SocketEngineSpec, WebSocketDelegate>
@optional

- (void)sendWebSocketMessage:(NSString*) str withType:(SocketEnginePacketType)type withData:(NSArray*) datas;

- (void)probeWebSocket;

@end

@interface SocketEngineWebsocket : SocketEngineSpec <SocketEngineSpec, WebSocketDelegate>

@end
