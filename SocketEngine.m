#import <Foundation/Foundation.h>
#import "SocketEngine.h"
#import "SocketEnginePacketType.h"
#import "SocketTypes.h"
#import "SocketStringReader.h"

@implementation SocketEngine
{
    
}

@synthesize invalidated;
@synthesize session;

@synthesize sessionDelegate;

@synthesize url;

@synthesize pingInterval;
//@synthesize pingTimeout;

@synthesize probeWait;

//@synthesize urlPollingWithSid;


@synthesize pongsMissed;
@synthesize pongsMissedMax;

@synthesize secure;
@synthesize security;
@synthesize selfSigned;
@synthesize voipEnabled;



-(void) setPingTimeout:(double)pingTimeout{
    _pingTimeout = pingTimeout;
    
    if( self.pingInterval == 0 ){
        self.pingInterval = 25;
    }
    
    self.pongsMissedMax = (int) ( pingTimeout / self.pingInterval );
}

-(instancetype)init {
    self = [super init];
    if(self) {
        self.socketPath = @"/engine.io/";
        self.pingTimeout = 0.0;
        //self.pongsMissedMax = pingTimeout / (pingInterval ?? 25);
        self.secure = NO;
        self.pongsMissed = 0;
        self.probing = NO;
        self.extraHeaders = [NSMutableDictionary new];
        self.polling = YES;
        self.invalidated = NO;
        self.forceWebsockets = NO;
        self.forcePolling = NO;
        self.doubleEncodeUTF8 = NO;
        self.fastUpgrade = NO;
        self.selfSigned = NO;
        self.voipEnabled = NO;
        self.probeWait = [ProbeWaitQueue new];
        self.postWait = [NSMutableArray new];
        self.closed = YES;
        [self stopPolling];
        
        self.parseQueue = dispatch_queue_create("com.socketio.engineParseQueue", nil);
        self.handleQueue = dispatch_queue_create("com.socketio.engineHandleQueue", nil);
        self.emitQueue = dispatch_queue_create("com.socketio.engineEmitQueue", nil);
    }
    return self;
}

-(instancetype) initWithOption:(id<SocketEngineClient>) client url:(NSURL*) url config:(NSMutableDictionary*) config{
    self = [self init];
    if(self) {
        self.client = client;
        self.url = url;
        sessionDelegate = self;
        
        
        for( NSString* key in config ){
            /*
             if( [config[key] isEqual:@"ConnectParams"] ){
             
             }
             */
            if([@"path" isEqualToString:key]) {
                self.socketPath = config[key];
            }else if([@"forcePolling" isEqualToString:key]) {
                self.forcePolling = [config[key] boolValue];
            }else if([@"secure" isEqualToString:key]) {
                self.secure = [config[key] boolValue];
            }else if([@"enable" isEqualToString:key]) {
                self.voipEnabled = [config[key] boolValue];
            }
            
        }
        [self createURLs];
      
    }
    return self;
}

-(void)createURLs
{
    NSMutableString *query = [NSMutableString new];
    NSURLComponents *urlPolling = [[NSURLComponents alloc] initWithString:self.url.absoluteString];
    NSURLComponents *urlWebSocket = [[NSURLComponents alloc] initWithString:self.url.absoluteString];
    
    if(secure) {
        urlPolling.scheme = @"https";
        urlWebSocket.scheme = @"wss";
    }else {
        urlPolling.scheme = @"http";
        urlWebSocket.scheme = @"ws";
    }
    urlPolling.path = self.socketPath;
    urlWebSocket.path = self.socketPath;
    urlWebSocket.percentEncodedQuery = [NSString stringWithFormat:@"transport=websocket%@",query];
    urlPolling.percentEncodedQuery =[NSString stringWithFormat:@"transport=polling&b64=1%@",query];
    
    self.urlPolling = urlPolling.URL;
    self.urlWebSocket = urlWebSocket.URL;
}


- (void) dealloc {
    [self setClosed:TRUE];
    [self stopPolling];
}

- (void) checkAndHandleEngineError:(NSString*) str{
    NSDictionary  *dict = [self toNSDictionary:str];
    if(dict) {
    if( dict[@"message"] ){
        [self didError:dict[@"message"]];
    }
    }else {
        if(self.client) {
            [self.client engineDidError:[NSString stringWithFormat:@"Got unknown error from server:%@",str]];
        }
    }
}


