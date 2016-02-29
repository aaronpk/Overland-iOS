//
//  GLManager.m
//  GPSLogger
//
//  Created by Aaron Parecki on 9/17/15.
//  Copyright © 2015 Esri. All rights reserved.
//

#import "GLManager.h"
#import "AFHTTPSessionManager.h"
#import "LOLDatabase.h"
#import "FMDatabase.h"
#import "PebbleManager.h"

@interface GLManager()

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CMMotionActivityManager *motionActivityManager;

@property BOOL trackingEnabled;
@property BOOL sendInProgress;
@property BOOL batchInProgress;
@property (strong, nonatomic) CLLocation *lastLocation;
@property (strong, nonatomic) CMMotionActivity *lastMotion;
@property (strong, nonatomic) NSDate *lastSentDate;

@property (strong, nonatomic) LOLDatabase *db;
@property (strong, nonatomic) FMDatabase *tripdb;

@end

@implementation GLManager

static NSString *const GLLocationQueueName = @"GLLocationQueue";

NSNumber *_sendingInterval;
NSArray *_tripModes;
bool _currentTripHasNewData;
CLLocationDistance _currentTripDistanceCached;
AFHTTPSessionManager *_httpClient;

+ (GLManager *)sharedManager {
    static GLManager *_instance = nil;
    
    @synchronized (self) {
        if (_instance == nil) {
            _instance = [[self alloc] init];
            
            _instance.db = [[LOLDatabase alloc] initWithPath:[self cacheDatabasePath]];
            _instance.db.serializer = ^(id object){
                return [self dataWithJSONObject:object error:NULL];
            };
            _instance.db.deserializer = ^(NSData *data) {
                return [self objectFromJSONData:data error:NULL];
            };
            
            _instance.tripdb = [FMDatabase databaseWithPath:[self tripDatabasePath]];
            [_instance setUpTripDB];
            
            [_instance setupHTTPClient];
            [_instance restoreTrackingState];
        }
    }
    
    return _instance;
}

#pragma mark - GLManager control (public)

- (void)saveNewAPIEndpoint:(NSString *)endpoint {
    [[NSUserDefaults standardUserDefaults] setObject:endpoint forKey:GLAPIEndpointDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self setupHTTPClient];
}

- (void)startAllUpdates {
    [self enableTracking];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:GLTrackingStateDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)stopAllUpdates {
    [self disableTracking];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:GLTrackingStateDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)refreshLocation {
    NSLog(@"Trying to update location now");
    [self.locationManager stopUpdatingLocation];
    [self.locationManager performSelector:@selector(startUpdatingLocation) withObject:nil afterDelay:1.0];
}

- (void)sendQueueNow {
    NSMutableSet *syncedUpdates = [NSMutableSet set];
    NSMutableArray *locationUpdates = [NSMutableArray array];
    
    NSString *endpoint = [[NSUserDefaults standardUserDefaults] stringForKey:GLAPIEndpointDefaultsName];
    
    if(endpoint == nil) {
        NSLog(@"No API endpoint is set, not sending data");
        return;
    }
    
    [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        
        [accessor enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *object) {
            [syncedUpdates addObject:key];
            [locationUpdates addObject:object];
            return (BOOL)(locationUpdates.count >= PointsPerBatch);
        }];
        
    }];
    
    NSDictionary *postData = @{@"locations": locationUpdates};
    
    NSLog(@"Endpoint: %@", endpoint);
    NSLog(@"Updates in post: %lu", (unsigned long)locationUpdates.count);
    
    if(locationUpdates.count == 0) {
        self.batchInProgress = NO;
        return;
    }
    
    [self sendingStarted];
    
    [_httpClient POST:endpoint parameters:postData progress:NULL success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"Response: %@", responseObject);
        
        if([responseObject objectForKey:@"result"] && [[responseObject objectForKey:@"result"] isEqualToString:@"ok"]) {
            self.lastSentDate = NSDate.date;
            
            [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
                for(NSString *key in syncedUpdates) {
                    [accessor removeDictionaryForKey:key];
                }
                
            }];
            
            // Try to send again in case there are more left
            [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
                [accessor countObjectsUsingBlock:^(long num) {
                    if(num > 0) {
                        NSLog(@"Number remaining: %ld", num);
                        self.batchInProgress = YES;
                    } else {
                        self.batchInProgress = NO;
                    }
                }];
            }];
            
            [self sendingFinished];
        } else {
            
            self.batchInProgress = NO;
            
            if([responseObject objectForKey:@"error"]) {
                [self notify:[responseObject objectForKey:@"error"] withTitle:@"Error"];
                [self sendingFinished];
            } else {
                [self notify:[responseObject description] withTitle:@"Error"];
                [self sendingFinished];
            }
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        self.batchInProgress = NO;
        NSLog(@"Error: %@", error);
        [self notify:error.description withTitle:@"Error"];
        [self sendingFinished];
    }];
    
}

