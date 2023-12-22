//
//  GLManager.m
//  GPSLogger
//
//  Created by Aaron Parecki on 9/17/15.
//  Copyright © 2015 Esri. All rights reserved.
//  Copyright © 2017 Aaron Parecki. All rights reserved.
//

#import "GLManager.h"
#import "AFHTTPSessionManager.h"
#import "LOLDatabase.h"
#import "FMDatabase.h"
#import "SystemConfiguration/CaptiveNetwork.h"
@import UserNotifications;

@interface GLManager()

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CMMotionActivityManager *motionActivityManager;
@property (strong, nonatomic) CMPedometer *pedometer;

@property BOOL trackingEnabled;
@property BOOL sendInProgress;
@property BOOL batchInProgress;
@property (strong, nonatomic) CLLocation *lastLocation;
@property (strong, nonatomic) CMMotionActivity *lastMotion;
@property (strong, nonatomic) NSDate *lastSentDate;
@property (strong, nonatomic) NSString *lastLocationName;

@property (strong, nonatomic) NSDictionary *lastLocationDictionary;
@property (strong, nonatomic) NSDictionary *tripStartLocationDictionary;

@property (strong, nonatomic) LOLDatabase *db;
@property (strong, nonatomic) FMDatabase *tripdb;

@end

@implementation GLManager

static NSString *const GLLocationQueueName = @"GLLocationQueue";
static NSString *const GLNotificationCategoryTripName = @"TRIP";

NSNumber *_sendingInterval;
NSArray *_tripModes;
bool _currentTripHasNewData;
bool _storeNextLocationAsTripStart = NO;
long _currentPointsInQueue;
NSString *_deviceId;
CLLocationDistance _currentTripDistanceCached;
AFHTTPSessionManager *_httpClient;

const double FEET_TO_METERS = 0.304;
const double MPH_to_METERSPERSECOND = 0.447;

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
            [_instance initializeNotifications];
            
            _instance.pedometer = [[CMPedometer alloc] init];
        }
    }
    
    return _instance;
}

#pragma mark - GLManager control (public)

- (void)saveNewAPIEndpoint:(NSString *)endpoint andAccessToken:(NSString *)accessToken {
    [[NSUserDefaults standardUserDefaults] setObject:endpoint forKey:GLAPIEndpointDefaultsName];
    [[NSUserDefaults standardUserDefaults] setObject:accessToken forKey:GLAPIAccessTokenDefaultsName];
    [self setupHTTPClient];
}

- (NSString *)apiEndpointURL {
    return [[NSUserDefaults standardUserDefaults] stringForKey:GLAPIEndpointDefaultsName];
}

- (NSString *)apiAccessToken {
    return [[NSUserDefaults standardUserDefaults] stringForKey:GLAPIAccessTokenDefaultsName];
}

- (void)saveNewDeviceId:(NSString *)deviceId {
    _deviceId = deviceId;
    [[NSUserDefaults standardUserDefaults] setObject:deviceId forKey:GLDeviceIdDefaultsName];
    // Always call saveNewAPIEndpoint after saveNewDeviceId to synchronize changes
}

- (NSString *)deviceId {
    NSString *d = [[NSUserDefaults standardUserDefaults] stringForKey:GLDeviceIdDefaultsName];
    if(d == nil) {
        d = @"";
    }
    return d;
}

- (void)startAllUpdates {
    [self enableTracking];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:GLTrackingStateDefaultsName];
}

- (void)stopAllUpdates {
    [self disableTracking];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:GLTrackingStateDefaultsName];
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
    
    __block long _numInQueue = 0;
    
    [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        
        [accessor enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *object) {
            if(key && object) {
                [syncedUpdates addObject:key];
                [locationUpdates addObject:object];
            } else if(key) {
                // Remove nil objects
                [accessor removeDictionaryForKey:key];
            }
            return (BOOL)(locationUpdates.count >= self.pointsPerBatchCurrentValue);
        }];
        
        [accessor countObjectsUsingBlock:^(long num) {
            _numInQueue = num;
        }];
    }];
    
    NSMutableDictionary *postData = [NSMutableDictionary dictionaryWithDictionary:@{@"locations": locationUpdates}];

    // If there are still more in the queue, then send the current location as a separate property.
    // This allows the server to know where the user is immediately even if there are many thousands of points in the backlog.
    NSDictionary *currentLocation = [self currentDictionaryFromLocation:self.lastLocation];
    if(_numInQueue > self.pointsPerBatchCurrentValue && self.lastLocation) {
        [postData setObject:currentLocation forKey:@"current"];
    }
    
    if(self.tripInProgress) {
        NSDictionary *currentTripInfo = [self currentTripDictionary];
        [postData setObject:currentTripInfo forKey:@"trip"];
    }

    // If there are any template strings in the URL, replace the values with the data from the most recent location
    // TS, LAT, LON, ACC, SPD, ALT, BAT
    NSMutableString *endpointURL = [endpoint mutableCopy];
    [endpointURL replaceOccurrencesOfString:@"%TS"
                                 withString:[self stringForProperty:kGLLocationPropertyTimestamp ofLocation:self.lastLocation] options:NSLiteralSearch
                                      range:NSMakeRange(0, endpointURL.length)];
    [endpointURL replaceOccurrencesOfString:@"%LAT"
                                 withString:[self stringForProperty:kGLLocationPropertyLatitude ofLocation:self.lastLocation] options:NSLiteralSearch
                                      range:NSMakeRange(0, endpointURL.length)];
    [endpointURL replaceOccurrencesOfString:@"%LON"
                                 withString:[self stringForProperty:kGLLocationPropertyLongitude ofLocation:self.lastLocation] options:NSLiteralSearch
                                      range:NSMakeRange(0, endpointURL.length)];
    [endpointURL replaceOccurrencesOfString:@"%ACC"
                                 withString:[self stringForProperty:kGLLocationPropertyAccuracy ofLocation:self.lastLocation] options:NSLiteralSearch
                                      range:NSMakeRange(0, endpointURL.length)];
    [endpointURL replaceOccurrencesOfString:@"%SPD"
                                 withString:[self stringForProperty:kGLLocationPropertySpeed ofLocation:self.lastLocation] options:NSLiteralSearch
                                      range:NSMakeRange(0, endpointURL.length)];
    [endpointURL replaceOccurrencesOfString:@"%ALT"
                                 withString:[self stringForProperty:kGLLocationPropertyAltitude ofLocation:self.lastLocation] options:NSLiteralSearch
                                      range:NSMakeRange(0, endpointURL.length)];
    [endpointURL replaceOccurrencesOfString:@"%BAT"
                                 withString:[self stringForProperty:kGLLocationPropertyBattery ofLocation:self.lastLocation] options:NSLiteralSearch
                                      range:NSMakeRange(0, endpointURL.length)];

    
    NSLog(@"Endpoint: %@", endpointURL);
    NSLog(@"Updates in post: %lu", (unsigned long)locationUpdates.count);
    
    if(locationUpdates.count == 0) {
        self.batchInProgress = NO;
        return;
    }
    
    [self sendingStarted];

    [_httpClient POST:endpointURL parameters:postData headers:NULL progress:NULL success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"Response: %@", responseObject);
        
        bool requestWasSuccessfullySent = NO;
        if(self.shouldConsiderHTTP200Success) {
            // Any non-200 response would have been caught by the error callback instead
            requestWasSuccessfullySent = YES;
        } else {
            // Response must be JSON
            if(![responseObject respondsToSelector:@selector(objectForKey:)]) {
                self.batchInProgress = NO;
                [self notify:@"Server did not return a JSON object" withTitle:@"Server Error"];
                [self sendingFinished];
                return;
            }

            // Response JSON must include {"result":"ok"}
            requestWasSuccessfullySent = [responseObject objectForKey:@"result"] && [[responseObject objectForKey:@"result"] isEqualToString:@"ok"];
        }
        
        
        if(requestWasSuccessfullySent) {
            self.lastSentDate = NSDate.date;
            NSDictionary *geocode = [responseObject objectForKey:@"geocode"];
            if(geocode && ![geocode isEqual:[NSNull null]]) {
                self.lastLocationName = [geocode objectForKey:@"full_name"];
            } else {
                self.lastLocationName = @"";
            }
            
            [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
                for(NSString *key in syncedUpdates) {
                    [accessor removeDictionaryForKey:key];
                }
            }];

            [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
                [accessor countObjectsUsingBlock:^(long num) {
                    _currentPointsInQueue = num;
                    NSLog(@"Number remaining: %ld", num);
                    if(num >= self.pointsPerBatchCurrentValue) {
                        self.batchInProgress = YES;
                    } else {
                        self.batchInProgress = NO;
                    }
                }];

                [self sendingFinished];
            }];
            
        } else {
            
            self.batchInProgress = NO;
            
            if([responseObject objectForKey:@"error"]) {
                [self notify:[responseObject objectForKey:@"error"] withTitle:@"Server Error"];
                [self sendingFinished];
            } else {
                [self notify:@"Server did not acknowledge the data was received, and did not return an error message" withTitle:@"Server Error"];
                [self sendingFinished];
            }
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        self.batchInProgress = NO;
        [self notify:error.localizedDescription withTitle:@"HTTP Error"];
        [self sendingFinished];
    }];
    
}

