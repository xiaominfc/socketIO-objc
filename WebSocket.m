#import "WebSocket.h"

static NSString *const ErrorDomain = @"WebSocket";
static dispatch_queue_t sharedWorkQueue;

@interface WSResponse : NSObject

@property(nonatomic, assign)BOOL isFin;
@property(nonatomic, assign)OpCode code;
@property(nonatomic, assign)NSInteger bytesLeft;
@property(nonatomic, assign)NSInteger frameCount;
@property(nonatomic, strong)NSMutableData *buffer;

@end

@implementation WSResponse


@end

@interface WebSocket () <NSStreamDelegate>

@property(nonatomic, strong, nonnull)NSURL *url;
@property(nonatomic, strong, null_unspecified)NSInputStream *inputStream;
@property(nonatomic, strong, null_unspecified)NSOutputStream *outputStream;
@property(nonatomic, strong, null_unspecified)NSOperationQueue *writeQueue;
@property(nonatomic, assign)BOOL isRunLoop;
@property(nonatomic, strong, nonnull)NSMutableArray *readStack;
@property(nonatomic, strong, nonnull)NSMutableArray *inputQueue;
@property(nonatomic, strong, nullable)NSData *fragBuffer;
@property(nonatomic, strong, nullable)NSArray *optProtocols;
@property(nonatomic, assign)BOOL isCreated;
@property(nonatomic, assign)BOOL didDisconnect;
@property(nonatomic, assign)BOOL certValidated;
@property(nonatomic, assign)BOOL readyToWrite;

@end

//Constant Header Values.
NS_ASSUME_NONNULL_BEGIN
static NSString *const WebsocketDidConnectNotification = @"WebsocketDidConnectNotification";
static NSString *const WebsocketDidDisconnectNotification = @"WebsocketDidDisconnectNotification";
static NSString *const WebsocketDisconnectionErrorKeyName = @"WebsocketDisconnectionErrorKeyName";

static NSString *const headerWSUpgradeName     = @"Upgrade";
static NSString *const headerWSUpgradeValue    = @"websocket";
static NSString *const headerWSHostName        = @"Host";
static NSString *const headerWSConnectionName  = @"Connection";
static NSString *const headerWSConnectionValue = @"Upgrade";
static NSString *const headerWSProtocolName    = @"Sec-WebSocket-Protocol";
static NSString *const headerWSVersionName     = @"Sec-Websocket-Version";
static NSString *const headerWSVersionValue    = @"13";
static NSString *const headerWSKeyName         = @"Sec-WebSocket-Key";
static NSString *const headerOriginName        = @"Origin";
static NSString *const headerWSAcceptName      = @"Sec-WebSocket-Accept";
NS_ASSUME_NONNULL_END

//Class Constants
static char CRLFBytes[] = {'\r', '\n', '\r', '\n'};
static int BUFFER_MAX = 4096;

// This get the correct bits out by masking the bytes of the buffer.
static const uint8_t FinMask             = 0x80;
static const uint8_t OpCodeMask          = 0x0F;
static const uint8_t RSVMask             = 0x70;
static const uint8_t MaskMask            = 0x80;
static const uint8_t PayloadLenMask      = 0x7F;
static const size_t  MaxFrameSize        = 32;

#define kHttpSwitchProtocolCode 101

@interface UnsafeBufferPointerTest:NSObject

@property(assign) int count;
@property(assign) uint8_t* baseAddress;

-(instancetype)initWithBaseAddress:(uint8_t*)baseAddress count:(int)count;

-(UnsafeBufferPointerTest*)fromOffset:(int)offset;

@end

@implementation UnsafeBufferPointerTest

-(instancetype)initWithBaseAddress:(uint8_t*)baseAddress count:(int)count
{
    self = [super init];
    if(self) {
        self.baseAddress = baseAddress;
        self.count = count;
    }
    return self;
}

-(UnsafeBufferPointerTest*)fromOffset:(int)offset{
    return [[UnsafeBufferPointerTest alloc] initWithBaseAddress:self.baseAddress + offset count:self.count - offset];
}

@end

@interface WebSocket()
@property(nonatomic,strong)UnsafeBufferPointerTest *emptyBuffer;

