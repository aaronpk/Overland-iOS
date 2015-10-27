//
//  GLManager.h
//  GPSLogger
//
//  Created by Aaron Parecki on 9/17/15.
//  Copyright © 2015 Esri. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>

static NSString *const GLNewDataNotification = @"GLNewDataNotification";
static NSString *const GLSendingStartedNotification = @"GLSendingStartedNotification";
static NSString *const GLSendingFinishedNotification = @"GLSendingFinishedNotification";

static NSString *const GLAPIEndpointDefaultsName = @"GLAPIEndpointDefaults";
static NSString *const GLLastSentDateDefaultsName = @"GLLastSentDateDefaults";
static NSString *const GLTrackingStateDefaultsName = @"GLTrackingStateDefaults";
static NSString *const GLSendIntervalDefaultsName = @"GLSendIntervalDefaults";
static NSString *const GLPausesAutomaticallyDefaultsName = @"GLPausesAutomaticallyDefaults";
static NSString *const GLResumesAutomaticallyDefaultsName = @"GLResumesAutomaticallyDefaults";
static NSString *const GLActivityTypeDefaultsName = @"GLActivityTypeDefaults";
static NSString *const GLDesiredAccuracyDefaultsName = @"GLDesiredAccuracyDefaults";
static NSString *const GLDefersLocationUpdatesDefaultsName = @"GLDefersLocationUpdatesDefaults";
static NSString *const GLSignificantLocationModeDefaultsName = @"GLSignificantLocationModeDefaults";

static NSString *const GLTripModeDefaultsName = @"GLTripModeDefaults";
static NSString *const GLTripStartTimeDefaultsName = @"GLTripStartTimeDefaults";
static NSString *const GLTripModeWalk = @"walk";
static NSString *const GLTripModeRun = @"run";
static NSString *const GLTripModeBicycle = @"bicycle";
static NSString *const GLTripModeDrive = @"drive";
static NSString *const GLTripModeCar2go = @"car2go";
static NSString *const GLTripModeTaxi = @"taxi";
static NSString *const GLTripModeBus = @"bus";
static NSString *const GLTripModeTrain = @"train";
static NSString *const GLTripModePlane = @"plane";

static int const PointsPerBatch = 200;
static double const MetersToMiles = 0.000621371;

typedef enum {
    kGLSignificantLocationDisabled,
    kGLSignificantLocationEnabled,
    kGLSignificantLocationExclusive
} GLSignificantLocationMode;

@interface GLManager : NSObject <CLLocationManagerDelegate>

+ (GLManager *)sharedManager;

@property (strong, nonatomic, readonly) CLLocationManager *locationManager;
@property (strong, nonatomic, readonly) CMMotionActivityManager *motionActivityManager;

@property (strong, nonatomic) NSNumber *sendingInterval;
@property BOOL pausesAutomatically;
@property (nonatomic) CLLocationDistance resumesAfterDistance;
@property (nonatomic) GLSignificantLocationMode significantLocationMode;
@property (nonatomic) CLActivityType activityType;
@property (nonatomic) CLLocationAccuracy desiredAccuracy;
@property (nonatomic) CLLocationDistance defersLocationUpdates;

@property (readonly) BOOL trackingEnabled;
@property (readonly) BOOL sendInProgress;
@property (strong, nonatomic, readonly) CLLocation *lastLocation;
@property (strong, nonatomic, readonly) CMMotionActivity *lastMotion;
@property (strong, nonatomic, readonly) NSNumber *lastStepCount;
@property (strong, nonatomic, readonly) NSDate *lastSentDate;

- (void)startAllUpdates;
- (void)stopAllUpdates;
- (void)refreshLocation;

- (void)saveNewAPIEndpoint:(NSString *)endpoint;

- (void)logAction:(NSString *)action;
- (void)sendQueueNow;
- (void)notify:(NSString *)message withTitle:(NSString *)title;

- (void)numberOfLocationsInQueue:(void(^)(long num))callback;
- (void)accountInfo:(void(^)(NSString *name))block;
- (NSSet <__kindof CLRegion *>*)monitoredRegions;

#pragma mark - Trips

+ (NSArray *)GLTripModes;
- (BOOL)tripInProgress;
@property (nonatomic) NSString *currentTripMode;
- (NSDate *)currentTripStart;
- (CLLocationDistance)currentTripDistance;
- (NSTimeInterval)currentTripDuration;
- (double)currentTripSpeed;
- (void)startTrip;
- (void)endTrip;

#pragma mark -

- (void)applicationWillTerminate;
- (void)applicationDidEnterBackground;
- (void)applicationWillResignActive;

@end
