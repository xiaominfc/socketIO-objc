#import "SocketEngineSpec.h"
#import "SocketTypes.h"

@implementation SocketEngineSpec : NSObject 
{
}



@synthesize client;
@synthesize closed;
@synthesize connected;
@synthesize connectParams;
@synthesize doubleEncodeUTF8;
@synthesize cookies;
@synthesize extraHeaders;

@synthesize fastUpgrade;
@synthesize forcePolling;
@synthesize forceWebsockets;
@synthesize parseQueue;


@synthesize polling;
@synthesize probing;

@synthesize emitQueue;
@synthesize handleQueue;

@synthesize sid;
@synthesize socketPath;
@synthesize urlPolling;
@synthesize urlWebSocket;

@synthesize urlPollingWithSid;

@synthesize websocket;
@synthesize ws;


- (NSURL*) urlPollingWithSid
{
    NSURLComponents *com = [[NSURLComponents alloc] initWithURL:self.urlPolling resolvingAgainstBaseURL:false];
    com.percentEncodedQuery = [com.percentEncodedQuery stringByAppendingString:[NSString stringWithFormat:@"&sid=%@",self.sid]];
    return com.URL;
}

- (NSURL*) urlWebSocketWithSid
{
    NSURLComponents *com = [[NSURLComponents alloc] initWithURL:self.urlWebSocket resolvingAgainstBaseURL:false];
    
    NSCharacterSet *set = [NSCharacterSet URLHostAllowedCharacterSet];
    NSString *urlEncoded = [self.sid stringByAddingPercentEncodingWithAllowedCharacters:set];
    
    NSString *percentEncodedQuery;
    if ( [self.sid isEqualToString:@""]){
        percentEncodedQuery = @"";
    } else {
        percentEncodedQuery = [[com.percentEncodedQuery  stringByAppendingString:@"&sid="] stringByAppendingString:urlEncoded];
    }
    com.percentEncodedQuery = percentEncodedQuery;
    return com.URL;
}

-(BinaryContainer*) createBinaryDataForSend:(NSData*) data{
    BinaryContainer* binaryContainer = [BinaryContainer new];
    if( self.websocket ){
        
        NSMutableData *mutableData = [[NSMutableData alloc]init];
        [mutableData appendData:data];
        
        binaryContainer.data = mutableData;
        
    } else {
        NSString *str = [@"b4" stringByAppendingString:[data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength]];
        
        binaryContainer.string = str;
    }
    
    return binaryContainer;
}

-(void) send:(NSString*) msg withData:(NSArray*) datas{
    [self write:msg withType:Message withData:datas];
}

@end