@property(nonatomic)CFReadStreamRef readStream;
@property(nonatomic)CFWriteStreamRef writeStream;
//@property(nonatomic, strong)CFReadStreamRef readStream;

@end


@implementation WebSocket


- (instancetype)initWithURL:(NSURL *)url protocols:(NSArray*)protocols
{
    self = [super init];
    if(self) {
        sharedWorkQueue = dispatch_queue_create("com.vluxe.starscream.websocket", nil);
        self.certValidated = NO;
        self.voipEnabled = NO;
        //self.selfSignedSSL = NO;
        self.queue = dispatch_get_main_queue();
        self.callbackQueue = dispatch_get_main_queue();
        self.url = url;
        self.origin = [url absoluteString];
        
        NSURL *hostUrl = [NSURL URLWithString:@"/" relativeToURL:url];
        if(hostUrl) {
            NSString* origin = hostUrl.absoluteString;
            self.origin = [origin substringToIndex:[origin length] - 1];
            
        }
        
        self.readStack = [NSMutableArray new];
        self.inputQueue = [NSMutableArray new];
        self.writeQueue = [NSOperationQueue new];
        self.writeQueue.maxConcurrentOperationCount = 1;
        
        self.optProtocols = protocols;
        self.emptyBuffer = [[UnsafeBufferPointerTest alloc] initWithBaseAddress:nil count:0];
    }
    
    return self;
}

- (void)connect {
    if(self.isCreated) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.queue, ^{
        weakSelf.didDisconnect = NO;
    });
    
    //everything is on a background thread.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        weakSelf.isCreated = YES;
        [weakSelf createHTTPRequest];
        weakSelf.isCreated = NO;
    });
}

- (void)disconnect{
    [self disconnect:0 closeCode:Normal ];
}

- (void)disconnect:(NSTimeInterval) forceTimeout closeCode:(UInt16) closeCode  {
    
    if( forceTimeout > 0 ){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, forceTimeout * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self disconnectStream:nil];
        });
    } else if ( forceTimeout == 0 ){
         [self writeError:Normal];
    }
    [self disconnectStream:nil];
}

- (void)writeString:(NSString*)string {
    if(string) {
        [self dequeueWrite:[string dataUsingEncoding:NSUTF8StringEncoding]
                  code:TextFrame];
    }
}

- (void)writePing:(NSData*)data {
    [self dequeueWrite:data code:OpPing];
}

- (void)writeData:(NSData*)data {
    [self dequeueWrite:data code:BinaryFrame];
}

- (void) createHTTPRequest {
    CFURLRef url = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)self.url.absoluteString, NULL);
    CFStringRef requestMethod = CFSTR("GET");
    CFHTTPMessageRef urlRequest = CFHTTPMessageCreateRequest(kCFAllocatorDefault,
                                                             requestMethod,
                                                             url,
                                                             kCFHTTPVersion1_1);
    CFRelease(url);
    
    NSNumber *port = _url.port;
    if (!port) {
        if([self.url.scheme isEqualToString:@"wss"] || [self.url.scheme isEqualToString:@"https"]){
            port = @(443);
        } else {
            port = @(80);
        }
    }
    NSString *protocols = nil;
    if([self.optProtocols count] > 0) {
        protocols = [self.optProtocols componentsJoinedByString:@","];
    }
    [self addHeader:urlRequest key:headerWSUpgradeName val:headerWSUpgradeValue];
    [self addHeader:urlRequest key:headerWSConnectionName val:headerWSConnectionValue];
    if (protocols.length > 0) {
        [self addHeader:urlRequest key:headerWSProtocolName val:protocols];
    }
    [self addHeader:urlRequest key:headerWSVersionName val:headerWSVersionValue];
    [self addHeader:urlRequest key:headerWSKeyName val:[self generateWebSocketKey]];
    
    if( self.origin != nil ){
        [self addHeader:urlRequest key:headerOriginName val:[self origin]];
    }
    
    [self addHeader:urlRequest key:headerWSHostName val:[NSString stringWithFormat:@"%@:%@",self.url.host,port]];
    for(NSString *key in self.headers) {
        [self addHeader:urlRequest key:key val:self.headers[key]];
    }
    
    NSData *serializedRequest = (__bridge_transfer NSData *)(CFHTTPMessageCopySerializedMessage(urlRequest));
    [self initStreamsWithData:serializedRequest port:port];
    CFRelease(urlRequest);
}

