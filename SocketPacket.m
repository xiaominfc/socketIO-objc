#import "SocketPacket.h"

#import <Foundation/Foundation.h>

@implementation SocketPacket
{
    
}

- (NSArray*) args {
    
    if (self.type == Event || (self.type == BinaryEvent && self.data.count != 0) ) {
        NSMutableArray *modifyableArray = [[NSMutableArray alloc] initWithArray:self.data];
        [modifyableArray removeObjectAtIndex:0];
        return [[NSArray alloc] initWithArray:modifyableArray];
    } else {
        return _data;
    }
    
}

- (NSString*) event
{
    return self.data[0];
}

- (NSString*) description
{
    NSString *result = [@"SocketPacket " stringByAppendingFormat:
                         @"{type: %ld; data: %@; id: %ld; placeholders: %ld; nsp: %@", (long)self.type, self.data, (long)self.id, (long)self.placeholders, self.nsp];
    return result;
}

- (NSString*) packetString
{
    return [self createPacketString];
}

- (nonnull instancetype) init:(PacketType)type nsp:(NSString *)nsp
{
    self = [super init];
    if (self) {
        self.type = type;
        self.nsp = nsp;
    }
    return self;
}


- (nonnull instancetype) init:(PacketType)type nsp:(NSString *)nsp placeholders:(NSInteger)placeholders
{
    self = [super init];
    if (self) {
        self.type = type;
        self.nsp = nsp;
        self.placeholders = placeholders;
    }
    return self;
}


- (nonnull instancetype) initWithData:(PacketType)type data:(NSArray *)data id:(NSInteger)id nsp:(NSString *)nsp
    placeholders:(NSInteger)placeholders binary:(NSData *) binary
{
    self = [super init];
    if (self) {
        self.type = type;
        self.data = data;
        self.id = id;
        self.nsp = nsp;
        self.placeholders = placeholders;
        self.binary = binary;
        
    }
    return self;
}

- (NSString*) completeMessage:(NSString*)message
{
    if ( self.data.count == 0 )
    {
        return [message stringByAppendingString:@"[]"];
    }
    
    
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.data options:NSJSONWritingPrettyPrinted error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    if( error != nil )
    {
        return [message stringByAppendingString:@"[]"];
    }

    return [message stringByAppendingString:jsonString];
}


- (NSString*) createPacketString {
    //NSString *typeString = [self packeyTypeEnumToString:self.type];
    // Binary count?
    
    NSString *typeString = [NSString stringWithFormat:@"%ld", (long)self.type];
    
    NSString *tmpString = @"";
    
    switch (self.type){
        case BinaryAck:
            tmpString = [NSString stringWithFormat:@"%lu-",self.binary.count];
            break;
        case BinaryEvent:
            tmpString = [NSString stringWithFormat:@"%lu-",self.binary.count];
            break;
        default:
            break;
    }
    
    NSString *binaryCountString = [typeString stringByAppendingString:tmpString];
    
    
    NSString *tmpString1 = @"";
    if( ![self.nsp isEqual: @"/"] ){
        tmpString1 = self.nsp;
    }
    
    NSString *tmpString2 = @"";
    if(self.id != -1){
        tmpString2 = [NSString stringWithFormat: @"%ld", (long)self.id];
    }

    // Namespace?
    NSString *nspString = [binaryCountString stringByAppendingString:tmpString1];
    // Ack number?
    NSString *idString = [nspString stringByAppendingString:tmpString2];
    
    return [self completeMessage:idString];
}



-(NSString*) packeyTypeEnumToString:(PacketType)enumVal
{
    NSArray *packetTypeArray = [[NSArray alloc] initWithObjects:kPacketTypeArray];
    return [packetTypeArray objectAtIndex:enumVal];
}

+(PacketType) findType:(int)binCount ack:(BOOL)ack {
    if( binCount == 0 && !ack ){
        return Event;
    } else if ( binCount == 0 && ack ){
        return Ack;
    } else if ( !ack ){
         return BinaryEvent;
    } else if ( ack ){
        return BinaryAck;
    } else {
        return Error;
    }
}


+(instancetype) packetFromEmit:(NSArray*) items id:(NSInteger)id nsp:(NSString*)nsp ack:(BOOL) ack {
    PacketType packetType = [self findType:0 ack:ack];
    SocketPacket *packet = [[SocketPacket alloc] initWithData:packetType data:items id:id nsp:nsp placeholders:0 binary:nil];
    return packet;
}

@end
