#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PacketType) {
    Connect = 0,
    Disconnect = 1,
    Event =2,
    Ack = 3,
    Error = 4,
    BinaryEvent = 5,
    BinaryAck = 6
};

#define kPacketTypeArray @"connect", @"disconnect", @"event", @"ack", @"error", @"binaryEvent", @"binaryAck", nil

@interface SocketPacket : NSObject

@property (nonatomic, assign) NSInteger placeholders;

@property (nonatomic, strong, nonnull) NSString *nsp;
@property (nonatomic, assign) NSInteger id;
@property (nonatomic, assign) PacketType type;

@property (nonatomic, strong, nullable) NSArray<NSData*> *binary;
@property (nonatomic, strong, nullable) NSArray *data;
@property (nonatomic, strong, nullable) NSArray *args;

@property (nonatomic, strong, nullable) NSString* event;
@property (nonatomic, readonly, nonnull) NSString* description;
@property (nonatomic, readonly, nonnull) NSString* packetString;

+ (PacketType)findType:(int)binCount ack:(BOOL)ack;

- (nonnull instancetype) init:(PacketType)type nsp:(nonnull NSString *)nsp;

- (nonnull instancetype) init:(PacketType)type nsp:(nonnull NSString *)nsp placeholders:(NSInteger)placeholders;

- (nonnull instancetype) initWithData:(PacketType)type data:(nonnull NSArray*)data id:(NSInteger)id nsp:(nullable NSString *)nsp
    placeholders:(NSInteger)placeholders binary:(nullable NSData *) binary;

+ (nonnull instancetype) packetFromEmit:(nullable NSArray*) items id:(NSInteger)id nsp:(nullable NSString*)nsp ack:(BOOL) ack;

@end