-(void) addHeader:(CFHTTPMessageRef) urlRequset key:(NSString *)key val:(NSString *)val {
    CFHTTPMessageSetHeaderFieldValue(urlRequset, (__bridge CFStringRef)key, (__bridge CFStringRef)val);
}

/////////////////////////////////////////////////////////////////////////////
//Random String of 16 lowercase chars, SHA1 and base64 encoded.
- (NSString*)generateWebSocketKey {
    NSInteger seed = 16;
    NSMutableString *string = [NSMutableString stringWithCapacity:seed];
    for (int i = 0; i < seed; i++) {
        [string appendFormat:@"%C", (unichar)('a' + arc4random_uniform(25))];
    }
    return [[string dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
}

/////////////////////////////////////////////////////////////////////////////
//Sets up our reader/writer for the TCP stream.
- (void)initStreamsWithData:(NSData*)data port:(NSNumber*)port {
    //CFReadStreamRef readStream = NULL;
    //CFWriteStreamRef writeStream = NULL;
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)self.url.host, [port intValue], &_readStream, &_writeStream);
    
    self.inputStream = (__bridge_transfer NSInputStream *)_readStream;
    self.inputStream.delegate = self;
    self.outputStream = (__bridge_transfer NSOutputStream *)_writeStream;
    self.outputStream.delegate = self;
    if([self.url.scheme isEqualToString:@"wss"] || [self.url.scheme isEqualToString:@"https"]) {
        [self.inputStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL forKey:NSStreamSocketSecurityLevelKey];
        [self.outputStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL forKey:NSStreamSocketSecurityLevelKey];
    
        if(self.disableSSLCertValidation) {
            NSString *chain = (__bridge_transfer NSString *)kCFStreamSSLValidatesCertificateChain;
            NSString *peerName = (__bridge_transfer NSString *)kCFStreamSSLPeerName;
            NSString *key = (__bridge_transfer NSString *)kCFStreamPropertySSLSettings;
            NSDictionary *settings = @{chain: [[NSNumber alloc] initWithBool:NO],
                                       peerName: [NSNull null]};
            [self.inputStream setProperty:settings forKey:key];
            [self.outputStream setProperty:settings forKey:key];
        }
        
    } else {
        self.certValidated = YES; //not a https session, so no need to check SSL pinning
    }

    if(self.voipEnabled) {
        [self.inputStream setProperty:NSStreamNetworkServiceTypeVoIP forKey:NSStreamNetworkServiceType];
        [self.outputStream setProperty:NSStreamNetworkServiceTypeVoIP forKey:NSStreamNetworkServiceType];
    }
    
    self.isRunLoop = YES;
    _readyToWrite = YES;
    
    CFReadStreamSetDispatchQueue(_readStream, sharedWorkQueue);
    CFWriteStreamSetDispatchQueue(_writeStream, sharedWorkQueue);
    
    //[self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    //[self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    
    [self.inputStream open];
    [self.outputStream open];
    
    
    
    NSBlockOperation *operation = [NSBlockOperation new];
    
    __weak typeof(operation) sOperation = operation;
    
    [operation addExecutionBlock:^{
        int timeout = 5 * 1000000;
        while(!_outputStream.hasSpaceAvailable && !sOperation.isCancelled) {
            usleep(100);
            if(sOperation.isCancelled) {
                return;
            }
            timeout -= 100;
            if(timeout < 0) {
                [self cleanupStream];
                [self doDisconnect:[self errorWithDetail:@"write time out" code:2]];
                return;
            }else if(_outputStream.streamError != NULL){
                return;
            }
        }
        if(sOperation.isCancelled) {
            return;
        }
        
        size_t dataLen = [data length];
        [self.outputStream write:[data bytes] maxLength:dataLen];
    }];
    [_writeQueue addOperation:operation];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    if(self.security && !self.certValidated && (eventCode == NSStreamEventHasBytesAvailable || eventCode == NSStreamEventHasSpaceAvailable)) {
        SecTrustRef trust = (__bridge SecTrustRef)([aStream propertyForKey:(__bridge_transfer NSString *)kCFStreamPropertySSLPeerTrust]);
        NSString *domain = [aStream propertyForKey:(__bridge_transfer NSString *)kCFStreamSSLPeerName];
        if([self.security isValid:trust domain:domain]) {
            self.certValidated = YES;
        } else {
            [self disconnectStream:[self errorWithDetail:@"Invalid SSL certificate" code:1]];
            return;
        }
    }
    switch (eventCode) {
        case NSStreamEventNone:
            break;
            
        case NSStreamEventOpenCompleted:
            break;
            
        case NSStreamEventHasBytesAvailable:
            if(aStream == self.inputStream) {
                [self processInputStream];
            }
            break;
            
        case NSStreamEventHasSpaceAvailable:
            break;
            
        case NSStreamEventErrorOccurred:
            [self disconnectStream:[aStream streamError]];
            break;
            
        case NSStreamEventEndEncountered:
            [self disconnectStream:nil];
            break;
            
        default:
            break;
    }
}