- (void)logAction:(NSString *)action {
    [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        NSString *timestamp = [GLManager iso8601DateStringFromDate:[NSDate date]];
        NSMutableDictionary *update = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                      @"type": @"Feature",
                                                                                      @"properties": @{
                                                                                              @"timestamp": timestamp,
                                                                                              @"action": action,
                                                                                              @"battery_state": [self currentBatteryState],
                                                                                              @"battery_level": [self currentBatteryLevel]
                                                                                              }
                                                                                      }];
        if(self.lastLocation) {
            [update setObject:@{
                                @"type": @"Point",
                                @"coordinates": @[
                                        [NSNumber numberWithDouble:self.lastLocation.coordinate.longitude],
                                        [NSNumber numberWithDouble:self.lastLocation.coordinate.latitude]
                                        ]
                                } forKey:@"geometry"];
        }
        [accessor setDictionary:update forKey:timestamp];
    }];
}

- (void)notify:(NSString *)message withTitle:(NSString *)title
{
    UILocalNotification* localNotification = [[UILocalNotification alloc] init];
    localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:1];
    localNotification.alertBody = [NSString stringWithFormat:@"%@: %@", title, message];
    localNotification.timeZone = [NSTimeZone defaultTimeZone];
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
}

- (void)accountInfo:(void(^)(NSString *name))block {
    NSString *endpoint = [[NSUserDefaults standardUserDefaults] stringForKey:GLAPIEndpointDefaultsName];
    [_httpClient GET:endpoint parameters:nil progress:NULL success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSDictionary *dict = (NSDictionary *)responseObject;
        block((NSString *)[dict objectForKey:@"name"]);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"Failed to get account info");
    }];
}

- (void)numberOfLocationsInQueue:(void(^)(long num))callback {
    [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        [accessor countObjectsUsingBlock:callback];
    }];
}

#pragma mark - GLManager control (private)

- (void)setupHTTPClient {
    NSURL *endpoint = [NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:GLAPIEndpointDefaultsName]];
    
    if(endpoint) {
        _httpClient = [[AFHTTPSessionManager manager] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@://%@", endpoint.scheme, endpoint.host]]];
        _httpClient.requestSerializer = [AFJSONRequestSerializer serializer];
        _httpClient.responseSerializer = [AFJSONResponseSerializer serializer];
    }
}

- (void)restoreTrackingState {
    if([[NSUserDefaults standardUserDefaults] boolForKey:GLTrackingStateDefaultsName]) {
        [self enableTracking];
        if(self.tripInProgress) {
            // If a trip is in progress, open the trip DB now
            [self.tripdb open];
            [[PebbleManager sharedManager] startWatchSession];
        }
    } else {
        [self disableTracking];
    }
}