- (NSString *)stringForProperty:(GLLocationProperty)prop ofLocation:(CLLocation *)location {
    NSString *string;
    switch(prop) {
        case kGLLocationPropertyTimestamp:
            string = [GLManager iso8601DateStringFromDate:location.timestamp];
            break;
        case kGLLocationPropertyLatitude:
            string = [[NSNumber numberWithDouble:((int)(location.coordinate.latitude * 10000000)) / 10000000.0] stringValue];
            break;
        case kGLLocationPropertyLongitude:
            string = [[NSNumber numberWithDouble:((int)(location.coordinate.longitude * 10000000)) / 10000000.0] stringValue];
            break;
            
        case kGLLocationPropertyAccuracy:
            string = [[NSNumber numberWithInt:(int)round(location.horizontalAccuracy)] stringValue];
            break;
        case kGLLocationPropertySpeed:
            string = [[NSNumber numberWithInt:(int)round(location.speed)] stringValue];
            break;
        case kGLLocationPropertyAltitude:
            string = [[NSNumber numberWithInt:(int)round(location.altitude)] stringValue];
            break;
        case kGLLocationPropertyBattery:
            string = [[self currentBatteryLevel] stringValue];
            break;
    }
    return string;
}

- (void)logAction:(NSString *)action {
    if(!self.includeTrackingStats) {
        return;
    }

    [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        NSString *timestamp = [GLManager iso8601DateStringFromDate:[NSDate date]];
        NSMutableDictionary *update = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                      @"type": @"Feature",
                                                                                      @"properties": [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                              @"timestamp": timestamp,
                                                                                              @"action": action,
                                                                                              }]
                                                                                      }];
        [self addMetadataToUpdate:update];
        
        if(self.lastLocation) {
            [update setObject:@{
                                @"type": @"Point",
                                @"coordinates": @[
                                        [NSNumber numberWithDouble:self.lastLocation.coordinate.longitude],
                                        [NSNumber numberWithDouble:self.lastLocation.coordinate.latitude]
                                        ]
                                } forKey:@"geometry"];
        }
        [accessor setDictionary:update forKey:[NSString stringWithFormat:@"%@-log", timestamp]];
    }];
}

- (void)accountInfo:(void(^)(NSString *name))block {
    NSString *endpoint = [[NSUserDefaults standardUserDefaults] stringForKey:GLAPIEndpointDefaultsName];
    [_httpClient GET:endpoint parameters:nil headers:nil progress:NULL success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSDictionary *dict = (NSDictionary *)responseObject;
        block((NSString *)[dict objectForKey:@"name"]);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"Failed to get account info");
    }];
}

- (void)numberOfLocationsInQueue:(void(^)(long num))callback {
    [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        [accessor countObjectsUsingBlock:^(long num) {
            _currentPointsInQueue = num;
            callback(num);
        }];
    }];
}

- (void)numberOfObjectsInQueue:(void(^)(long locations, long trips, long stats))callback {
    [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        __block long locations = 0;
        __block long trips = 0;
        __block long stats = 0;
        [accessor enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *object) {
            NSDictionary *properties = [object objectForKey:@"properties"];
            if([properties objectForKey:@"action"]) {
                stats++;
            } else if([[properties objectForKey:@"type"] isEqualToString:@"trip"]) {
                trips++;
            } else {
                locations++;
            }
            return NO;
        }];
        //NSLog(@"Queue stats: %ld %ld %ld", locations, trips, stats);
        callback(locations, trips, stats);
    }];
}


- (void)requestAuthorizationPermission {
    bool isFirstRequest = false;
    if (@available(iOS 14.0, *)) {
        if(self.locationManager.authorizationStatus == kCLAuthorizationStatusNotDetermined) {
            isFirstRequest = true;
        }
    }
    if(isFirstRequest) {
        NSLog(@"Requesting WhenInUse Permission");
        [self.locationManager requestWhenInUseAuthorization];
    } else {
        NSLog(@"Requesting Always Permission");
        [self.locationManager requestAlwaysAuthorization];
    }
}


#pragma mark - GLManager control (private)

