//
//  GLManager.m
//  GPSLogger
//
//  Created by Aaron Parecki on 9/17/15.
//  Copyright © 2015 Esri. All rights reserved.
//

#import "GLManager.h"
#import "LOLDatabase.h"
#import "AFHTTPSessionManager.h"

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

@end

@implementation GLManager

static NSString *const GLLocationQueueName = @"GLLocationQueue";

NSNumber *_sendingInterval;

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
            
            [_instance setupHTTPClient];
            [_instance restoreTrackingState];
        }
    }
    
    return _instance;
}

#pragma mark LOLDB

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

#pragma mark -

- (void)setupHTTPClient {
    NSURL *endpoint = [NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:GLAPIEndpointDefaultsName]];
    
    _httpClient = [[AFHTTPSessionManager manager] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@://%@", endpoint.scheme, endpoint.host]]];
    _httpClient.requestSerializer = [AFJSONRequestSerializer serializer];
    _httpClient.responseSerializer = [AFJSONResponseSerializer serializer];
}

- (void)restoreTrackingState {
    if([[NSUserDefaults standardUserDefaults] boolForKey:GLTrackingStateDefaultsName]) {
        [self enableTracking];
    } else {
        [self disableTracking];
    }
}

- (void)startAllUpdates {
    [self enableTracking];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:GLTrackingStateDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)enableTracking {
    self.trackingEnabled = YES;
    [self.locationManager requestAlwaysAuthorization];
    [self.locationManager startUpdatingLocation];
    [self.locationManager startUpdatingHeading];
    if(CMMotionActivityManager.isActivityAvailable) {
        [self.motionActivityManager startActivityUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMMotionActivity *activity) {
            [[NSNotificationCenter defaultCenter] postNotificationName:GLNewDataNotification object:self];
            self.lastMotion = activity;
        }];
    }
}

- (void)stopAllUpdates {
    [self disableTracking];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:GLTrackingStateDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)disableTracking {
    self.trackingEnabled = NO;
    [self.locationManager stopUpdatingHeading];
    [self.locationManager stopUpdatingLocation];
    if(CMMotionActivityManager.isActivityAvailable) {
        [self.motionActivityManager stopActivityUpdates];
        self.lastMotion = nil;
    }
}

- (void)refreshLocation {
    NSLog(@"Trying to update location now");
    [self.locationManager stopUpdatingLocation];
    [self.locationManager performSelector:@selector(startUpdatingLocation) withObject:nil afterDelay:1.0];
}

#pragma mark - LocationManager properties

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


- (BOOL)defaultsKeyExists:(NSString *)key {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [[[defaults dictionaryRepresentation] allKeys] containsObject:key];
}
        
#pragma mark -

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

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    [[NSNotificationCenter defaultCenter] postNotificationName:GLNewDataNotification object:self];
    self.lastLocation = (CLLocation *)locations[0];
    
    NSLog(@"Received %d locations", (int)locations.count);
    
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
            NSNumber *timestamp = [NSNumber numberWithInt:(int)round([loc.timestamp timeIntervalSince1970])];
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
                                             @"deferred": [NSNumber numberWithDouble:self.defersLocationUpdates]
                                             }
                                     };
            [accessor setDictionary:update forKey:[timestamp stringValue]];
        }
        
    }];
    
    [self sendQueueIfNecessary];
}

- (void)numberOfLocationsInQueue:(void(^)(long num))callback {
    [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        [accessor countObjectsUsingBlock:callback];
    }];
}

- (void)sendingStarted {
    self.sendInProgress = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:GLSendingStartedNotification object:self];
}

- (void)sendingFinished {
    self.sendInProgress = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:GLSendingFinishedNotification object:self];
}

- (void)sendQueueIfNecessary {
    BOOL sendingEnabled = [self.sendingInterval integerValue] > -1;
    if(!sendingEnabled) {
        return;
    }
    
    if(self.sendInProgress) {
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

    // Send if there is a full batch AND time has elapsed,
    // or if we're in the middle of flushing
    if((numPending >= PointsPerBatch && timeElapsed)
        || self.batchInProgress) {
        NSLog(@"Sending a batch now");
        [self sendQueueNow];
        self.lastSentDate = NSDate.date;
    }
}

- (void)sendQueueNow {
    [self sendingStarted];
    
    NSMutableSet *syncedUpdates = [NSMutableSet set];
    NSMutableArray *locationUpdates = [NSMutableArray array];
    
    [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        
        [accessor enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *object) {
            [syncedUpdates addObject:key];
            [locationUpdates addObject:object];
            return (BOOL)(locationUpdates.count >= PointsPerBatch);
        }];
        
    }];
    
    NSDictionary *postData = @{@"locations": locationUpdates};
    
    NSString *endpoint = [[NSUserDefaults standardUserDefaults] stringForKey:GLAPIEndpointDefaultsName];
    NSLog(@"Endpoint: %@", endpoint);
    NSLog(@"Updates in post: %lu", (unsigned long)locationUpdates.count);
    
    if(locationUpdates.count == 0) {
        self.batchInProgress = NO;
        return;
    }
    
    [_httpClient POST:endpoint parameters:postData success:^(NSURLSessionDataTask *task, id responseObject) {
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
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        self.batchInProgress = NO;
        NSLog(@"Error: %@", error);
        [self notify:error.description withTitle:@"Error"];
        [self sendingFinished];
    }];
    
}

- (NSDate *)lastSentDate {
    return (NSDate *)[[NSUserDefaults standardUserDefaults] objectForKey:GLLastSentDateDefaultsName];
}

- (void)setLastSentDate:(NSDate *)lastSentDate {
    [[NSUserDefaults standardUserDefaults] setObject:lastSentDate forKey:GLLastSentDateDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
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
    [_httpClient GET:endpoint parameters:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nonnull responseObject) {
        NSDictionary *dict = (NSDictionary *)responseObject;
        block((NSString *)[dict objectForKey:@"name"]);
    } failure:^(NSURLSessionDataTask * _Nonnull task, NSError * _Nonnull error) {
        NSLog(@"Failed to get account info");
    }];
}

#pragma mark -

- (void)setSendingInterval:(NSNumber *)newValue {
    [[NSUserDefaults standardUserDefaults] setValue:newValue forKey:GLSendIntervalDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _sendingInterval = newValue;
}

- (NSNumber *)sendingInterval {
    if(_sendingInterval)
        return _sendingInterval;
    
    _sendingInterval = (NSNumber *)[[NSUserDefaults standardUserDefaults] valueForKey:GLSendIntervalDefaultsName];
    return _sendingInterval;
}

@end