- (void)enableTracking {
    self.trackingEnabled = YES;
    [self.locationManager requestAlwaysAuthorization];
    [self.locationManager startUpdatingLocation];
    [self.locationManager startUpdatingHeading];
    [self.locationManager startMonitoringVisits];
    if(self.significantLocationMode != kGLSignificantLocationDisabled) {
        [self.locationManager startMonitoringSignificantLocationChanges];
        NSLog(@"Monitoring significant location changes");
    }
    
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    
    if(CMMotionActivityManager.isActivityAvailable) {
        [self.motionActivityManager startActivityUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMMotionActivity *activity) {
            [[NSNotificationCenter defaultCenter] postNotificationName:GLNewDataNotification object:self];
            self.lastMotion = activity;
        }];
    }
    
    // Set the last location if location manager has a last location.
    // This will be set for example when the app launches due to a signification location change,
    // the locationmanager has a location already before a location event is delivered to the delegate.
    if(self.locationManager.location) {
        self.lastLocation = self.locationManager.location;
    }
}

- (void)disableTracking {
    self.trackingEnabled = NO;
    [UIDevice currentDevice].batteryMonitoringEnabled = NO;
    [self.locationManager stopMonitoringVisits];
    [self.locationManager stopUpdatingHeading];
    [self.locationManager stopUpdatingLocation];
    [self.locationManager stopMonitoringSignificantLocationChanges];
    if(CMMotionActivityManager.isActivityAvailable) {
        [self.motionActivityManager stopActivityUpdates];
        self.lastMotion = nil;
    }
}

- (void)sendingStarted {
    self.sendInProgress = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:GLSendingStartedNotification object:self];
}

- (void)sendingFinished {
    self.sendInProgress = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:GLSendingFinishedNotification object:self];
}

- (void)sendQueueIfTimeElapsed {
    BOOL sendingEnabled = [self.sendingInterval integerValue] > -1;
    if(!sendingEnabled) {
        return;
    }
    
    if(self.sendInProgress) {
        NSLog(@"Send is already in progress");
        return;
    }
    
    BOOL timeElapsed = [(NSDate *)[self.lastSentDate dateByAddingTimeInterval:[self.sendingInterval doubleValue]] compare:NSDate.date] == NSOrderedAscending;
    
    __block long numPending = 0;
    [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        [accessor countObjectsUsingBlock:^(long num) {
            numPending = num;
        }];
    }];
    //    if(numPending < PointsPerBatch) {
    //        self.batchInProgress = NO;
    //    }
    
    NSLog(@"Points in queue: %lu", numPending);
    
    // Send if time has elapsed,
    // or if we're in the middle of flushing
    if(timeElapsed || self.batchInProgress) {
        NSLog(@"Sending a batch now");
        [self sendQueueNow];
        self.lastSentDate = NSDate.date;
    }
}

- (void)sendQueueIfNotInProgress {
    if(self.sendInProgress) {
        return;
    }
    
    [self sendQueueNow];
    self.lastSentDate = NSDate.date;
}

#pragma mark - Trips

+ (NSArray *)GLTripModes {
    if(!_tripModes) {
        _tripModes = @[GLTripModeWalk, GLTripModeRun, GLTripModeBicycle,
                       GLTripModeDrive, GLTripModeCar2go, GLTripModeTaxi,
                       GLTripModeBus, GLTripModeTrain, GLTripModePlane];
        }
    return _tripModes;
}

- (BOOL)tripInProgress {
    return [[NSUserDefaults standardUserDefaults] objectForKey:GLTripStartTimeDefaultsName] != nil;
}

- (NSString *)currentTripMode {
    NSString *mode = [[NSUserDefaults standardUserDefaults] stringForKey:GLTripModeDefaultsName];
    if(!mode) {
        mode = @"bicycle";
    }
    return mode;
}

