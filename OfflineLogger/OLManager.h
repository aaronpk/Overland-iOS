//
//  OLManager.h
//  OfflineLogger
//
//  Created by Aaron Parecki on 10/21/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

static NSString *const OLDataViewNeedsUpdateNotification = @"OLDataViewNeedsUpdateNotification";

@interface OLManager : NSObject <CLLocationManagerDelegate>

+ (OLManager *)sharedManager;

@property (strong, nonatomic, readonly) CLLocationManager *locationManager;
@property (strong, nonatomic) CLLocation *lastLocation;

- (void)startAllUpdates;
- (void)stopAllUpdates;

@end