- (void)setupHTTPClient {
    NSURL *endpoint = [NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:GLAPIEndpointDefaultsName]];
    
    if(endpoint) {
        _httpClient = [[AFHTTPSessionManager manager] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@://%@", endpoint.scheme, endpoint.host]]];
        _httpClient.requestSerializer = [AFJSONRequestSerializer serializer];
        _httpClient.responseSerializer = [AFJSONResponseSerializer serializer];
        if(self.apiAccessToken != nil && ![@"" isEqualToString:self.apiAccessToken]) {
            [_httpClient.requestSerializer setValue:[NSString stringWithFormat:@"Bearer %@", self.apiAccessToken]
                                 forHTTPHeaderField:@"Authorization"];
        } else {
            [_httpClient.requestSerializer setValue:nil forHTTPHeaderField:@"Authorization"];
        }
    }
    
    _deviceId = [self deviceId];
}

- (void)restoreTrackingState {
    if([[NSUserDefaults standardUserDefaults] boolForKey:GLTrackingStateDefaultsName]) {
        [self enableTracking];
        if(self.tripInProgress) {
            // If a trip is in progress, open the trip DB now
            [self.tripdb open];
        }
    } else {
        [self disableTracking];
    }
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    [[NSNotificationCenter defaultCenter] postNotificationName:GLAuthorizationStatusChangedNotification object:self];
    NSLog(@"Location Authorization Changed: %@", self.authorizationStatusAsString);
}

- (void)enableTracking {
    self.trackingEnabled = YES;

    if(self.tripInProgress) {
        self.locationManager.activityType = self.activityTypeDuringTrip;
        self.locationManager.desiredAccuracy = self.desiredAccuracyDuringTrip;
        self.locationManager.showsBackgroundLocationIndicator = self.showBackgroundLocationIndicatorDuringTrip;
    } else {
        self.locationManager.activityType = self.activityType;
        self.locationManager.desiredAccuracy = self.desiredAccuracy;
        self.locationManager.showsBackgroundLocationIndicator = self.showBackgroundLocationIndicator;
    }

    if(self.tripInProgress) {
        NSLog(@"Monitoring standard location changes during trip");
        [self.locationManager startUpdatingLocation];
        [self.locationManager startUpdatingHeading];
        [self.locationManager stopMonitoringSignificantLocationChanges];
    } else {
        switch(self.trackingMode) {
            case kGLTrackingModeOff:
                NSLog(@"Not monitoring continuous location");
                [self.locationManager stopUpdatingLocation];
                [self.locationManager stopUpdatingHeading];
                [self.locationManager stopMonitoringSignificantLocationChanges];
                break;
            case kGLTrackingModeStandard:
                NSLog(@"Monitoring standard location changes");
                [self.locationManager startUpdatingLocation];
                [self.locationManager startUpdatingHeading];
                [self.locationManager stopMonitoringSignificantLocationChanges];
                break;
            case kGLTrackingModeSignificant:
                NSLog(@"Monitoring significant location changes");
                [self.locationManager startMonitoringSignificantLocationChanges];
                [self.locationManager stopUpdatingLocation];
                [self.locationManager stopUpdatingHeading];
                break;
            case kGLTrackingModeStandardAndSignificant:
                NSLog(@"Monitoring both standard and significant location changes");
                [self.locationManager startUpdatingLocation];
                [self.locationManager startUpdatingHeading];
                [self.locationManager startMonitoringSignificantLocationChanges];
                break;
        }
    }
    
    if(self.visitTrackingEnabled) {
        [self.locationManager startMonitoringVisits];
    } else {
        [self.locationManager stopMonitoringVisits];
    }
    
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    
    if(CMMotionActivityManager.isActivityAvailable) {
        [self.motionActivityManager startActivityUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMMotionActivity *activity) {
            self.lastMotion = activity;
            [[NSNotificationCenter defaultCenter] postNotificationName:GLNewActivityNotification object:self];
        }];
    }

    NSLog(@"Location Authorization Status %@", self.authorizationStatusAsString);
    
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
                       GLTripModeCar, GLTripModeTaxi, GLTripModeBus,
                       GLTripModeTram, GLTripModeTrain, GLTripModeMetro,
                       GLTripModeGondola, GLTripModeMonorail, GLTripModeSleigh,
                       GLTripModePlane, GLTripModeBoat, GLTripModeScooter];
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

- (NSDictionary *)currentTripStartLocationDictionary {
    if(!self.tripInProgress) {
        self.tripStartLocationDictionary = nil;
        return nil;
    }
    if(self.tripStartLocationDictionary == nil) {
        NSDictionary *startLocation = (NSDictionary *)[[NSUserDefaults standardUserDefaults] objectForKey:GLTripStartLocationDefaultsName];
        self.tripStartLocationDictionary = startLocation;
    }
    return self.tripStartLocationDictionary;
}

- (NSDictionary *)currentTripDictionary {
    return @{
            @"mode": self.currentTripMode,
            @"start": [GLManager iso8601DateStringFromDate:self.currentTripStart],
            @"distance": [NSNumber numberWithDouble:self.currentTripDistance],
            @"start_location": (self.currentTripStartLocationDictionary ?: [NSNull null]),
            @"current_location": (self.lastLocationDictionary ?: [NSNull null]),
    };
}

- (void)startTrip {
    if(self.tripInProgress) {
        return;
    }
    
    [self sendQueueNow];

    [self.tripdb open];
    _currentTripDistanceCached = 0;
    _currentTripHasNewData = NO;
    
    NSDate *startDate = [NSDate date];
    [[NSUserDefaults standardUserDefaults] setObject:startDate forKey:GLTripStartTimeDefaultsName];
    
    _storeNextLocationAsTripStart = YES;
    NSLog(@"Store next location as trip start. Current trip start: %@", self.tripStartLocationDictionary);

    [self startAllUpdates];

    NSLog(@"Started a trip at %@", startDate);
    
    [self incrementTripMode:self.currentTripMode];
}

- (void)endTrip {
    [self endTripFromAutopause:NO];
}

- (void)endTripFromAutopause:(BOOL)autopause {
    _storeNextLocationAsTripStart = NO;

    // Restore locationManager settings to values not during a trip
    self.locationManager.activityType = self.activityType;
    self.locationManager.desiredAccuracy = self.desiredAccuracy;
    self.locationManager.showsBackgroundLocationIndicator = self.showBackgroundLocationIndicator;

    if(!self.tripInProgress) {
        return;
    }

    if([CMPedometer isStepCountingAvailable]) {
        [self.pedometer queryPedometerDataFromDate:self.currentTripStart toDate:[NSDate date] withHandler:^(CMPedometerData *pedometerData, NSError *error) {
            if(pedometerData) {
                [self writeTripToDB:autopause steps:[pedometerData.numberOfSteps integerValue]];
            } else {
                [self writeTripToDB:autopause steps:0];
            }
        }];
    } else {
        [self writeTripToDB:autopause steps:0];
    }
    
    [self sendQueueNow];
}

