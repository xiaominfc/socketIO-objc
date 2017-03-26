#import <Foundation/Foundation.h>

@protocol SocketEngineClient <NSObject>

- (void) engineDidError:(NSString*) reason;
- (void) engineDidClose:(NSString*) reason;
- (void) engineDidOpen:(NSString*) reason;
- (void) parseEngineMessage:(NSString*) _msg;
- (void) parseEngineBinaryData:(NSData*) data;

@end