- (void)disconnectStream:(NSError*)error {
    NSLog(@"disconnectStream:%@",[error description]);
    if ( error == nil ) {
        [self.writeQueue waitUntilAllOperationsAreFinished];
    } else {
        [self.writeQueue cancelAllOperations];
    }
    [self cleanupStream];
    [self doDisconnect:error];
}

- (void)cleanupStream {
    NSLog(@"cleanupStream");
    
    if(_readStream) {
        CFReadStreamSetDispatchQueue(_readStream, nil);
    }
    
    if(_writeStream) {
        CFWriteStreamSetDispatchQueue(_writeStream, nil);
    }
    
    //[self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    //[self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self.outputStream close];
    [self.inputStream close];
    self.outputStream = nil;
    self.inputStream = nil;
    self.isRunLoop = NO;
    _isConnected = NO;
    self.certValidated = NO;
}

- (void)processInputStream {
    @autoreleasepool {
        uint8_t buffer[BUFFER_MAX];
        NSInteger length = [self.inputStream read:buffer maxLength:BUFFER_MAX];
        if(length > 0) {
            BOOL process = NO;
            if(self.inputQueue.count == 0) {
                process = YES;
            }
            [self.inputQueue addObject:[NSData dataWithBytes:buffer length:length]];
            if  (process) {
                [self dequeueInput];
            }
        }
    }
}

- (void)dequeueInput {
    while(self.inputQueue.count > 0) {
        NSData *data = [self.inputQueue objectAtIndex:0];
        NSData *work = data;
        if(self.fragBuffer) {
            NSMutableData *combine = [NSMutableData dataWithData:self.fragBuffer];
            [combine appendData:data];
            work = combine;
            self.fragBuffer = nil;
        }
        if(!self.isConnected) {
            //CFIndex responseStatusCode;
             // TODO
            //[self processTCPHandshake:(uint8_t*)work.bytes length:work.length responseStatusCode:&responseStatusCode];
            [self processTCPHandshake:(uint8_t*)work.bytes length:work.length];
        } else {
             // TODO
            [self processRawMessage:(uint8_t*)work.bytes length:work.length];
        }
        [self.inputQueue removeObject:data];
    }
}

- (void) processTCPHandshake:(uint8_t*)buffer length:(NSInteger)bufferLen {
    long code = [self processHTTP:buffer length:bufferLen];
    
    switch (code) {
        case 0:
            break;
        case -1:
            _fragBuffer = [[NSData alloc] initWithBytes:buffer length:bufferLen];
            break;
        default:
            [self doDisconnect:[self errorWithDetail:@"Invalid HTTP upgrade" code:code]];
            break;
    }
}

