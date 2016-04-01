//
//  BTManager.m
//  GPSLogger
//
//  Created by Aaron Parecki on 11/16/15.
//  Copyright © 2015 Aaron Parecki. All rights reserved.
//

#import "BTManager.h"

@implementation BTManager {
    bool bluetoothEnabled;
}

+ (BTManager *)sharedManager {
    static BTManager *_instance = nil;
    
    @synchronized (self) {
        if (_instance == nil) {
            _instance = [[self alloc] init];
            _instance.manager = [[CBCentralManager alloc] initWithDelegate:_instance queue:nil];
            _instance.heartRateServiceUUID = [CBUUID UUIDWithString: @"180D"];
        }
    }
    
    return _instance;
}

- (void)scanForBluetoothDevices {
    //[self.manager scanForPeripheralsWithServices:@[self.heartRateServiceUUID] options:nil];
    NSArray <CBPeripheral *> *peripherals = [self.manager retrieveConnectedPeripheralsWithServices:@[self.heartRateServiceUUID]];
    // Connect to the first heart rate monitor
    if(peripherals.count > 0) {
        [self.manager stopScan];
        self.peripheral = peripherals[0];
        NSLog(@"Found peripheral: %@", self.peripheral);
        [self.manager connectPeripheral:self.peripheral options:nil];
    }
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connected %@", peripheral);
    peripheral.delegate = self;
    [peripheral discoverServices:@[self.heartRateServiceUUID]];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(nonnull CBPeripheral *)peripheral error:(nullable NSError *)error {
    NSLog(@"Failed to connect: %@", error);
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"Discovered %@", peripheral);
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if(central.state == CBCentralManagerStatePoweredOn) {
        NSLog(@"bluetooth enabled");
    }
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    NSLog(@"Discovered services: %@", peripheral.services);
    if(peripheral.services.count > 0) {
        [peripheral discoverCharacteristics:nil forService:peripheral.services[0]];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(nonnull CBService *)service error:(nullable NSError *)error {
    NSLog(@"discovered characteristic: %@", service.characteristics);
    for(CBCharacteristic *c in service.characteristics) {
        if([c.UUID isEqual:[CBUUID UUIDWithString:@"2A37"]]) {
            NSLog(@"Subscribing to %@", c);
            [peripheral setNotifyValue:YES forCharacteristic:c];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    [self getHeartBPMData:characteristic error:error];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSLog(@"Notification state for %@ updated %@", characteristic, error);
}

#pragma mark - CBCharacteristic helpers

// From https://developer.apple.com/library/mac/samplecode/HeartRateMonitor/Listings/HeartRateMonitor_HeartRateMonitorAppDelegate_m.html
- (void)getHeartBPMData:(CBCharacteristic *)characteristic error:(NSError *)error {

    const uint8_t *reportData = characteristic.value.bytes;
    uint16_t bpm = 0;
    if((reportData[0] & 0x01) == 0){
        bpm = reportData[1];
    } else {
        bpm = CFSwapInt16LittleToHost(*(uint16_t *)(&reportData[1]));
    }
    
    self.currentHeartRate = [NSNumber numberWithInt:bpm];
    self.currentHeartRateTimestamp = [NSDate date];
    
    NSLog(@"current heart rate %@", self.currentHeartRate);
}

@end