- (void) handleBase64:(NSString*) message{
    NSLog(@"handleBase64:%@",message);
    // binary in base64 string
    
    
    NSData *data = [[NSData alloc] initWithBase64EncodedString:[message substringFromIndex:2] options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    if(self.client) {
        [self.client parseEngineBinaryData:data];
    }
}

- (void) closeOutEngine:(NSString*) reason{
    NSLog(@"reason:%@",reason);
    [self setSid:@""];
    [self setClosed:TRUE];
    [self setInvalidated:TRUE];
    [self setConnected:FALSE];
    
    if( self.ws ){
        [self.ws disconnect];
        [self stopPolling];
        if( self.client ){
            [self.client engineDidClose:reason];
        }
    }
}

-(void) connect{
    if( self.connected ){
        [self disconnect:@"reconnet"];
    }
    
    [self resetEngine];
    
    if( self.forceWebsockets ){
        self.polling = NO;
        self.websocket = YES;
        
        [self createWebsocketAndConnect];
        return;
    }
    
    NSMutableURLRequest *reqPolling = [[NSMutableURLRequest alloc] initWithURL:self.urlPollingWithSid];
    
    if( self.cookies != NULL ){
        NSDictionary<NSString *, NSString *> *headers = [NSHTTPCookie requestHeaderFieldsWithCookies:self.cookies];
        reqPolling.allHTTPHeaderFields = headers;
    }
    
    if( self.extraHeaders ){
        for( NSString *headerName in self.extraHeaders ){
            [reqPolling setValue:self.extraHeaders[headerName] forHTTPHeaderField:headerName];
        }
    }
    
    [self doLongPoll:reqPolling];
    
}

-(void) createWebsocketAndConnect {
    WebSocket* ws = [[WebSocket alloc] initWithURL:self.urlWebSocketWithSid protocols:NULL];
    self.ws = ws;
    if( self.cookies != NULL ){
        NSDictionary<NSString *, NSString *> *headers = [NSHTTPCookie requestHeaderFieldsWithCookies:self.cookies];
        for( NSString *key in headers ){
            [self.ws setValue:headers[key] forKey:key];
        }
    }
    
    if( self.extraHeaders ){
        for( NSString *key in self.extraHeaders ){
            [self.ws setValue:self.extraHeaders[key] forKey:key];
        }
    }
    
   // self.ws.callbackQueue = self.handleQueue;
    self.ws.voipEnabled = self.voipEnabled;
    self.ws.delegate = self;
    self.ws.disableSSLCertValidation = self.selfSigned;
    self.ws.security = self.security;
    
    [self.ws connect];
}

- (void) didError:(NSString*) reason {
    if( self.client ){
        [self.client engineDidError:reason];
        [self disconnect:reason];
    }
}

- (void) disconnect:(NSString*) reason {
    if( !self.connected ){
        [self closeOutEngine:reason];
        return;
    }
    
    if( self.closed ){
        [self closeOutEngine:reason];
        return;
    }
    
    if( self.websocket ){
        [self sendWebSocketMessage:@"" withType:Close withData:@[]];
        [self closeOutEngine:reason];
    } else {
        [self disconnectPolling:reason];
    }
}

- (void) disconnectPolling:(NSString*) reason {
    dispatch_async(self.emitQueue ,^{
        NSString *typeStr = [NSString stringWithFormat: @"%ld", (long)Close];
        [self.postWait addObject:typeStr];
        
        NSMutableURLRequest  *req = [self createRequestForPostWithPostWait];
        [self doRequest:req callbackWith:nil];
        [self closeOutEngine:reason];
    });
}

-(void) doFastUpgrade {
    if (self.waitingForPoll){
        NSLog(@"Outstanding poll when switched to WebSockets, we'll probably disconnect soon. You should report this");
    }
    
    [self sendWebSocketMessage:@"" withType:Upgrade withData:@[]];
    [self setWebsocket:TRUE];
    [self setPolling:FALSE];
    [self setFastUpgrade:FALSE];
    [self setProbing:FALSE];
    
    [self flushProbeWait];
    
}

-(void) flushProbeWait {
    dispatch_async(self.emitQueue ,^{
        for( Probe *waiter in self.probeWait ){
            [self write:waiter.msg withType:waiter.type withData:waiter.data];
        }
        
        [self.probeWait removeAllObjects];
        
        if( self.postWait.count != 0 ){
            [self flushWaitingForPostToWebSocket];
        }
    });
}

-(void)flushWaitingForPostToWebSocket {
    if( !self.ws ){
        return;
    }
    
    for( NSString *msg in self.postWait ){
        [self.ws writeString:msg];
    }
    
    [self.postWait removeAllObjects];
}

-(void)handleClose:(NSString*) reason {
    if( self.client ){
        [self.client engineDidClose:reason];
    }
}

-(void)handleMessage:(NSString*) message {
    if( self.client ){
        [self.client parseEngineMessage:message];
    }
}

-(void)handleNOOP {
    [self doPoll];
}

-(void)handleOpen:(NSString*) openData{
    NSDictionary  *json = [self toNSDictionary:openData];
    if(!json){
        [self didError:@"Error parsing open packet"];
        return;
    }
    
    NSString *sid = json[@"sid"];
    if( sid == NULL ){
        [self didError:@"Open packet contained no sid"];
        return;
    }
    
    BOOL upgradeWs;
    
    self.sid = sid;
    self.connected = true;
    
    //NSString *upgrades = json[@"upgrades"];
    NSArray *upgrades = json[@"upgrades"];
    
    if( upgrades){
        //upgradeWs = [upgrades containsString:@"websocket"];
        upgradeWs = [upgrades containsObject:@"websocket"];
    } else {
        upgradeWs = FALSE;
    }
    
    double pingInterval = [json[@"pingInterval"] doubleValue];
    double pingTimeout = [json[@"pingTimeout"] doubleValue];
    
    if( pingInterval > 0 && pingTimeout > 0) {
        self.pingInterval = pingInterval / 1000.0;
        self.pingTimeout = pingTimeout / 1000.0;
    }
    
    if( !self.forcePolling && !self.forceWebsockets && upgradeWs ){
        [self createWebsocketAndConnect];
    }
    
    [self sendPing];
    
    if( !self.forceWebsockets ){
        [self doPoll];
    }
    
    [self.client engineDidOpen:@"Connect"];
}

- (void) handlePong:(NSString*) message{
    self.pongsMissed = 0;
    
    if( [message isEqualToString:@"3probe"] ){
        [self upgradeTransport];
    }
}

- (void) parseEngineData:(NSData*) data {
    if( self.client ){
        NSData *newData = [data subdataWithRange:NSMakeRange(1, [data length])];
        [self.client parseEngineBinaryData:newData];
    }
}

- (void) parseEngineMessage:(NSString*) message fromPolling:(BOOL) fromPolling {
    SocketStringReader *reader = [[SocketStringReader alloc] init:message];
    NSString *fixedString;
    
    if( [message hasPrefix:@"b4"] ){
        return [self handleBase64:message];
    }
    
    
    int value = reader.currentCharacter;
    if(value > 9) {
        value = value - 48;
    }
    
    if(value > Noop || value < Open) {
        value = -1;
    }
    
    
    if( value == -1 ){
        [self checkAndHandleEngineError:message];
        return;
    }
    SocketEnginePacketType type = value;

    
    if( fromPolling && type != Noop && self.doubleEncodeUTF8 ){
        fixedString = [self fixDoubleUTF8:message];
    } else {
        fixedString = message;
    }
    
    switch (type) {
            case Message:
            [self handleMessage:[fixedString substringFromIndex:1]];
            break;
            case Noop:
            [self handleNOOP];
            break;
            
            case Pong:
            [self handlePong:fixedString];
            break;
            
            case Open:
            [self handleOpen:[fixedString substringFromIndex:1]];
            break;
            
            case Close:
            [self handleClose:fixedString];
            break;
            
        default:
            break;
    }
}

- (void) resetEngine{
    
    self.closed = FALSE;
    self.connected = FALSE;
    self.fastUpgrade = FALSE;
    self.polling = TRUE;
    self.probing = FALSE;
    self.invalidated = FALSE;
    
    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
    
    self.session  = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self.sessionDelegate delegateQueue:mainQueue];
    
    self.sid = @"";
    self.waitingForPoll = FALSE;
    self.waitingForPost = FALSE;
    self.websocket = FALSE;
}

