//
//  OLManager.h
//  OfflineLogger
//
//  Created by Aaron Parecki on 10/21/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>

static NSString *const OLNewDataNotification = @"OLNewDataNotification";
static NSString *const OLSendingStartedNotification = @"OLSendingStartedNotification";
static NSString *const OLSendingFinishedNotification = @"OLSendingFinishedNotification";

static NSString *const OLAPIEndpointDefaultsName = @"OLAPIEndpointDefaults";
static NSString *const OLLastSentDateDefaultsName = @"OLLastSentDateDefaults";
static NSString *const OLTrackingStateDefaultsName = @"OLTrackingStateDefaults";
static NSString *const OLSendIntervalDefaultsName = @"OLSendIntervalDefaults";

static int const PointsPerBatch = 200;

@interface OLManager : NSObject <CLLocationManagerDelegate>

+ (OLManager *)sharedManager;

@property (strong, nonatomic, readonly) CLLocationManager *locationManager;
@property (strong, nonatomic, readonly) CMMotionActivityManager *motionActivityManager;
@property (strong, nonatomic, readonly) CMStepCounter *stepCounter;

@property (strong, nonatomic) NSNumber *sendingInterval;

@property (readonly) BOOL trackingEnabled;
@property (readonly) BOOL sendInProgress;
@property (strong, nonatomic, readonly) CLLocation *lastLocation;
@property (strong, nonatomic, readonly) CMMotionActivity *lastMotion;
@property (strong, nonatomic, readonly) NSNumber *lastStepCount;
@property (strong, nonatomic, readonly) NSDate *lastSentDate;

- (void)startAllUpdates;
- (void)stopAllUpdates;

- (void)queryStepCount:(void(^)(NSInteger numberOfSteps, NSError *error))callback;

- (void)numberOfLocationsInQueue:(void(^)(long num))callback;
- (void)sendQueueNow;

- (void)notify:(NSString *)message withTitle:(NSString *)title;

- (void)gatherSteps:(void(^)(NSMutableArray *data))handler;

@end