- (void)incrementTripMode:(NSString *)tripMode {
    NSMutableDictionary *currentStats = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:GLTripModeStatsDefaultsName] mutableCopy];
    if(currentStats == nil) {
        currentStats = [[NSMutableDictionary alloc] init];
    }
    NSNumber *count = [currentStats valueForKey:tripMode];
    NSNumber *newCount;
    if(count != nil) {
        newCount = [NSNumber numberWithInt:[count intValue] + 1];
    } else {
        newCount = @1;
    }
    [currentStats setValue:newCount forKey:tripMode];
    [self tripModesByFrequency];
    [[NSUserDefaults standardUserDefaults] setValue:currentStats forKey:GLTripModeStatsDefaultsName];
}

- (NSArray *)tripModesByFrequency {
    NSDictionary *currentStats = [[NSUserDefaults standardUserDefaults] dictionaryForKey:GLTripModeStatsDefaultsName];
    NSArray *tripModes = [currentStats keysSortedByValueUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [(NSNumber*)obj2 compare:(NSNumber*)obj1];
    }];
    return tripModes;
}

- (void)writeTripToDB:(BOOL)autopause steps:(NSInteger)numberOfSteps {

    [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        NSString *timestamp = [GLManager iso8601DateStringFromDate:[NSDate date]];
        NSDictionary *currentTrip = @{
                                      @"type": @"Feature",
                                      @"geometry": @{
                                              @"type": @"Point",
                                              @"coordinates": @[
                                                      [NSNumber numberWithDouble:self.lastLocation.coordinate.longitude],
                                                      [NSNumber numberWithDouble:self.lastLocation.coordinate.latitude]
                                                      ]
                                              },
                                      @"properties": [NSMutableDictionary dictionaryWithDictionary:@{
                                              @"timestamp": timestamp,
                                              @"type": @"trip",
                                              @"mode": self.currentTripMode,
                                              @"start": [GLManager iso8601DateStringFromDate:self.currentTripStart],
                                              @"end": timestamp,
                                              @"start_location": (self.tripStartLocationDictionary ?: [NSNull null]),
                                              @"end_location":(self.lastLocationDictionary ?: [NSNull null]),
                                              @"duration": [NSNumber numberWithDouble:self.currentTripDuration],
                                              @"distance": [NSNumber numberWithDouble:self.currentTripDistance],
                                              @"stopped_automatically": @(autopause),
                                              @"steps": [NSNumber numberWithInteger:numberOfSteps],
                                              }]
                                      };
        [self addMetadataToUpdate:currentTrip];
        if(autopause) {
            [self notify:@"Trip ended automatically" withTitle:@"Tracker"];
        }
        [accessor setDictionary:currentTrip forKey:[NSString stringWithFormat:@"%@-trip",timestamp]];
    }];

    self.tripStartLocationDictionary = nil;
    [[NSUserDefaults standardUserDefaults] setObject:nil forKey:GLTripStartTimeDefaultsName];
    [[NSUserDefaults standardUserDefaults] setObject:nil forKey:GLTripStartLocationDefaultsName];

    _currentTripDistanceCached = 0;
    [self clearTripDB];
    [self.tripdb close];
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:GLTripStartTimeDefaultsName];
    NSLog(@"Ended a %@ trip", self.currentTripMode);
}

#pragma mark - Properties

- (CLLocationManager *)locationManager {
    if (!_locationManager) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.distanceFilter = kCLDistanceFilterNone;
        _locationManager.allowsBackgroundLocationUpdates = YES;
        if(self.tripInProgress) {
            _locationManager.pausesLocationUpdatesAutomatically = NO;
            _locationManager.desiredAccuracy = self.desiredAccuracyDuringTrip;
            _locationManager.activityType = self.activityTypeDuringTrip;
        } else {
            _locationManager.pausesLocationUpdatesAutomatically = self.pausesAutomatically;
            _locationManager.desiredAccuracy = self.desiredAccuracy;
            _locationManager.activityType = self.activityType;
        }
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
    return [NSNumber numberWithDouble:((int)([UIDevice currentDevice].batteryLevel * 100)) / 100.0];
}

- (NSString *)authorizationStatusAsString {
    if (@available(iOS 14.0, *)) {
        switch(self.locationManager.authorizationStatus) {
            case kCLAuthorizationStatusNotDetermined:
                return @"Not Determined";
            case kCLAuthorizationStatusRestricted:
                return @"Restricted";
            case kCLAuthorizationStatusDenied:
                return @"Denied";
            case kCLAuthorizationStatusAuthorizedWhenInUse:
                return @"When in Use";
            case kCLAuthorizationStatusAuthorizedAlways:
                return @"Always";
        }
    } else {
        return @"Unknown";
    }
}

- (BOOL)shouldConsiderHTTP200Success {
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    return [standardUserDefaults boolForKey:GLConsiderHTTP200SuccessDefaultsName];
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
}

- (CLLocationDistance)discardPointsWithinDistance {
    if([self defaultsKeyExists:GLDiscardPointsWithinDistanceDefaultsName]) {
        return [[NSUserDefaults standardUserDefaults] doubleForKey:GLDiscardPointsWithinDistanceDefaultsName];
    } else {
        return -1;
    }
}
- (void)setDiscardPointsWithinDistance:(CLLocationDistance)distance {
    [[NSUserDefaults standardUserDefaults] setDouble:distance forKey:GLDiscardPointsWithinDistanceDefaultsName];
}

- (CLLocationDistance)discardPointsWithinDistanceDuringTrip {
    if([self defaultsKeyExists:GLTripDiscardPointsWithinDistanceDefaultsName]) {
        return [[NSUserDefaults standardUserDefaults] doubleForKey:GLTripDiscardPointsWithinDistanceDefaultsName];
    } else {
        return -1;
    }
}
- (void)setDiscardPointsWithinDistanceDuringTrip:(CLLocationDistance)distance {
    [[NSUserDefaults standardUserDefaults] setDouble:distance forKey:GLTripDiscardPointsWithinDistanceDefaultsName];
}

- (CLLocationDistance)discardPointsWithinDistanceCurrentValue {
    if(self.tripInProgress) {
        return self.discardPointsWithinDistanceDuringTrip;
    } else {
        return self.discardPointsWithinDistance;
    }
}

- (int)discardPointsWithinSeconds {
    if([self defaultsKeyExists:GLDiscardPointsWithinSecondsDefaultsName]) {
        return (int)[[NSUserDefaults standardUserDefaults] integerForKey:GLDiscardPointsWithinSecondsDefaultsName];
    } else {
        return 1;
    }
}
- (void)setDiscardPointsWithinSeconds:(int)seconds {
    [[NSUserDefaults standardUserDefaults] setInteger:seconds forKey:GLDiscardPointsWithinSecondsDefaultsName];
}

- (int)discardPointsWithinSecondsDuringTrip {
    if([self defaultsKeyExists:GLTripDiscardPointsWithinSecondsDefaultsName]) {
        return (int)[[NSUserDefaults standardUserDefaults] integerForKey:GLTripDiscardPointsWithinSecondsDefaultsName];
    } else {
        return 1;
    }
}
- (void)setDiscardPointsWithinSecondsDuringTrip:(int)seconds {
    [[NSUserDefaults standardUserDefaults] setInteger:seconds forKey:GLTripDiscardPointsWithinSecondsDefaultsName];
}