/////////////////////////////////////////////////////////////////////////////
//Finds the HTTP Packet in the TCP stream, by looking for the CRLF.
- (long)processHTTP:(uint8_t*)buffer length:(NSInteger)bufferLen {
    int k = 0;
    NSInteger totalSize = 0;
    for(int i = 0; i < bufferLen; i++) {
        if(buffer[i] == CRLFBytes[k]) {
            k++;
            if(k == 3) {
                totalSize = i + 1;
                break;
            }
        } else {
            k = 0;
        }
    }
    if(totalSize > 0) {
        long status = [self validateResponse:buffer length:totalSize];
        if(status != 0) {
            return status;
        }
        _isConnected = YES;
        dispatch_sync(self.callbackQueue, ^{
            [self onConnect];
            if(self.delegate) {
                [self.delegate websocketDidConnect:self];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:WebsocketDidConnectNotification object:self];
        });

        
            totalSize += 1; //skip the last \n
            NSInteger  restSize = bufferLen-totalSize;
            if(restSize > 0) {
                // TODO
                 [self processRawMessage:(buffer+totalSize) length:restSize];
            }
        return status;
    }
    return -1;
}




-(void) processRawMessage:(uint8_t*)pointer length:(NSInteger)bufferLen{
    UnsafeBufferPointerTest *buffer = [[UnsafeBufferPointerTest alloc] initWithBaseAddress:pointer count:bufferLen];
    do {
        buffer = [self processOneRawMessage:buffer];
    } while (buffer.count >= 2);
    
    
    if (buffer.count > 0) {
        _fragBuffer = [[NSData alloc] initWithBytes:buffer.baseAddress length:buffer.count];
        //fragBuffer = Data(buffer: buffer)
    }
}

-(BOOL)canDispatch
{
    return _readyToWrite;
}

-(BOOL)processResponse : (WSResponse*)response{
    if (response.isFin && response.bytesLeft <= 0 ){
        if (response.code == OpPing ){
            NSData* data = response.buffer; // local copy so it is perverse for writing
            [self dequeueWrite:data code:OpPong];
        } else if (response.code == TextFrame){
            
            NSString *str = [[NSString alloc] initWithData:response.buffer encoding:NSUTF8StringEncoding];
            //let str: NSString? = NSString(data: response.buffer! as Data, encoding: String.Encoding.utf8.rawValue)
            if( str == nil ){
                [self writeError:Encoding];
                return false;
            }
            if (self.canDispatch){
                
                
                __weak typeof(self) weakSelf = self;
               
                dispatch_sync(_callbackQueue, ^{
                    if(weakSelf.onText) {
                        weakSelf.onText(str);
                    }
                    
                    if(weakSelf.delegate) {
                        [weakSelf.delegate websocket:weakSelf didReceiveMessage:str];
                    }
                });
            }
        } else if (response.code == BinaryFrame){
            if ([self canDispatch ]) {
                
                NSData* data = response.buffer;// local copy so it is perverse for writing
                
                __weak typeof(self) weakSelf = self;
                
                dispatch_sync(_callbackQueue, ^{
                    if(weakSelf.onData) {
                        weakSelf.onData(data);
                    }
                    if(weakSelf.delegate) {
                        [weakSelf.delegate websocket:weakSelf didReceiveData:data];
                    }
                });
            }
        }
        
        [_readStack removeLastObject];
        return YES;
    }
    return NO;
}


+(uint16_t)readUint16: (uint8_t*)buffer  offset:(int)offset{
    uint16_t value = (buffer[offset + 0] << 8) | buffer[offset + 1];
    return value;
}

/**
 Read a 64 bit big endian value from a buffer
 */
+(uint64_t)readUint64:(uint8_t*) buffer offset:(int) offset{
    uint64_t value = 0;
    
    for(int i = 0 ; i < 8 ;i ++) {
        value = (value << 8) | (buffer[offset + i]);
    }
    return value;
}

/**
 Write a 16-bit big endian value to a buffer.
 */
+(void)writeUint16:(uint8_t*)buffer  offset:(int)offset value: (uint16_t) value {
    buffer[offset + 0] = value >> 8;
    buffer[offset + 1] = value & 0xff;
}

/**
 Write a 64-bit big endian value to a buffer.
 */
+(void)writeUint64:(uint8_t*)buffer  offset:(int)offset value: (uint64_t) value{
    for(int i = 0 ; i < 8 ; i++)  {
        buffer[offset + i] = (value >> (8*(7 - i))) & 0xff;
    }
}