- (void)setCurrentTripMode:(NSString *)mode {
    [[NSUserDefaults standardUserDefaults] setObject:mode forKey:GLTripModeDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDate *)currentTripStart {
    if(!self.tripInProgress) {
        return nil;
    }
    return (NSDate *)[[NSUserDefaults standardUserDefaults] objectForKey:GLTripStartTimeDefaultsName];
}

- (NSTimeInterval)currentTripDuration {
    if(!self.tripInProgress) {
        return -1;
    }
    
    NSDate *startDate = self.currentTripStart;
    return [startDate timeIntervalSinceNow] * -1.0;
}

- (CLLocationDistance)currentTripDistance {
    if(!self.tripInProgress) {
        return -1;
    }
    
    if(!_currentTripHasNewData) {
        return _currentTripDistanceCached;
    }

    CLLocationDistance distance = 0;
    CLLocation *lastLocation;
    CLLocation *loc;
    
    FMResultSet *s = [self.tripdb executeQuery:@"SELECT latitude, longitude FROM trips ORDER BY timestamp"];
    while([s next]) {
        loc = [[CLLocation alloc] initWithLatitude:[s doubleForColumnIndex:0] longitude:[s doubleForColumnIndex:1]];
        
        if(lastLocation) {
            distance += [lastLocation distanceFromLocation:loc];
        }
        
        lastLocation = loc;
    }
    
    return distance;
}

- (CLLocationCoordinate2D)currentTripStartLocation {
    if(!self.tripInProgress)
        return kCLLocationCoordinate2DInvalid;
    
    CLLocationCoordinate2D result = kCLLocationCoordinate2DInvalid;
    FMResultSet *s = [self.tripdb executeQuery:@"SELECT latitude, longitude FROM trips ORDER BY timestamp LIMIT 1"];
    while([s next]) {
        result = CLLocationCoordinate2DMake([s doubleForColumnIndex:0], [s doubleForColumnIndex:1]);
    }
    return result;
}

/**
 * speed in miles per hour
 */
- (double)currentTripSpeed {
    if(!self.tripInProgress) {
        return -1;
    }
    
    double speedMS = self.lastLocation.speed;
    return speedMS * 2.23694;
}

- (void)startTrip {
    if(self.tripInProgress) {
        return;
    }
    
    [[PebbleManager sharedManager] startWatchSession];
    
    NSDate *startDate = [NSDate date];
    [[NSUserDefaults standardUserDefaults] setObject:startDate forKey:GLTripStartTimeDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [self.tripdb open];
    _currentTripDistanceCached = 0;
    _currentTripHasNewData = NO;
    
    NSLog(@"Started a trip");
}

- (void)endTrip {
    [self endTripFromAutopause:NO];
}

- (void)endTripFromAutopause:(BOOL)autopause {
    if(!self.tripInProgress) {
        return;
    }

    [[PebbleManager sharedManager] stopWatchSession];

    [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        NSString *timestamp = [GLManager iso8601DateStringFromDate:[NSDate date]];
        CLLocationCoordinate2D startLocation = [self currentTripStartLocation];
        NSMutableDictionary *update = [NSMutableDictionary dictionaryWithDictionary:@{
                                 @"type": @"Feature",
                                 @"geometry": @{
                                         @"type": @"Point",
                                         @"coordinates": @[
                                                 [NSNumber numberWithDouble:self.lastLocation.coordinate.longitude],
                                                 [NSNumber numberWithDouble:self.lastLocation.coordinate.latitude]
                                                 ]
                                         },
                                 @"properties": @{
                                         @"timestamp": timestamp,
                                         @"type": @"trip",
                                         @"mode": self.currentTripMode,
                                         @"start": [GLManager iso8601DateStringFromDate:self.currentTripStart],
                                         @"end": timestamp,
                                         @"start-coordinates": @[
                                                 [NSNumber numberWithDouble:startLocation.longitude],
                                                 [NSNumber numberWithDouble:startLocation.latitude]
                                                 ],
                                         @"end-coordinates":@[
                                                 [NSNumber numberWithDouble:self.lastLocation.coordinate.longitude],
                                                 [NSNumber numberWithDouble:self.lastLocation.coordinate.latitude]
                                                 ],
                                         @"duration": [NSNumber numberWithDouble:self.currentTripDuration],
                                         @"distance": [NSNumber numberWithDouble:self.currentTripDistance],
                                         @"stopped_automatically": @(autopause)
                                         }
                                 }];
        if(autopause) {
            [self notify:@"Trip ended automatically" withTitle:@"Tracker"];
        }
        [accessor setDictionary:update forKey:timestamp];
    }];

    _currentTripDistanceCached = 0;
    [self clearTripDB];
    [self.tripdb close];

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:GLTripStartTimeDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSLog(@"Ended a %@ trip", self.currentTripMode);
}

#pragma mark - Properties

- (CLLocationManager *)locationManager {
    if (!_locationManager) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.desiredAccuracy = self.desiredAccuracy;
        _locationManager.distanceFilter = 1;
        _locationManager.allowsBackgroundLocationUpdates = YES;
        _locationManager.pausesLocationUpdatesAutomatically = self.pausesAutomatically;
        _locationManager.activityType = self.activityType;
    }
    
    return _locationManager;
}