- (void) sendPing{
    if( !self.connected ) {
        return;
    }
    
    if( self.pongsMissed > self.pongsMissedMax ){
        if( self.client ){
            [self.client engineDidClose:@"Ping timeout"];
            return;
        }
    }
    
    if(self.pingInterval == 0){
        return;
    }
    
    self.pongsMissed += 1;
    [self write:@"" withType:Ping withData:@[]];
    
    
    
    
    CGFloat deadlinePlus = (CGFloat) (self.pingInterval * NSEC_PER_SEC);

    //NSLog(@"start:%llu",dispatch_time(dispatch_time_t when, <#int64_t delta#>));
    __weak typeof(self) weakSelf = self;
   
    
    //dispatch_time_t start = DISPATCH_TIME_NOW;
    
    
    dispatch_after(dispatch_time(0, deadlinePlus), dispatch_get_main_queue(), ^{
        [weakSelf sendPing];
    });
}

- (void) upgradeTransport{
    if( self.ws && self.ws.isConnected ){
        self.fastUpgrade = YES;
        [self sendPollMessage:@"" type:Noop withData:@[]];
    }
}

- (void) write:(NSString*) msg withType:(SocketEnginePacketType)type withData:(NSArray<NSData *> * _Nonnull)data{
    
    dispatch_async(self.emitQueue ,^{
        if( !self.connected ){
            return;
        }
        
        if( self.websocket ){
            [self sendWebSocketMessage:msg withType:type withData:data];
        } else if( !self.probing ){
            [self sendPollMessage:msg type:type withData:data];
        } else {
            Probe *probe = [Probe new];
            probe.msg = msg;
            probe.type = type;
            probe.data = data;
            [self.probeWait addObject:probe];
        }
    });
}


