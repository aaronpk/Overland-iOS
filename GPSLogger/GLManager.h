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
@import UserNotifications;

static NSString *const GLNewDataNotification = @"GLNewDataNotification";
static NSString *const GLAuthorizationStatusChangedNotification = @"GLAuthorizationStatusChangedNotification";
static NSString *const GLSendingStartedNotification = @"GLSendingStartedNotification";
static NSString *const GLSendingFinishedNotification = @"GLSendingFinishedNotification";

static NSString *const GLAPIEndpointDefaultsName = @"GLAPIEndpointDefaults";
static NSString *const GLAPIAccessTokenDefaultsName = @"GLAPIAccessTokenDefaults";
static NSString *const GLDeviceIdDefaultsName = @"GLDeviceIdDefaults";
static NSString *const GLLastSentDateDefaultsName = @"GLLastSentDateDefaults";
static NSString *const GLTrackingStateDefaultsName = @"GLTrackingStateDefaults";
static NSString *const GLSendIntervalDefaultsName = @"GLSendIntervalDefaults";
static NSString *const GLPausesAutomaticallyDefaultsName = @"GLPausesAutomaticallyDefaults";
static NSString *const GLResumesAutomaticallyDefaultsName = @"GLResumesAutomaticallyDefaults";
static NSString *const GLDiscardPointsWithinDistanceDefaultsName = @"GLDiscardPointsWithinDistanceDefaults";
static NSString *const GLDiscardPointsWithinSecondsDefaultsName = @"GLDiscardPointsWithinSecondsDefaults";
static NSString *const GLIncludeTrackingStatsDefaultsName = @"GLIncludeTrackingStatsDefaultsName";
static NSString *const GLActivityTypeDefaultsName = @"GLActivityTypeDefaults";
static NSString *const GLDesiredAccuracyDefaultsName = @"GLDesiredAccuracyDefaults";
static NSString *const GLDefersLocationUpdatesDefaultsName = @"GLDefersLocationUpdatesDefaults";
static NSString *const GLSignificantLocationModeDefaultsName = @"GLSignificantLocationModeDefaults";
static NSString *const GLPointsPerBatchDefaultsName = @"GLPointsPerBatchDefaults";
static NSString *const GLNotificationPermissionRequestedDefaultsName = @"GLNotificationPermissionRequestedDefaults";
static NSString *const GLNotificationsEnabledDefaultsName = @"GLNotificationsEnabledDefaults";
static NSString *const GLIncludeUniqueIdDefaultsName = @"GLIncludeUniqueIdDefaults";
static NSString *const GLConsiderHTTP200SuccessDefaultsName = @"GLConsiderHTTP200SuccessDefaults";
static NSString *const GLScreenLockEnabledDefaultsName = @"GLScreenLockEnabledDefaults";

static NSString *const GLTripTrackingEnabledDefaultsName = @"GLTripTrackingEnabledDefaults";
static NSString *const GLTripModeDefaultsName = @"GLTripModeDefaults";
static NSString *const GLTripStartTimeDefaultsName = @"GLTripStartTimeDefaults";
static NSString *const GLTripStartLocationDefaultsName = @"GLTripStartLocationDefaults";
static NSString *const GLTripModeWalk = @"walk";
static NSString *const GLTripModeRun = @"run";
static NSString *const GLTripModeBicycle = @"bicycle";
static NSString *const GLTripModeCar = @"car";
static NSString *const GLTripModeTaxi = @"taxi";
static NSString *const GLTripModeBus = @"bus";
static NSString *const GLTripModeTrain = @"train";
static NSString *const GLTripModePlane = @"plane";
static NSString *const GLTripModeTram = @"tram";
static NSString *const GLTripModeMetro = @"metro";
static NSString *const GLTripModeBoat = @"boat";
static NSString *const GLTripModeScooter = @"scooter";

typedef enum {
    kGLTrackingModeStandard,
    kGLTrackingModeSignificant,
    kGLTrackingModeStandardAndSignificant
} GLTrackingMode;

@interface GLManager : NSObject <CLLocationManagerDelegate, UNUserNotificationCenterDelegate>

+ (GLManager *)sharedManager;

+ (NSString *)currentWifiHotSpotName;

@property (strong, nonatomic, readonly) CLLocationManager *locationManager;
@property (strong, nonatomic, readonly) CMMotionActivityManager *motionActivityManager;

@property (strong, nonatomic) NSNumber *sendingInterval;
@property BOOL pausesAutomatically;
@property BOOL includeTrackingStats;
@property BOOL notificationsEnabled;
@property (nonatomic) CLLocationDistance resumesAfterDistance;
@property (nonatomic) CLLocationDistance discardPointsWithinDistance;
@property (nonatomic) int discardPointsWithinSeconds;
@property (nonatomic) GLTrackingMode trackingMode;
@property (nonatomic) CLActivityType activityType;
@property (nonatomic) CLLocationAccuracy desiredAccuracy;
@property (nonatomic) CLLocationDistance defersLocationUpdates;
@property (nonatomic) int pointsPerBatch;

@property (readonly) BOOL trackingEnabled;
@property (readonly) BOOL sendInProgress;
@property (strong, nonatomic, readonly) CLLocation *lastLocation;
@property (strong, nonatomic, readonly) NSDictionary *lastLocationDictionary;
@property (strong, nonatomic, readonly) CMMotionActivity *lastMotion;
@property (strong, nonatomic, readonly) NSString *lastMotionString;
@property (strong, nonatomic, readonly) NSNumber *lastStepCount;
@property (strong, nonatomic, readonly) NSDate *lastSentDate;
@property (strong, nonatomic, readonly) NSString *lastLocationName;

- (void)startAllUpdates;
- (void)stopAllUpdates;
- (void)refreshLocation;

- (NSString *)authorizationStatusAsString;
- (void)requestAuthorizationPermission;

- (void)saveNewAPIEndpoint:(NSString *)endpoint andAccessToken:(NSString *)accessToken;
- (NSString *)apiEndpointURL;
- (NSString *)apiAccessToken;
- (void)saveNewDeviceId:(NSString *)deviceId;
- (NSString *)deviceId;

- (void)logAction:(NSString *)action;
- (void)sendQueueNow;
- (void)notify:(NSString *)message withTitle:(NSString *)title;
- (void)askToEndTrip;

- (void)numberOfLocationsInQueue:(void(^)(long num))callback;
- (void)numberOfObjectsInQueue:(void(^)(long locations, long trips, long stats))callback;
- (void)accountInfo:(void(^)(NSString *name))block;
- (NSSet <__kindof CLRegion *>*)monitoredRegions;

- (void)requestNotificationPermission;

@property (strong, nonatomic, readonly) NSString *wifiZoneName;
@property (strong, nonatomic, readonly) NSString *wifiZoneLatitude;
@property (strong, nonatomic, readonly) NSString *wifiZoneLongitude;
- (void)saveNewWifiZone:(NSString *)name withLatitude:(NSString *)latitude andLongitude:(NSString *)longitude;

#pragma mark - Trips

+ (NSArray *)GLTripModes;
- (BOOL)tripInProgress;
@property (nonatomic) NSString *currentTripMode;
- (NSDate *)currentTripStart;
- (CLLocationDistance)currentTripDistance;
- (NSTimeInterval)currentTripDuration;
- (void)startTrip;
- (void)endTrip;

#pragma mark -

- (void)applicationWillTerminate;
- (void)applicationDidEnterBackground;
- (void)applicationWillResignActive;

@end