-(UnsafeBufferPointerTest*) processOneRawMessage:(UnsafeBufferPointerTest*) buffer {
    
    WSResponse* response = [_readStack lastObject];
    
    
    if(!buffer.baseAddress) {
        return self.emptyBuffer;
    }
    
    //guard let baseAddress = buffer.baseAddress else {return emptyBuffer}
    
    uint8_t* baseAddress = buffer.baseAddress;
    int bufferLen = buffer.count;
    if (response != nil && bufferLen < 2) {
        _fragBuffer = [[NSData alloc] initWithBytes:buffer.baseAddress length:buffer.count];
        //fragBuffer = Data(buffer: buffer)
        return _emptyBuffer;
    }
    
    if(response && response.bytesLeft > 0) {
        NSInteger len = response.bytesLeft;
        NSInteger extra = bufferLen - response.bytesLeft;
        if (response.bytesLeft > bufferLen) {
            len = bufferLen;
            extra = 0;
        }
        response.bytesLeft -= len;
        //response.buffer.append(Data(bytes: baseAddress, count: len))
        //[response.buffer appendData:[[NSData alloc] initWithBytes:baseAddress length:len]];
        [response.buffer appendData:[[NSData alloc] initWithBytes:baseAddress length:len]];
        [self processResponse:response];
    
         return [buffer fromOffset:(bufferLen - extra)];
    }else {
        int isFin = (FinMask & baseAddress[0]);
        int  receivedOpcode = OpCodeMask & baseAddress[0];
        int isMasked = (MaskMask & baseAddress[1]);
        int payloadLen = (PayloadLenMask & baseAddress[1]);
        int offset = 2;
        if ((isMasked > 0 || (RSVMask & baseAddress[0]) > 0) && receivedOpcode != OpPong) {
            CloseCode errCode = ProtocolError;
            [self doDisconnect:[self errorWithDetail:@"masked and rsv data is not currently supported" code:errCode]];
            [self writeError:errCode];
            return _emptyBuffer;
        }
        BOOL isControlFrame = (receivedOpcode == ConnectionClose || receivedOpcode == OpPing);
        if(!isControlFrame && (receivedOpcode != BinaryFrame && receivedOpcode != OpContinueFrame &&
                               receivedOpcode != TextFrame && receivedOpcode != OpPong)){
            CloseCode errCode = ProtocolError;
            [self doDisconnect:[self errorWithDetail:@"unknown opcode: \(receivedOpcode)" code:errCode]];
            [self writeError:errCode];
            return _emptyBuffer;
        }
        if (isControlFrame && isFin == 0 ){
            CloseCode errCode = ProtocolError;
            [self doDisconnect:[self errorWithDetail:@"control frames can't be fragmented" code:errCode]];
            [self writeError:errCode];
            return _emptyBuffer;
        }
        CloseCode closeCode = Normal;
        if (receivedOpcode == ConnectionClose){
            if (payloadLen == 1 ){
                closeCode = ProtocolError;
            } else if (payloadLen > 1 ){
                closeCode = [WebSocket readUint16:baseAddress offset:offset];
                if (closeCode < 1000 || (closeCode > 1003 && closeCode < 1007) || (closeCode > 1011 && closeCode < 3000) ){
                    closeCode = ProtocolError;
                }
            }
            if( payloadLen < 2 ){
                
                [self doDisconnect:[self errorWithDetail:@"connection closed by server" code:closeCode]];
                [self writeError:closeCode];
                return _emptyBuffer;
            }
        } else if(isControlFrame && payloadLen > 125 ){
            [self writeError:ProtocolError];
            return _emptyBuffer;
        }
        int64_t dataLength = payloadLen;
        if (dataLength == 127 ){
            dataLength = [WebSocket readUint64:baseAddress offset: offset];
            offset += sizeof(uint64_t);
        } else if (dataLength == 126 ){
            dataLength = (uint16_t) [WebSocket readUint16:baseAddress offset: offset];
            offset += sizeof(uint16_t);
        }
        if (bufferLen < offset || (bufferLen - offset) < dataLength ){
            _fragBuffer = [[NSData alloc] initWithBytes:baseAddress length:bufferLen];
            return _emptyBuffer;
        }
        int64_t len = dataLength;
        if (dataLength > bufferLen) {
            len = bufferLen-offset;
        }
        NSData *data;
        if(len < 0){
            len = 0;
            data = [NSData new];
        } else {
            if (receivedOpcode == ConnectionClose && len > 0 ){
                int  size =sizeof(uint16_t);
                offset += size;
                len -= (size);
            }
            data = [[NSData alloc] initWithBytes:baseAddress+offset length:len];
            
        }
        if (receivedOpcode == ConnectionClose){
            NSString* closeReason = @"connection closed by server";
            
            if(data) {
                closeReason = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            }else {
                closeCode = ProtocolError;
            }
            
            [self doDisconnect:[self errorWithDetail:closeReason code:closeCode]];
            [self writeError:closeCode];
            return _emptyBuffer;
        }
        if(receivedOpcode == OpPong){
            if ([self canDispatch ]) {
                __weak typeof(self) weakSelf = self;
                dispatch_sync(_callbackQueue, ^{
                    
                    NSData *pongData = nil;
                    if(data.length > 0) {
                        pongData = data;
                    }
                    weakSelf.onPong(pongData);
                    if(weakSelf.pongDelegate) {
                        [weakSelf.pongDelegate websocket:weakSelf didReceivePong:pongData];
                    }
                });
                
            }
            
            return [buffer fromOffset:offset + len];
        }
        
        
        
        WSResponse *response = [_readStack lastObject];
        if (isControlFrame ){
            response = nil; // Don't append pings.
        }
        if( isFin == 0 && receivedOpcode == OpContinueFrame && response == nil ){
            
            
            CloseCode errCode = ProtocolError;
            [self doDisconnect:[self errorWithDetail:@"continue frame before a binary or text frame" code:errCode]];
            [self writeError:errCode];
            return _emptyBuffer;
        }
        BOOL isNew = NO;
        if (!response) {
            if (receivedOpcode == OpContinueFrame){
                CloseCode errCode = ProtocolError;
                [self doDisconnect:[self errorWithDetail:@"first frame can't be a continue frame" code:errCode]];
                [self writeError:errCode];
                return _emptyBuffer;
            }
            isNew = YES;
            response = [WSResponse new];
            response.code = receivedOpcode;
            response.bytesLeft = dataLength;
            response.buffer = [[NSMutableData alloc] initWithData:data];
        } else {
            if (receivedOpcode == OpContinueFrame) {
                response.bytesLeft = dataLength;
            } else {
                CloseCode errCode = ProtocolError;
                [self doDisconnect:[self errorWithDetail:@"second and beyond of fragment message must be a continue frame" code:errCode]];
                [self writeError:errCode];
                return _emptyBuffer;
            }
            [response.buffer appendData:data];
        }
        if (response) {
            response.bytesLeft -= len;
            response.frameCount += 1;
            response.isFin = isFin > 0 ? YES : NO;
            if (isNew) {
                [_readStack addObject:response];
            }
            [self processResponse:response];
        }
        
        int step = offset + len;
        return [buffer fromOffset:step];
    }
}