- (int)discardPointsWithinSecondsCurrentValue {
    if(self.tripInProgress) {
        return self.discardPointsWithinSecondsDuringTrip;
    } else {
        return self.discardPointsWithinSeconds;
    }
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
    self.locationManager.pausesLocationUpdatesAutomatically = pausesAutomatically;
}

- (BOOL)includeTrackingStats {
    if([self defaultsKeyExists:GLIncludeTrackingStatsDefaultsName]) {
        return [[NSUserDefaults standardUserDefaults] boolForKey:GLIncludeTrackingStatsDefaultsName];
    } else {
        return NO;
    }
}
- (void)setIncludeTrackingStats:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:GLIncludeTrackingStatsDefaultsName];
}

- (GLTrackingMode)trackingMode {
    if([self defaultsKeyExists:GLSignificantLocationModeDefaultsName]) {
        return (int)[[NSUserDefaults standardUserDefaults] integerForKey:GLSignificantLocationModeDefaultsName];
    } else {
        return kGLTrackingModeStandard;
    }
}
- (void)setTrackingMode:(GLTrackingMode)trackingMode {
    [[NSUserDefaults standardUserDefaults] setInteger:trackingMode forKey:GLSignificantLocationModeDefaultsName];
    [self enableTracking];
}

- (BOOL)visitTrackingEnabled {
    if([self defaultsKeyExists:GLVisitTrackingEnabledDefaultsName]) {
        return [[NSUserDefaults standardUserDefaults] boolForKey:GLVisitTrackingEnabledDefaultsName];
    } else {
        return NO;
    }
}
- (void)setVisitTrackingEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:GLVisitTrackingEnabledDefaultsName];
    [self enableTracking];
}

- (GLLoggingMode)loggingMode {
    if([self defaultsKeyExists:GLLoggingModeDefaultsName]) {
        return (int)[[NSUserDefaults standardUserDefaults] integerForKey:GLLoggingModeDefaultsName];
    } else {
        return kGLLoggingModeAllData;
    }
}
- (void)setLoggingMode:(GLLoggingMode)loggingMode {
    [[NSUserDefaults standardUserDefaults] setInteger:loggingMode forKey:GLLoggingModeDefaultsName];
}

- (GLLoggingMode)loggingModeDuringTrip {
    if([self defaultsKeyExists:GLTripLoggingModeDefaultsName]) {
        return (int)[[NSUserDefaults standardUserDefaults] integerForKey:GLTripLoggingModeDefaultsName];
    } else {
        return kGLLoggingModeAllData;
    }
}
- (void)setLoggingModeDuringTrip:(GLLoggingMode)loggingMode {
    [[NSUserDefaults standardUserDefaults] setInteger:loggingMode forKey:GLTripLoggingModeDefaultsName];
}

- (GLLoggingMode)loggingModeCurrentValue {
    if(self.tripInProgress) {
        return self.loggingModeDuringTrip;
    } else {
        return self.loggingMode;
    }
}

- (BOOL)showBackgroundLocationIndicator {
    if([self defaultsKeyExists:GLBackgroundIndicatorDefaultsName]) {
        return [[NSUserDefaults standardUserDefaults] boolForKey:GLBackgroundIndicatorDefaultsName];
    } else {
        return NO;
    }
}
- (void)setShowBackgroundLocationIndicator:(BOOL)mode {
    [[NSUserDefaults standardUserDefaults] setBool:mode forKey:GLBackgroundIndicatorDefaultsName];
    if(self.trackingEnabled && !self.tripInProgress) {
        self.locationManager.showsBackgroundLocationIndicator = mode;
    }
}

- (BOOL)showBackgroundLocationIndicatorDuringTrip {
    if([self defaultsKeyExists:GLTripBackgroundIndicatorDefaultsName]) {
        return [[NSUserDefaults standardUserDefaults] boolForKey:GLTripBackgroundIndicatorDefaultsName];
    } else {
        return YES;
    }
}
- (void)setShowBackgroundLocationIndicatorDuringTrip:(BOOL)mode {
    [[NSUserDefaults standardUserDefaults] setBool:mode forKey:GLTripBackgroundIndicatorDefaultsName];
    if(self.tripInProgress) {
        self.locationManager.showsBackgroundLocationIndicator = mode;
    }
}

- (CLActivityType)activityType {
    if([self defaultsKeyExists:GLActivityTypeDefaultsName]) {
        // Map back to CLActivityType constants
        long activityInt = [[NSUserDefaults standardUserDefaults] integerForKey:GLActivityTypeDefaultsName];
        CLActivityType activityType;
        switch(activityInt) {
            case 1:
                activityType = CLActivityTypeOther;
                break;
            case 2:
                activityType = CLActivityTypeAutomotiveNavigation;
                break;
            case 3:
                activityType = CLActivityTypeFitness;
                break;
            case 4:
                activityType = CLActivityTypeOtherNavigation;
                break;
            case 5:
                if (@available(iOS 12.0, *)) {
                    activityType = CLActivityTypeAirborne;
                } else {
                    activityType = CLActivityTypeOther;
                }
                break;
            default:
                activityType = CLActivityTypeOther;
                break;
        }
        return activityType;
    } else {
        return CLActivityTypeOther;
    }
}
- (void)setActivityType:(CLActivityType)activityType {
    // Store these as integers, in the same order as the UI control
    int activityInt;
    switch(activityType) {
        case CLActivityTypeOther:
            activityInt = 1;
            break;
        case CLActivityTypeAutomotiveNavigation:
            activityInt = 2;
            break;
        case CLActivityTypeFitness:
            activityInt = 3;
            break;
        case CLActivityTypeOtherNavigation:
            activityInt = 4;
            break;
        case CLActivityTypeAirborne:
            if (@available(iOS 12.0, *)) {
                activityInt = 5;
            } else {
                activityInt = 1;
            }
            break;
    }
    [[NSUserDefaults standardUserDefaults] setInteger:activityInt forKey:GLActivityTypeDefaultsName];
    self.locationManager.activityType = activityType;
}

