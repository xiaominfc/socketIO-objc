# socketIO-objc
support socket.io 1.0 and objective-c implemention


## Objective-c Example
```objective-c
NSURL* url = [[NSURL alloc] initWithString:@"http://localhost:3007"];

SocketIOClient* socket = [[SocketIOClient alloc] initWithSocketURL:url config:@{@"log": @YES}];
[socket on:@"connect" callback:^(NSArray* data, SocketAckEmitter* ack) {
    NSLog(@"socket connected");
    [socket emit:@"room" items:@[@{@"room":@"10"}]];
    [socket send:@"initState"];

}];

[socket on:@"changePage" callback:^(id  _Nullable args, SocketAckEmitter * _Nullable ackEmitter) {
    NSLog(@"changePage");
}];

[self.socket connect];

```

## Thanks for
[0nlyoung7](https://github.com/0nlyoung7/socket.io-client-objc)
[socketio](https://github.com/socketio/socket.io-client-swift)
