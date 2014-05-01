//
//  BPAppDelegate.m
//  BLEPeripheral
//
//  Created by Sandeep Mistry on 10/28/2013.
//  Copyright (c) 2013 Sandeep Mistry. All rights reserved.
//

#import <objc/runtime.h>
#import <objc/message.h>

#import "BPAppDelegate.h"

@interface CBXpcConnection : NSObject //{
//    <CBXpcConnectionDelegate> *_delegate;
//    NSRecursiveLock *_delegateLock;
//    NSMutableDictionary *_options;
//    NSObject<OS_dispatch_queue> *_queue;
//    int _type;
//    NSObject<OS_xpc_object> *_xpcConnection;
//    NSObject<OS_dispatch_semaphore> *_xpcSendBarrier;
//}
//
//@property <CBXpcConnectionDelegate> * delegate;

- (id)allocXpcArrayWithNSArray:(id)arg1;
- (id)allocXpcDictionaryWithNSDictionary:(id)arg1;
- (id)allocXpcMsg:(int)arg1 args:(id)arg2;
- (id)allocXpcObjectWithNSObject:(id)arg1;
- (void)checkIn;
- (void)checkOut;
- (void)dealloc;
- (id)delegate;
- (void)disconnect;
- (void)handleConnectionEvent:(id)arg1;
- (void)handleInvalid;
- (void)handleMsg:(int)arg1 args:(id)arg2;
- (void)handleReset;
- (id)initWithDelegate:(id)arg1 queue:(id)arg2 options:(id)arg3 sessionType:(int)arg4;
- (BOOL)isMainQueue;
- (id)nsArrayWithXpcArray:(id)arg1;
- (id)nsDictionaryFromXpcDictionary:(id)arg1;
- (id)nsObjectWithXpcObject:(id)arg1;
- (void)sendAsyncMsg:(int)arg1 args:(id)arg2;
- (void)sendMsg:(int)arg1 args:(id)arg2;
- (id)sendSyncMsg:(int)arg1 args:(id)arg2;
- (void)setDelegate:(id)arg1;

@end

@implementation CBXpcConnection (Swizzled)

- (void)sendMsg1:(int)arg1 args:(id)arg2
{
    NSLog(@"sendMsg: %d, %@", arg1, arg2);
    
    if ([self respondsToSelector:@selector(sendMsg1:args:)]) {
        [self sendMsg1:arg1 args:arg2];
    }
}

- (void)handleMsg1:(int)arg1 args:(id)arg2
{
    NSLog(@"handleMsg: %d, %@", arg1, arg2);
    
    if ([self respondsToSelector:@selector(handleMsg1:args:)]) {
        [self handleMsg1:arg1 args:arg2];
    }
}

@end

@interface BPAppDelegate ()

@property (nonatomic, strong) CBPeripheralManager *peripheralManager;
@property (nonatomic, strong) CBMutableService *service;
@property (weak) IBOutlet NSButton *sendButton;
@property CBMutableCharacteristic* mycharac;
@end


@implementation BPAppDelegate


//#define XPC_SPY 1

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
#ifdef XPC_SPY
    // Insert code here to initialize your application
    Class xpcConnectionClass = NSClassFromString(@"CBXpcConnection");
    
    Method origSendMethod = class_getInstanceMethod(xpcConnectionClass,  @selector(sendMsg:args:));
    Method newSendMethod = class_getInstanceMethod(xpcConnectionClass, @selector(sendMsg1:args:));
    
    method_exchangeImplementations(origSendMethod, newSendMethod);
    
    Method origHandleMethod = class_getInstanceMethod(xpcConnectionClass,  @selector(handleMsg:args:));
    Method newHandleMethod = class_getInstanceMethod(xpcConnectionClass, @selector(handleMsg1:args:));
    
    method_exchangeImplementations(origHandleMethod, newHandleMethod);
#endif
    
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    NSLog(@"peripheralManagerDidUpdateState: %d", (int)peripheral.state);
    
    if (CBPeripheralManagerStatePoweredOn == peripheral.state) {
        
       
         self.mycharac = [[CBMutableCharacteristic alloc]
                                                   // init UUID of characteristics
                                                   initWithType:[CBUUID UUIDWithString:@"A254"]
                                                   // init properties of characteristic
                                                   properties:CBCharacteristicPropertyWriteWithoutResponse|CBCharacteristicPropertyRead|CBCharacteristicPropertyNotify
                                                   value:nil
                                                   permissions:CBAttributePermissionsWriteable | CBAttributePermissionsReadable];
        
        self.service = [[CBMutableService alloc]
                        // init UUID of service
                        initWithType:[CBUUID UUIDWithString:@"19CE"]
                        primary:YES];
        
        // include characeteristics into service
        self.service.characteristics = @[self.mycharac];
        
        [self.peripheralManager addService:self.service];
    } else {
        [peripheral stopAdvertising];
        [peripheral removeAllServices];
    }
}


- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
    NSLog(@"peripheralManagerDidStartAdvertising: %@", error);
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
    NSLog(@"peripheralManagerDidAddService: %@ %@", service, error);

    [peripheral startAdvertising:@{
                                   CBAdvertisementDataLocalNameKey: @"hello"
                                   }];
}


-(void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequests:(NSArray *)requests {
    NSLog(@"didReceiveReadRequest");
}



// invoke when write properties is requested
-(void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests {
    NSLog(@"didReceiveWriteRequest");
    for(CBATTRequest* req in requests){
        
        // data receive and convert NSData (req.value) to NSString
        NSString* str = [[NSString alloc]
                         initWithData:req.value
                         encoding:NSUTF8StringEncoding];
        
        NSLog(str);
        
        
        // sleep for 1 seconds
        [self performSelector:@selector(timerFireMethod:) withObject:req afterDelay:0.5];
        
    }
    
}

-(void)timerFireMethod:(CBATTRequest *)incomingReq  {
    
    
    CBATTRequest* r = [self.service.characteristics objectAtIndex:0 ];
    // change the characteristic data by assign it
    r.value = incomingReq.value;
    
    // Notify the central that data is changed.
    BOOL didSendValue = [self.peripheralManager updateValue:r.value
                                          forCharacteristic:self.mycharac
                                       onSubscribedCentrals:nil];
    
    NSLog(@"timerFireMethod %@ %i",incomingReq.characteristic.UUID, didSendValue);
}

- (IBAction)sendAction:(id)sender {
    NSLog(@"send");
}


@end