- (CLActivityType)activityTypeDuringTrip {
    if([self defaultsKeyExists:GLTripActivityTypeDefaultsName]) {
        // Map back to CLActivityType constants
        long activityInt = [[NSUserDefaults standardUserDefaults] integerForKey:GLTripActivityTypeDefaultsName];
        CLActivityType activityType;
        switch(activityInt) {
            case 1:
                activityType = CLActivityTypeOther;
                break;
            case 2:
                activityType = CLActivityTypeAutomotiveNavigation;
                break;
            case 3:
                activityType = CLActivityTypeFitness;
                break;
            case 4:
                activityType = CLActivityTypeOtherNavigation;
                break;
            case 5:
                if (@available(iOS 12.0, *)) {
                    activityType = CLActivityTypeAirborne;
                } else {
                    activityType = CLActivityTypeOther;
                }
                break;
            default:
                activityType = CLActivityTypeOther;
                break;
        }
        return activityType;
    } else {
        return CLActivityTypeOther;
    }
}
- (void)setActivityTypeDuringTrip:(CLActivityType)activityType {
    // Store these as integers, in the same order as the UI control
    int activityInt;
    switch(activityType) {
        case CLActivityTypeOther:
            activityInt = 1;
            break;
        case CLActivityTypeAutomotiveNavigation:
            activityInt = 2;
            break;
        case CLActivityTypeFitness:
            activityInt = 3;
            break;
        case CLActivityTypeOtherNavigation:
            activityInt = 4;
            break;
        case CLActivityTypeAirborne:
            if (@available(iOS 12.0, *)) {
                activityInt = 5;
            } else {
                activityInt = 1;
            }
            break;
    }
    [[NSUserDefaults standardUserDefaults] setInteger:activityInt forKey:GLTripActivityTypeDefaultsName];
}

- (CLLocationAccuracy)desiredAccuracy {
    if([self defaultsKeyExists:GLDesiredAccuracyDefaultsName]) {
        return [[NSUserDefaults standardUserDefaults] doubleForKey:GLDesiredAccuracyDefaultsName];
    } else {
        return kCLLocationAccuracyHundredMeters;
    }
}
- (void)setDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy {
    [[NSUserDefaults standardUserDefaults] setDouble:desiredAccuracy forKey:GLDesiredAccuracyDefaultsName];
    if(!self.tripInProgress) {
        self.locationManager.desiredAccuracy = desiredAccuracy;
    }
}

- (CLLocationAccuracy)desiredAccuracyDuringTrip {
    if([self defaultsKeyExists:GLTripDesiredAccuracyDefaultsName]) {
        return [[NSUserDefaults standardUserDefaults] doubleForKey:GLTripDesiredAccuracyDefaultsName];
    } else {
        return kCLLocationAccuracyHundredMeters;
    }
}
- (void)setDesiredAccuracyDuringTrip:(CLLocationAccuracy)desiredAccuracy {
    [[NSUserDefaults standardUserDefaults] setDouble:desiredAccuracy forKey:GLTripDesiredAccuracyDefaultsName];
    if(self.tripInProgress) {
        self.locationManager.desiredAccuracy = desiredAccuracy;
    }
}

- (int)pointsPerBatch {
    if([self defaultsKeyExists:GLPointsPerBatchDefaultsName]) {
        return (int)[[NSUserDefaults standardUserDefaults] integerForKey:GLPointsPerBatchDefaultsName];
    } else {
        return 200;
    }
}
- (void)setPointsPerBatch:(int)points {
    [[NSUserDefaults standardUserDefaults] setInteger:points forKey:GLPointsPerBatchDefaultsName];
}

- (int)pointsPerBatchDuringTrip {
    if([self defaultsKeyExists:GLTripPointsPerBatchDefaultsName]) {
        return (int)[[NSUserDefaults standardUserDefaults] integerForKey:GLTripPointsPerBatchDefaultsName];
    } else {
        return 200;
    }
}
- (void)setPointsPerBatchDuringTrip:(int)points {
    [[NSUserDefaults standardUserDefaults] setInteger:points forKey:GLTripPointsPerBatchDefaultsName];
}

- (int)pointsPerBatchCurrentValue {
    if(self.tripInProgress) {
        return self.pointsPerBatchDuringTrip;
    } else {
        return self.pointsPerBatch;
    }
}

#pragma mark GLManager

- (NSNumber *)sendingInterval {
    if(_sendingInterval)
        return _sendingInterval;
    
    _sendingInterval = (NSNumber *)[[NSUserDefaults standardUserDefaults] valueForKey:GLSendIntervalDefaultsName];
    if(_sendingInterval == nil) {
        _sendingInterval = [NSNumber numberWithInteger:300];
    }
    return _sendingInterval;
}

- (void)setSendingInterval:(NSNumber *)newValue {
    [[NSUserDefaults standardUserDefaults] setValue:newValue forKey:GLSendIntervalDefaultsName];
    _sendingInterval = newValue;
}

- (NSDate *)lastSentDate {
    return (NSDate *)[[NSUserDefaults standardUserDefaults] objectForKey:GLLastSentDateDefaultsName];
}

- (void)setLastSentDate:(NSDate *)lastSentDate {
    [[NSUserDefaults standardUserDefaults] setObject:lastSentDate forKey:GLLastSentDateDefaultsName];
}

#pragma mark - CLLocationManager Delegate Methods

- (void)locationManager:(CLLocationManager *)manager didVisit:(CLVisit *)visit {

    if(self.visitTrackingEnabled) {
        [[NSNotificationCenter defaultCenter] postNotificationName:GLNewDataNotification object:self];
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
                                      @"properties": [NSMutableDictionary dictionaryWithDictionary:@{
                                              @"timestamp": timestamp,
                                              @"action": @"visit",
                                              @"arrival_date": ([visit.arrivalDate isEqualToDate:[NSDate distantPast]] ? [NSNull null] : [GLManager iso8601DateStringFromDate:visit.arrivalDate]),
                                              @"departure_date": ([visit.departureDate isEqualToDate:[NSDate distantFuture]] ? [NSNull null] : [GLManager iso8601DateStringFromDate:visit.departureDate]),
                                              @"horizontal_accuracy": [NSNumber numberWithInt:visit.horizontalAccuracy],
                                              }]
                                    };
            [self addMetadataToUpdate:update];
            [accessor setDictionary:update forKey:[NSString stringWithFormat:@"%@-visit", timestamp]];
        }];

    }
    
    // If a trip is active, ask if they would like to end the trip
    if(self.tripInProgress) {
        [self askToEndTrip];
    }
    
    [self sendQueueIfTimeElapsed];
}

