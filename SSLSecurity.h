#import <Foundation/Foundation.h>
#import <Security/Security.h>


@interface SSLCert : NSObject

@property (nonatomic, copy) NSData *certData;
@property (nonatomic) SecKeyRef key;

- (instancetype)initWithData:(NSData *)data;

- (instancetype)initWithKey:(SecKeyRef)key;

@end

@interface SSLSecurity : NSObject

@property(nonatomic)BOOL isReady; //is the key processing done?
@property(nonatomic, strong)NSMutableArray *certificates;
@property(nonatomic, strong)NSMutableArray *pubKeys;
@property(nonatomic)BOOL usePublicKeys;

- (instancetype)initWithCerts:(NSArray<SSLCert*>*)certs publicKeys:(BOOL)publicKeys;

- (instancetype)initUsingPublicKeys:(BOOL)publicKeys;

@property(nonatomic)BOOL validatedDN;

- (BOOL)isValid:(SecTrustRef)trust domain:(NSString*)domain;

@end
