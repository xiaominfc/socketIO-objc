#import <Foundation/Foundation.h>
#import "SocketIOClientSpec.h"

@protocol SocketParsable <NSObject>

@optional
- (BOOL) isStringEmpty:(NSString *)string;
- (void) parseBinaryData:(NSData*) data;
- (void) parseSocketMessage:(NSString*) message;

@end

@interface SocketParsable : SocketIOClientSpec <SocketIOClientSpec, SocketParsable>

@end