- (void)deleteAllData {
    [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        [accessor deleteAllData];
    }];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    
    if(self.trackingMode == kGLTrackingModeOff) {
        // This probably shouldn't happen, but just in case, don't log anything if they have tracking mode set to off
        return;
    }
        
    // If a wifi override is configured, replace the input location list with the location in the wifi mapping
    if([GLManager currentWifiHotSpotName]) {
        CLLocation *wifiLocation = [self currentLocationFromWifiName:[GLManager currentWifiHotSpotName]];
        if(wifiLocation) {
            locations = @[wifiLocation];
        }
    }
    
    // NSLog(@"Received %d locations", (int)locations.count);
    
    // NSLog(@"%@", locations);
    
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
        case CLActivityTypeAirborne:
            activityType = @"airborne";
    }
    
    CLLocation *lastLocationSeen = self.lastLocation; // Grab the last known location from the previous batch
    
    int startIndex = 0;
    if(self.loggingModeCurrentValue == kGLLoggingModeOnlyLatest) {
        // Only grab the latest point in this batch
        startIndex = ((int)locations.count) - 1;
    }
    
    BOOL didAddData = NO;
    
    for(int i=startIndex; i<locations.count; i++) {
        CLLocation *loc = locations[i];
        
        // If Discard is enabled, check if this point is too close to the previous
        if(self.discardPointsWithinDistanceCurrentValue > 0) {
            CLLocationDistance distanceBetweenPoints = [lastLocationSeen distanceFromLocation:loc];
            if(distanceBetweenPoints < self.discardPointsWithinDistanceCurrentValue) {
                // NSLog(@"Discarding location because this point is too close to the previous: %f", distanceBetweenPoints);
                continue;
            }
        }

        if(self.discardPointsWithinSecondsCurrentValue > 1) {
            int timeInterval = (int)[loc.timestamp timeIntervalSinceDate:lastLocationSeen.timestamp];
            if(timeInterval < self.discardPointsWithinSecondsCurrentValue) {
                continue;
            }
        }
        
        NSString *timestamp = [GLManager iso8601DateStringFromDate:loc.timestamp];
        NSDictionary *update = [self currentDictionaryFromLocation:loc];
        NSMutableDictionary *properties = [update objectForKey:@"properties"];
        if(self.includeTrackingStats) {
            [properties setValue:[NSNumber numberWithBool:self.locationManager.pausesLocationUpdatesAutomatically] forKey:@"pauses"];
            [properties setValue:activityType forKey:@"activity"];
            [properties setValue:[NSNumber numberWithDouble:self.locationManager.desiredAccuracy] forKey:@"desired_accuracy"];
            [properties setValue:[NSNumber numberWithInt:self.trackingMode] forKey:@"tracking_mode"];
            [properties setValue:[NSNumber numberWithLong:locations.count] forKey:@"locations_in_payload"];
        }
        // Add the trip start time as trip_id in the location update
        if(self.tripInProgress) {
            [properties setValue:[GLManager iso8601DateStringFromDate:self.currentTripStart] forKey:@"trip_id"];
        }

        // Queue the point in the database
        [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
            if(self.loggingModeCurrentValue == kGLLoggingModeOnlyLatest) {
                // Delete everything in the DB so that this new point is the only one in the queue after it's added below
                [accessor deleteAllData];
            }
            [accessor setDictionary:update forKey:timestamp];
        }];
        didAddData = YES;
        
        if([loc.timestamp timeIntervalSinceDate:self.currentTripStart] >= 0  // only if the location is newer than the trip start
           && loc.horizontalAccuracy <= 200 // only if the location is accurate enough
           ) {

            if(_storeNextLocationAsTripStart) {
                [[NSUserDefaults standardUserDefaults] setObject:update forKey:GLTripStartLocationDefaultsName];
                self.tripStartLocationDictionary = update;
                _storeNextLocationAsTripStart = NO;
            }
            
            // If a trip is in progress, add to the trip's list too (for calculating trip distance)
            if(self.tripInProgress) {
                [self.tripdb executeUpdate:@"INSERT INTO trips (timestamp, latitude, longitude) VALUES (?, ?, ?)", [NSNumber numberWithInt:[loc.timestamp timeIntervalSince1970]], [NSNumber numberWithDouble:loc.coordinate.latitude], [NSNumber numberWithDouble:loc.coordinate.longitude]];
                _currentTripHasNewData = YES;
            }
        }

        self.lastLocation = loc;
        self.lastLocationDictionary = [self currentDictionaryFromLocation:self.lastLocation];

    }

    if(didAddData) {
        [[NSNotificationCenter defaultCenter] postNotificationName:GLNewDataNotification object:self];
    }

    [self sendQueueIfTimeElapsed];
}

- (void)addMetadataToUpdate:(NSDictionary *) update {
    NSMutableDictionary *properties = [update objectForKey:@"properties"];
    if(_deviceId && _deviceId.length > 0) {
        [properties setValue:_deviceId forKey:@"device_id"];
    }
    [properties setValue:[GLManager currentWifiHotSpotName] forKey:@"wifi"];
    [properties setValue:[self currentBatteryState] forKey:@"battery_state"];
    [properties setValue:[self currentBatteryLevel] forKey:@"battery_level"];
    if([[NSUserDefaults standardUserDefaults] boolForKey:GLIncludeUniqueIdDefaultsName]) {
        NSString *uniqueId = [UIDevice currentDevice].identifierForVendor.UUIDString;
        [properties setValue:uniqueId forKey:@"unique_id"];
    }
}

- (NSDictionary *)currentDictionaryFromLocation:(CLLocation *)loc {
    NSString *timestamp = [GLManager iso8601DateStringFromDate:loc.timestamp];
    NSDictionary *update = @{
             @"type": @"Feature",
             @"geometry": @{
                     @"type": @"Point",
                     @"coordinates": @[
                             [NSNumber numberWithDouble:((int)(loc.coordinate.longitude * 10000000)) / 10000000.0],
                             [NSNumber numberWithDouble:((int)(loc.coordinate.latitude * 10000000)) / 10000000.0]
                             ]
                     },
             @"properties": [NSMutableDictionary dictionaryWithDictionary:@{
                     @"timestamp": timestamp,
                     @"altitude": [NSNumber numberWithInt:(int)round(loc.altitude)],
                     @"speed": [NSNumber numberWithInt:(int)round(loc.speed)],
                     @"horizontal_accuracy": [NSNumber numberWithInt:(int)round(loc.horizontalAccuracy)],
                     @"vertical_accuracy": [NSNumber numberWithInt:(int)round(loc.verticalAccuracy)],
                     @"motion": [self motionArrayFromLastMotion],
                     }]
             };
    [self addMetadataToUpdate:update];
    return update;
}

- (NSArray *)motionArrayFromLastMotion {
    NSMutableArray *motion = [[NSMutableArray alloc] init];
    CMMotionActivity *motionActivity = [GLManager sharedManager].lastMotion;
    if(motionActivity.walking)
        [motion addObject:@"walking"];
    if(motionActivity.running)
        [motion addObject:@"running"];
    if(motionActivity.cycling)
        [motion addObject:@"cycling"];
    if(motionActivity.automotive)
        [motion addObject:@"driving"];
    if(motionActivity.stationary)
        [motion addObject:@"stationary"];
    return [NSArray arrayWithArray:motion];
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
    NSLog(@"Did exit region");
    [self logAction:@"exited_pause_region"];
    [self notify:@"Starting updates from exiting the geofence" withTitle:@"Resumed"];
    [self.locationManager stopMonitoringForRegion:region];
    [self enableTracking];
}