- (CMMotionActivityManager *)motionActivityManager {
    if (!_motionActivityManager) {
        _motionActivityManager = [[CMMotionActivityManager alloc] init];
    }
    
    return _motionActivityManager;
}

- (NSString *)currentBatteryState {
    switch([UIDevice currentDevice].batteryState) {
        case UIDeviceBatteryStateUnknown:
            return @"unknown";
        case UIDeviceBatteryStateCharging:
            return @"charging";
        case UIDeviceBatteryStateFull:
            return @"full";
        case UIDeviceBatteryStateUnplugged:
            return @"unplugged";
    }
}

- (NSNumber *)currentBatteryLevel {
    return [NSNumber numberWithFloat:[UIDevice currentDevice].batteryLevel];
}

#pragma mark CLLocationManager

- (NSSet *)monitoredRegions {
    return self.locationManager.monitoredRegions;
}

- (BOOL)pausesAutomatically {
    if([self defaultsKeyExists:GLPausesAutomaticallyDefaultsName]) {
        return [[NSUserDefaults standardUserDefaults] boolForKey:GLPausesAutomaticallyDefaultsName];
    } else {
        return NO;
    }
}
- (void)setPausesAutomatically:(BOOL)pausesAutomatically {
    [[NSUserDefaults standardUserDefaults] setBool:pausesAutomatically forKey:GLPausesAutomaticallyDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.locationManager.pausesLocationUpdatesAutomatically = pausesAutomatically;
}

- (CLLocationDistance)resumesAfterDistance {
    if([self defaultsKeyExists:GLResumesAutomaticallyDefaultsName]) {
        return [[NSUserDefaults standardUserDefaults] doubleForKey:GLResumesAutomaticallyDefaultsName];
    } else {
        return -1;
    }
}
- (void)setResumesAfterDistance:(CLLocationDistance)resumesAfterDistance {
    [[NSUserDefaults standardUserDefaults] setDouble:resumesAfterDistance forKey:GLResumesAutomaticallyDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (GLSignificantLocationMode)significantLocationMode {
    if([self defaultsKeyExists:GLSignificantLocationModeDefaultsName]) {
        return (int)[[NSUserDefaults standardUserDefaults] integerForKey:GLSignificantLocationModeDefaultsName];
    } else {
        return kGLSignificantLocationDisabled;
    }
}
- (void)setSignificantLocationMode:(GLSignificantLocationMode)significantLocationMode {
    [[NSUserDefaults standardUserDefaults] setInteger:significantLocationMode forKey:GLSignificantLocationModeDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if(significantLocationMode != kGLSignificantLocationDisabled) {
        [self.locationManager startMonitoringSignificantLocationChanges];
    } else {
        [self.locationManager stopMonitoringSignificantLocationChanges];
    }
}

- (CLActivityType)activityType {
    if([self defaultsKeyExists:GLActivityTypeDefaultsName]) {
        return [[NSUserDefaults standardUserDefaults] integerForKey:GLActivityTypeDefaultsName];
    } else {
        return CLActivityTypeOther;
    }
}
- (void)setActivityType:(CLActivityType)activityType {
    [[NSUserDefaults standardUserDefaults] setInteger:activityType forKey:GLActivityTypeDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.locationManager.activityType = activityType;
}

- (CLLocationAccuracy)desiredAccuracy {
    if([self defaultsKeyExists:GLDesiredAccuracyDefaultsName]) {
        return [[NSUserDefaults standardUserDefaults] doubleForKey:GLDesiredAccuracyDefaultsName];
    } else {
        return kCLLocationAccuracyHundredMeters;
    }
}
- (void)setDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy {
    NSLog(@"Setting desiredAccuracy: %f", desiredAccuracy);
    [[NSUserDefaults standardUserDefaults] setDouble:desiredAccuracy forKey:GLDesiredAccuracyDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.locationManager.desiredAccuracy = desiredAccuracy;
}

- (CLLocationDistance)defersLocationUpdates {
    if([self defaultsKeyExists:GLDefersLocationUpdatesDefaultsName]) {
        return [[NSUserDefaults standardUserDefaults] doubleForKey:GLDefersLocationUpdatesDefaultsName];
    } else {
        return 0;
    }
}
- (void)setDefersLocationUpdates:(CLLocationDistance)distance {
    [[NSUserDefaults standardUserDefaults] setDouble:distance forKey:GLDefersLocationUpdatesDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if(distance > 0) {
        [self.locationManager allowDeferredLocationUpdatesUntilTraveled:distance timeout:[self.sendingInterval doubleValue]];
    } else {
        [self.locationManager disallowDeferredLocationUpdates];
    }
}

#pragma mark GLManager

- (NSNumber *)sendingInterval {
    if(_sendingInterval)
        return _sendingInterval;
    
    _sendingInterval = (NSNumber *)[[NSUserDefaults standardUserDefaults] valueForKey:GLSendIntervalDefaultsName];
    return _sendingInterval;
}

- (void)setSendingInterval:(NSNumber *)newValue {
    [[NSUserDefaults standardUserDefaults] setValue:newValue forKey:GLSendIntervalDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _sendingInterval = newValue;
}

- (NSDate *)lastSentDate {
    return (NSDate *)[[NSUserDefaults standardUserDefaults] objectForKey:GLLastSentDateDefaultsName];
}

- (void)setLastSentDate:(NSDate *)lastSentDate {
    [[NSUserDefaults standardUserDefaults] setObject:lastSentDate forKey:GLLastSentDateDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - CLLocationManager Delegate Methods

- (void)locationManager:(CLLocationManager *)manager didVisit:(CLVisit *)visit {
    [[NSNotificationCenter defaultCenter] postNotificationName:GLNewDataNotification object:self];

    NSLog(@"Got a visit event: %@", visit);
    
    [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        NSString *timestamp = [GLManager iso8601DateStringFromDate:[NSDate date]];
        NSDictionary *update = @{
                                  @"type": @"Feature",
                                  @"geometry": @{
                                          @"type": @"Point",
                                          @"coordinates": @[
                                                  [NSNumber numberWithDouble:visit.coordinate.longitude],
                                                  [NSNumber numberWithDouble:visit.coordinate.latitude]
                                                  ]
                                          },
                                  @"properties": @{
                                          @"timestamp": timestamp,
                                          @"action": @"visit",
                                          @"arrival_date": ([visit.arrivalDate isEqualToDate:[NSDate distantPast]] ? [NSNull null] : [GLManager iso8601DateStringFromDate:visit.arrivalDate]),
                                          @"departure_date": ([visit.departureDate isEqualToDate:[NSDate distantFuture]] ? [NSNull null] : [GLManager iso8601DateStringFromDate:visit.departureDate]),
                                          @"horizontal_accuracy": [NSNumber numberWithInt:visit.horizontalAccuracy],
                                          @"battery_state": [self currentBatteryState],
                                          @"battery_level": [self currentBatteryLevel]
                                          }
                                };
        [accessor setDictionary:update forKey:timestamp];
    }];

    [self sendQueueIfTimeElapsed];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    [[NSNotificationCenter defaultCenter] postNotificationName:GLNewDataNotification object:self];
    self.lastLocation = (CLLocation *)locations[0];
    
    NSLog(@"Received %d locations", (int)locations.count);
    
    // NSLog(@"%@", locations);
    
    // Queue the point in the database
    [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        
        NSMutableArray *motion = [[NSMutableArray alloc] init];
        CMMotionActivity *motionActivity = [GLManager sharedManager].lastMotion;
        if(motionActivity.walking)
            [motion addObject:@"walking"];
        if(motionActivity.running)
            [motion addObject:@"running"];
        if(motionActivity.automotive)
            [motion addObject:@"driving"];
        if(motionActivity.stationary)
            [motion addObject:@"stationary"];
        
        NSString *activityType = @"";
        switch([GLManager sharedManager].activityType) {
            case CLActivityTypeOther:
                activityType = @"other";
                break;
            case CLActivityTypeAutomotiveNavigation:
                activityType = @"automotive_navigation";
                break;
            case CLActivityTypeFitness:
                activityType = @"fitness";
                break;
            case CLActivityTypeOtherNavigation:
                activityType = @"other_navigation";
                break;
        }
        
        for(int i=0; i<locations.count; i++) {
            CLLocation *loc = locations[i];
            NSString *timestamp = [GLManager iso8601DateStringFromDate:loc.timestamp];
            NSDictionary *update = @{
                                     @"type": @"Feature",
                                     @"geometry": @{
                                             @"type": @"Point",
                                             @"coordinates": @[
                                                     [NSNumber numberWithDouble:loc.coordinate.longitude],
                                                     [NSNumber numberWithDouble:loc.coordinate.latitude]
                                                     ]
                                             },
                                     @"properties": @{
                                             @"timestamp": timestamp,
                                             @"altitude": [NSNumber numberWithInt:(int)round(loc.altitude)],
                                             @"speed": [NSNumber numberWithInt:(int)round(loc.speed)],
                                             @"horizontal_accuracy": [NSNumber numberWithInt:(int)round(loc.horizontalAccuracy)],
                                             @"vertical_accuracy": [NSNumber numberWithInt:(int)round(loc.verticalAccuracy)],
                                             @"motion": motion,
                                             @"pauses": [NSNumber numberWithBool:self.locationManager.pausesLocationUpdatesAutomatically],
                                             @"activity": activityType,
                                             @"desired_accuracy": [NSNumber numberWithDouble:self.locationManager.desiredAccuracy],
                                             @"deferred": [NSNumber numberWithDouble:self.defersLocationUpdates],
                                             @"significant_change": [NSNumber numberWithInt:self.significantLocationMode],
                                             @"locations_in_payload": [NSNumber numberWithLong:locations.count],
                                             @"battery_state": [self currentBatteryState],
                                             @"battery_level": [self currentBatteryLevel]
                                             }
                                     };
            [accessor setDictionary:update forKey:timestamp];

            // If a trip is in progress, add to the trip's list too
            if(self.tripInProgress && loc.horizontalAccuracy <= 100) {
                [self.tripdb executeUpdate:@"INSERT INTO trips (timestamp, latitude, longitude) VALUES (?, ?, ?)", [NSNumber numberWithInt:[loc.timestamp timeIntervalSince1970]], [NSNumber numberWithDouble:loc.coordinate.latitude], [NSNumber numberWithDouble:loc.coordinate.longitude]];
                [[PebbleManager sharedManager] refreshWatchface];
                _currentTripHasNewData = YES;
            }

        }
        
    }];
    
    [self sendQueueIfTimeElapsed];
}

- (void)locationManagerDidPauseLocationUpdates:(CLLocationManager *)manager {
    [self logAction:@"paused_location_updates"];
    
    [self notify:@"Location updates paused" withTitle:@"Paused"];
    
    // Create an exit geofence to help it resume automatically
    if(self.resumesAfterDistance > 0) {
        CLCircularRegion *region = [[CLCircularRegion alloc] initWithCenter:self.lastLocation.coordinate radius:self.resumesAfterDistance identifier:@"resume-from-pause"];
        region.notifyOnEntry = NO;
        region.notifyOnExit = YES;
        [self.locationManager startMonitoringForRegion:region];
    }
    
    // Send the queue now to flush all remaining points
    [self sendQueueIfNotInProgress];
    
    // If a trip was in progress, stop it now
    if(self.tripInProgress) {
        [self endTripFromAutopause:YES];
    }
}

-(void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    [self logAction:@"exited_pause_region"];
    [self notify:@"Starting updates from exiting the geofence" withTitle:@"Resumed"];
    [self.locationManager stopMonitoringForRegion:region];
    [self enableTracking];
}

- (void)locationManagerDidResumeLocationUpdates:(CLLocationManager *)manager {
    [self logAction:@"resumed_location_updates"];
    [self notify:@"Location updates resumed" withTitle:@"Resumed"];
}

- (void)locationManager:(CLLocationManager *)manager didFinishDeferredUpdatesWithError:(nullable NSError *)error {
    [self logAction:@"did_finish_deferred_updates"];
}

#pragma mark - AppDelegate Methods

- (void)applicationDidEnterBackground {
    // [self logAction:@"did_enter_background"];
}

- (void)applicationWillTerminate {
    [self logAction:@"will_terminate"];
}

- (void)applicationWillResignActive {
    // [self logAction:@"will_resign_active"];
}

#pragma mark -


- (BOOL)defaultsKeyExists:(NSString *)key {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [[[defaults dictionaryRepresentation] allKeys] containsObject:key];
}

#pragma mark - FMDB

+ (NSString *)tripDatabasePath {
    NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    return [docsPath stringByAppendingPathComponent:@"trips.sqlite"];
}

- (void)setUpTripDB {
    [self.tripdb open];
    if(![self.tripdb executeUpdate:@"CREATE TABLE IF NOT EXISTS trips (\
       id INTEGER PRIMARY KEY AUTOINCREMENT, \
       timestamp INTEGER, \
       latitude REAL, \
       longitude REAL \
     )"]) {
        NSLog(@"Error creating trip DB: %@", self.tripdb.lastErrorMessage);
    }
    [self.tripdb close];
}

- (void)clearTripDB {
    [self.tripdb executeUpdate:@"DELETE FROM trips"];
}


#pragma mark - LOLDB

+ (NSString *)cacheDatabasePath
{
    NSString *caches = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return [caches stringByAppendingPathComponent:@"GLLoggerCache.sqlite"];
}

+ (id)objectFromJSONData:(NSData *)data error:(NSError **)error;
{
    return [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:error];
}

+ (NSData *)dataWithJSONObject:(id)object error:(NSError **)error;
{
    return [NSJSONSerialization dataWithJSONObject:object options:0 error:error];
}

+ (NSString *)iso8601DateStringFromDate:(NSDate *)date {
    struct tm *timeinfo;
    char buffer[80];
    
    time_t rawtime = (time_t)[date timeIntervalSince1970];
    timeinfo = gmtime(&rawtime);
    
    strftime(buffer, 80, "%Y-%m-%dT%H:%M:%SZ", timeinfo);
    
    return [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
}

@end
