//
//  BTManager.h
//  GPSLogger
//
//  Created by Aaron Parecki on 11/16/15.
//  Copyright © 2015 Aaron Parecki. All rights reserved.
//

#ifndef BTManager_h
#define BTManager_h

@import CoreBluetooth;
@import QuartzCore;

@interface BTManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

@property CBCentralManager *manager;
@property CBUUID *heartRateServiceUUID;
@property CBPeripheral *peripheral;

@property NSNumber *currentHeartRate;
@property NSDate *currentHeartRateTimestamp;

+ (BTManager *)sharedManager;
- (void)scanForBluetoothDevices;

@end

#endif /* BTManager_h */
