#import <Foundation/Foundation.h>

@interface SocketStringReader : NSObject

@property (nonatomic, copy) NSString* message;
@property (nonatomic, assign) NSUInteger currentIndex;
@property (nonatomic, readonly) Boolean hasNext;
@property (nonatomic, readonly) unichar currentCharacter;

- (SocketStringReader*) init:(NSString*) message;

- (NSUInteger) advance:(NSUInteger) by __attribute__((warn_unused_result));

- (NSString*) read:(NSUInteger) count;

- (NSString*) readUntilOccurence:(NSString *) keyword;

- (int) indexOf:(NSString *) keyword;


@end