//Validate the HTTP is a 101, as per the RFC spec.
- (long)validateResponse:(uint8_t *)buffer length:(NSInteger)bufferLen {
    CFHTTPMessageRef response = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, NO);
    CFHTTPMessageAppendBytes(response, buffer, bufferLen);
    CFIndex responseStatusCode = CFHTTPMessageGetResponseStatusCode(response);
    
    if(responseStatusCode != kHttpSwitchProtocolCode) {
        CFRelease(response);
        return responseStatusCode;
    }
    
    NSDictionary *headers = (__bridge_transfer NSDictionary *)(CFHTTPMessageCopyAllHeaderFields(response));
    NSString *acceptKey = headers[headerWSAcceptName];
    CFRelease(response);
    if(acceptKey.length > 0) {
        return 0;
    }
    return -1;
}

-(void)dequeueWrite:(NSData*)data code:(OpCode)code {
    if(!self.isConnected) {
        return;
    }
    if(!self.writeQueue) {
        self.writeQueue = [[NSOperationQueue alloc] init];
        self.writeQueue.maxConcurrentOperationCount = 1;
    }
    
    __weak typeof(self) weakSelf = self;
    [self.writeQueue addOperationWithBlock:^{
        if(!weakSelf || !weakSelf.isConnected) {
            return;
        }
        typeof(weakSelf) strongSelf = weakSelf;
        uint64_t offset = 2; //how many bytes do we need to skip for the header
        uint8_t *bytes = (uint8_t*)[data bytes];
        uint64_t dataLength = data.length;
        NSMutableData *frame = [[NSMutableData alloc] initWithLength:(NSInteger)(dataLength + MaxFrameSize)];
        uint8_t *buffer = (uint8_t*)[frame mutableBytes];
        buffer[0] = FinMask | code;
        if(dataLength < 126) {
            buffer[1] |= dataLength;
        } else if(dataLength <= UINT16_MAX) {
            buffer[1] |= 126;
            *((uint16_t *)(buffer + offset)) = CFSwapInt16BigToHost((uint16_t)dataLength);
            offset += sizeof(uint16_t);
        } else {
            buffer[1] |= 127;
            *((uint64_t *)(buffer + offset)) = CFSwapInt64BigToHost((uint64_t)dataLength);
            offset += sizeof(uint64_t);
        }
        BOOL isMask = YES;
        if(isMask) {
            buffer[1] |= MaskMask;
            uint8_t *maskKey = (buffer + offset);
            int secRan = SecRandomCopyBytes(kSecRandomDefault, sizeof(uint32_t), (uint8_t *)maskKey);
            offset += sizeof(uint32_t);
            
            for (size_t i = 0; i < dataLength; i++) {
                buffer[offset] = bytes[i] ^ maskKey[i % sizeof(uint32_t)];
                offset += 1;
            }
        } else {
            for(size_t i = 0; i < dataLength; i++) {
                buffer[offset] = bytes[i];
                offset += 1;
            }
        }
        uint64_t total = 0;
        while (true) {
            if(!strongSelf.isConnected || !strongSelf.outputStream) {
                break;
            }
            NSInteger len = [strongSelf.outputStream write:([frame bytes]+total) maxLength:(NSInteger)(offset-total)];
            if(len < 0 || len == NSNotFound) {
                NSError *error = strongSelf.outputStream.streamError;
                if(!error) {
                    error = [strongSelf errorWithDetail:@"output stream error during write" code:OutputStreamWriteError];
                }
                [strongSelf doDisconnect:error];
                break;
            } else {
                total += len;
            }
            if(total >= offset) {
                break;
            }
        }
    }];
}