- (void)locationManagerDidResumeLocationUpdates:(CLLocationManager *)manager {
    [self logAction:@"resumed_location_updates"];
    [self notify:@"Location updates resumed" withTitle:@"Resumed"];
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

#pragma mark - Notifications

- (BOOL)notificationsEnabled {
    if([self defaultsKeyExists:GLNotificationsEnabledDefaultsName]) {
        return [[NSUserDefaults standardUserDefaults] boolForKey:GLNotificationsEnabledDefaultsName];
    } else {
        return NO;
    }
}
- (void)setNotificationsEnabled:(BOOL)enabled {
    if(enabled) {
        [self requestNotificationPermission];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:GLNotificationsEnabledDefaultsName];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:GLNotificationPermissionRequestedDefaultsName];
    }
}

- (void)initializeNotifications {
    UNUserNotificationCenter *notificationCenter = [UNUserNotificationCenter currentNotificationCenter];
    notificationCenter.delegate = self;
    
    // If notifications were successfully requested previously, initialize again for this app launch
    if([[NSUserDefaults standardUserDefaults] boolForKey:GLNotificationPermissionRequestedDefaultsName]) {
        [self requestNotificationPermission];
    }
    
    UNNotificationAction *endTripAction = [UNNotificationAction actionWithIdentifier:@"END_TRIP" title:@"End Trip" options:UNNotificationActionOptionNone];
    UNNotificationCategory *actionCategory = [UNNotificationCategory categoryWithIdentifier:GLNotificationCategoryTripName
                                                                                    actions:@[endTripAction]
                                                                          intentIdentifiers:@[]
                                                                                    options:UNNotificationCategoryOptionNone];
    [notificationCenter setNotificationCategories:[NSSet setWithArray:@[actionCategory]]];
}

- (void)requestNotificationPermission {
    UNUserNotificationCenter *notificationCenter = [UNUserNotificationCenter currentNotificationCenter];

    UNAuthorizationOptions options = UNAuthorizationOptionAlert + UNAuthorizationOptionSound;
    [notificationCenter requestAuthorizationWithOptions:options
                                      completionHandler:^(BOOL granted, NSError * _Nullable error) {
                                          // If the user denies permission, set requested=NO so that if they ever enable it in settings again the permission will be requested again
                                          [[NSUserDefaults standardUserDefaults] setBool:granted forKey:GLNotificationPermissionRequestedDefaultsName];
                                          [[NSUserDefaults standardUserDefaults] setBool:granted forKey:GLNotificationsEnabledDefaultsName];
                                          if(!granted) {
                                              NSLog(@"User did not allow notifications");
                                          }
                                      }];
}

- (void)notify:(NSString *)message withTitle:(NSString *)title
{
    if([self notificationsEnabled]) {
        UNUserNotificationCenter *notificationCenter = [UNUserNotificationCenter currentNotificationCenter];
        
        UNMutableNotificationContent *content = [UNMutableNotificationContent new];
        content.title = title;
        content.body = message;
        content.sound = [UNNotificationSound defaultSound];
        
        /* UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1 repeats:NO]; */
        
        NSString *identifier = @"GLLocalNotification";
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                                                              content:content
                                                                              trigger:nil];
        
        [notificationCenter addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
            if (error != nil) {
                NSLog(@"Something went wrong: %@",error);
            } else {
                NSLog(@"Notification sent");
            }
        }];
    }
}

/* Force notifications to display as normal when the app is active */
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    
    completionHandler(UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner);
}

- (void)askToEndTrip
{
    if(self.notificationsEnabled) {
        UNUserNotificationCenter *notificationCenter = [UNUserNotificationCenter currentNotificationCenter];

        UNMutableNotificationContent *content = [UNMutableNotificationContent new];
        content.title = @"End Trip";
        content.body = @"It looks like you stopped moving, would you like to end the current trip?";
        content.sound = [UNNotificationSound defaultSound];
        content.categoryIdentifier = GLNotificationCategoryTripName;
        
        NSString *identifier = @"GLLocalNotificationEndTripPrompt";
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                                                              content:content
                                                                              trigger:nil];

        [notificationCenter addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
            if(error != nil) {
                NSLog(@"Something went wrong trying to ask to end the trip: %@", error);
            } else{
                NSLog(@"Notification sent");
            }
        }];
    }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(nonnull UNNotificationResponse *)response withCompletionHandler:(nonnull void (^)(void))completionHandler
{
    if([@"END_TRIP" isEqualToString:response.actionIdentifier]) {
        [self endTrip];

        // If location updates were off when the trip was started, disable location now
        if([[NSUserDefaults standardUserDefaults] boolForKey:GLTripTrackingEnabledDefaultsName] == NO) {
            [[GLManager sharedManager] stopAllUpdates];
        }
    }
    
    completionHandler();
}


#pragma mark - Wifi Positioning

/*
 Allow the user to configure wifi names mapping to locations. If the phone is connected to
 one of the known wifi names, use the configured location instead of the phone's reported location.
 This should help avoid GPS drift around common locations like "home" and "work", and can
 also be used to pause location updates when the user gets home.
*/

- (CLLocation *)currentLocationFromWifiName:(NSString *)wifi {
    if(wifi == nil) {
        return nil;
    }
    
    if(self.wifiZoneName) {
    
        if([self.wifiZoneName isEqualToString:wifi]) {
            double latitude = [self.wifiZoneLatitude floatValue];
            double longitude = [self.wifiZoneLongitude floatValue];
            CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(latitude, longitude);
            NSDate *timestamp = NSDate.date;
            
            CLLocation *loc = [[CLLocation alloc] initWithCoordinate:coord
                                                            altitude:-1
                                                  horizontalAccuracy:1
                                                    verticalAccuracy:0
                                                              course:0
                                                               speed:0
                                                           timestamp:timestamp];
            return loc;
        }
    }
    
    return nil;
}

- (void)saveNewWifiZone:(NSString *)name withLatitude:(NSString *)latitude andLongitude:(NSString *)longitude {
    
    [[NSUserDefaults standardUserDefaults] setObject:name forKey:@"WifiZoneName"];
    [[NSUserDefaults standardUserDefaults] setObject:latitude forKey:@"WifiZoneLatitude"];
    [[NSUserDefaults standardUserDefaults] setObject:longitude forKey:@"WifiZoneLongitude"];
}
- (NSString *)wifiZoneName {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"WifiZoneName"];
}
- (NSString *)wifiZoneLatitude {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"WifiZoneLatitude"];
}
- (NSString *)wifiZoneLongitude {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"WifiZoneLongitude"];
}


#pragma mark -

- (BOOL)defaultsKeyExists:(NSString *)key {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [[[defaults dictionaryRepresentation] allKeys] containsObject:key];
}

+ (NSString *)currentWifiHotSpotName {
    NSString *wifiName = @"";
    NSArray *ifs = (__bridge_transfer id)CNCopySupportedInterfaces();
    for (NSString *ifnam in ifs) {
        NSDictionary *info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
        if (info[@"SSID"]) {
            wifiName = info[@"SSID"];
        }
    }
    return wifiName;
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
