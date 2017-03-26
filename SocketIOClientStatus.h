#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SocketIOClientStatus) {
    NotConnected = 0,
    Disconnected = 1,
    Connecting = 2,
    Connected = 3
};
