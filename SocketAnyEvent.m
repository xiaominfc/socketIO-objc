#import "SocketAnyEvent.h"

@implementation SocketAnyEvent
{
    
}

- (NSString*) description
{
    return [NSString stringWithFormat:@"SocketAnyEvent: Event: %@ items: %@)", self.event, (self.items ? self.items : @"")];
}

-(instancetype)init:(NSString*) event items:(NSArray*) items{
    if(self = [super init]) {
        self.event = event;
        self.items = items;
    }
    return self;
}

@end