- (void)doDisconnect:(NSError*)error {
    if(!self.didDisconnect) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(self.queue, ^{
            weakSelf.didDisconnect = YES;
            [weakSelf disconnect];
            if([weakSelf.delegate respondsToSelector:@selector(websocketDidDisconnect:error:)]) {
                [weakSelf.delegate websocketDidDisconnect:weakSelf error:error];
            }
            if(weakSelf.onDisconnect) {
                weakSelf.onDisconnect(error);
            }
        });
    }
}

- (NSError*)errorWithDetail:(NSString*)detail code:(NSInteger)code
{
    return [self errorWithDetail:detail code:code userInfo:nil];
}

- (NSError*)errorWithDetail:(NSString*)detail code:(NSInteger)code userInfo:(NSDictionary *)userInfo
{
    NSMutableDictionary* details = [NSMutableDictionary dictionary];
    details[detail] = NSLocalizedDescriptionKey;
    if (userInfo) {
        [details addEntriesFromDictionary:userInfo];
    }
    return [[NSError alloc] initWithDomain:ErrorDomain code:code userInfo:details];
}

- (void)writeError:(uint16_t)code {
    uint16_t buffer[1];
    buffer[0] = CFSwapInt16BigToHost(code);
    [self dequeueWrite:[NSData dataWithBytes:buffer length:sizeof(uint16_t)] code:ConnectionClose];
}

- (void)dealloc {
    if(self.isConnected) {
        [self disconnect];
    }
}

@end