-(void)websocketDidConnect:(WebSocket*) socket{
    if( !self.forceWebsockets ){
        self.probing = true;
        [self probeWebSocket];
    } else {
        self.connected = true;
        self.probing = false;
        self.polling = false;
    }
}

-(void)websocketDidDisconnect:(WebSocket*) socket error:(NSError*) error{
    self.probing = false;
    
    if( self.closed ){
        [self.client engineDidClose:@"Socket Disconnected"];
        return;
    } else {
        [self flushProbeWait];
    }
}

-(void) URLSession:(NSURLSession*)session error:(NSError*) error{
    
    [self didError:@"Engine URLSession became invalid"];
}


- (NSDictionary*) toNSDictionary:(NSString*) str{
    
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    
    NSError *e = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData: data options: NSJSONReadingMutableContainers error: &e];
    
    if (!json) {
        NSLog(@"Error parsing JSON: %@", e);
        return nil;;
    }
    
    return json;
}
//

- (void)probeWebSocket {
    if( self.ws && self.ws.isConnected ){
        [self sendWebSocketMessage:@"probe" withType:Ping withData:@[]];
    }
}

- (void)sendWebSocketMessage:(NSString*) str withType:(SocketEnginePacketType)type withData:(NSArray*) datas{
    
    if( self.ws ){
        NSString *typeStr = [NSString stringWithFormat: @"%ld%@", (long)type,str];
        NSLog(@"string:%@" ,typeStr);
        [self.ws writeString:typeStr];
        for(NSData *data in datas){
            BinaryContainer* bc = [self createBinaryDataForSend:data];
            if( bc.data ){
                [self.ws writeData:data];
            }
        }
    }
    
   
}

-(NSString*)fixDoubleUTF8:(NSString*) string {
    
    NSData *utf8Data = [string dataUsingEncoding:NSISOLatin1StringEncoding];
    if(utf8Data) {
        string = [[NSString alloc] initWithData:utf8Data encoding:NSUTF8StringEncoding];
    }
    return string;
}

- (void)websocketDidReceiveMessage:(WebSocket*) socket text:(NSString*) text{
    [self parseEngineMessage:text fromPolling:FALSE];
}

- (void)websocketDidReceiveData:(WebSocket*) socket data:(NSData*) data{
    [self parseEngineData:data];
}

-(void)websocket:(nonnull WebSocket*)socket didReceiveMessage:(nonnull NSString*)string
{
    [self parseEngineMessage:string fromPolling:FALSE];
}

-(void)websocket:(nonnull WebSocket*)socket didReceiveData:(nullable NSData*)data
{
    [self parseEngineData:data];
}

@end
