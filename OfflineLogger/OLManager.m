//
//  OLManager.m
//  OfflineLogger
//
//  Created by Aaron Parecki on 10/21/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import "OLManager.h"
#import "LOLDatabase.h"
#import "AFHTTPSessionManager.h"

@interface OLManager()

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CMMotionActivityManager *motionActivityManager;
@property (strong, nonatomic) CMStepCounter *stepCounter;

@property BOOL trackingEnabled;
@property BOOL sendInProgress;
@property (strong, nonatomic) CLLocation *lastLocation;
@property (strong, nonatomic) CMMotionActivity *lastMotion;
@property (strong, nonatomic) NSNumber *lastStepCount;
@property (strong, nonatomic) NSDate *lastSentDate;

@property (strong, nonatomic) LOLDatabase *db;

@end

@implementation OLManager

static NSString *const OLLocationQueueName = @"OLLocationQueue";
static NSString *const OLStepCountQueueName = @"OLStepCountQueue";

NSNumber *_sendingInterval;

AFHTTPSessionManager *_httpClient;

+ (OLManager *)sharedManager {
    static OLManager *_instance = nil;
    
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
            [_instance startStepCounting];
            [_instance restoreTrackingState];
        }
    }
    
    return _instance;
}

#pragma mark LOLDB

+ (NSString *)cacheDatabasePath
{
	NSString *caches = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	return [caches stringByAppendingPathComponent:@"OLLoggerCache.sqlite"];
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

- (void)startStepCounting {
    if(CMStepCounter.isStepCountingAvailable) {
        // Request step count updates every 5 steps, but don't use the step count reported because then I'd have to keep track of the time I started counting steps.
        [self.stepCounter startStepCountingUpdatesToQueue:[NSOperationQueue mainQueue]
                                                 updateOn:5
                                              withHandler:^(NSInteger numberOfSteps, NSDate *timestamp, NSError *error) {
                                                  [self queryStepCount:nil];
                                              }];
    }
}

- (void)setupHTTPClient {
    NSURL *endpoint = [NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:OLAPIEndpointDefaultsName]];
    
    _httpClient = [[AFHTTPSessionManager manager] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@://%@", endpoint.scheme, endpoint.host]]];
    _httpClient.requestSerializer = [AFJSONRequestSerializer serializer];
    _httpClient.responseSerializer = [AFJSONResponseSerializer serializer];
}

- (void)restoreTrackingState {
    if([[NSUserDefaults standardUserDefaults] boolForKey:OLTrackingStateDefaultsName]) {
        [self enableTracking];
    } else {
        [self disableTracking];
    }
}

- (void)startAllUpdates {
    [self enableTracking];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:OLTrackingStateDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)enableTracking {
    self.trackingEnabled = YES;
    [self.locationManager startUpdatingLocation];
    [self.locationManager startUpdatingHeading];
    if(CMMotionActivityManager.isActivityAvailable) {
        [self.motionActivityManager startActivityUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMMotionActivity *activity) {
            [[NSNotificationCenter defaultCenter] postNotificationName:OLNewDataNotification object:self];
            self.lastMotion = activity;
        }];
    }
}

- (void)stopAllUpdates {
    [self disableTracking];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:OLTrackingStateDefaultsName];
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


#pragma mark -

+ (NSDate *)last24Hours {
    return [NSDate dateWithTimeIntervalSinceNow:-86400.0];
}

- (CLLocationManager *)locationManager {
    if (!_locationManager) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        _locationManager.distanceFilter = 1;
    }
    
    return _locationManager;
}

- (CMMotionActivityManager *)motionActivityManager {
    if (!_motionActivityManager) {
        _motionActivityManager = [[CMMotionActivityManager alloc] init];
    }
    
    return _motionActivityManager;
}

- (CMStepCounter *)stepCounter {
    if (!_stepCounter) {
        _stepCounter = [[CMStepCounter alloc] init];
    }
    
    return _stepCounter;
}

- (void)queryStepCount:(void(^)(NSInteger numberOfSteps, NSError *error))handler {
    [self.stepCounter queryStepCountStartingFrom:[OLManager last24Hours]
                                              to:[NSDate date]
                                         toQueue:[NSOperationQueue mainQueue]
                                     withHandler:^(NSInteger numberOfSteps, NSError *error) {
                                         self.lastStepCount = [NSNumber numberWithInteger:numberOfSteps];
                                         if(handler) {
                                             handler(numberOfSteps, error);
                                         }
                                     }];
}

- (void)queryStepCountAtDate:(NSDate *)date withHandler:(void(^)(NSInteger numberOfSteps, NSError *error))handler {
    [self.stepCounter queryStepCountStartingFrom:[OLManager last24Hours]
                                              to:[NSDate date]
                                         toQueue:[NSOperationQueue mainQueue]
                                     withHandler:^(NSInteger numberOfSteps, NSError *error) {
                                         self.lastStepCount = [NSNumber numberWithInteger:numberOfSteps];
                                         if(handler) {
                                             handler(numberOfSteps, error);
                                         }
                                     }];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    [[NSNotificationCenter defaultCenter] postNotificationName:OLNewDataNotification object:self];
    self.lastLocation = (CLLocation *)locations[0];
    
    // Queue the point in the database
	[self.db accessCollection:OLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {

        NSMutableArray *motion = [[NSMutableArray alloc] init];
        CMMotionActivity *activity = [OLManager sharedManager].lastMotion;
        if(activity.walking)
            [motion addObject:@"walking"];
        if(activity.running)
            [motion addObject:@"running"];
        if(activity.automotive)
            [motion addObject:@"driving"];
        if(activity.stationary)
            [motion addObject:@"stationary"];

        for(int i=0; i<locations.count; i++) {
            CLLocation *loc = locations[i];
            NSDictionary *update = @{
                @"timestamp": [NSNumber numberWithInt:(int)round([loc.timestamp timeIntervalSince1970])],
                @"latitude": [NSNumber numberWithDouble:loc.coordinate.latitude],
                @"longitude": [NSNumber numberWithDouble:loc.coordinate.longitude],
                @"altitude": [NSNumber numberWithInt:(int)round(loc.altitude)],
                @"speed": [NSNumber numberWithInt:(int)round(loc.speed)],
                @"horizontal_accuracy": [NSNumber numberWithInt:(int)round(loc.horizontalAccuracy)],
                @"vertical_accuracy": [NSNumber numberWithInt:(int)round(loc.verticalAccuracy)],
                @"motion": motion
            };
//            NSLog(@"Storing location update %@, for key: %@", update, [update objectForKey:@"timestamp"]);
            [accessor setDictionary:update forKey:[[update objectForKey:@"timestamp"] stringValue]];
        }
        
	}];
    
    [self sendQueueIfNecessary];
}

- (void)numberOfLocationsInQueue:(void(^)(long num))callback {
    [self.db accessCollection:OLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
        [accessor countObjectsUsingBlock:callback];
    }];
}

- (void)sendingStarted {
    self.sendInProgress = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:OLSendingStartedNotification object:self];
}

- (void)sendingFinished {
    self.sendInProgress = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:OLSendingFinishedNotification object:self];
}

- (void)sendQueueIfNecessary {
    if(!self.sendInProgress &&
       [(NSDate *)[self.lastSentDate dateByAddingTimeInterval:[self.sendingInterval doubleValue]] compare:NSDate.date] == NSOrderedAscending) {
        NSLog(@"Sending queue now");
        [self sendQueueNow];
        self.lastSentDate = NSDate.date;
    }
}

- (void)sendQueueNow {
    [self sendingStarted];
    
    NSMutableSet *syncedUpdates = [NSMutableSet set];
    NSMutableArray *locationUpdates = [NSMutableArray array];

    [self.db accessCollection:OLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {

        [accessor enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *object) {
            [syncedUpdates addObject:key];
            [locationUpdates addObject:object];
            return (BOOL)(locationUpdates.count >= PointsPerBatch);
        }];

    }];

    NSDictionary *postData = @{@"locations": locationUpdates};
    
    NSString *endpoint = [[NSUserDefaults standardUserDefaults] stringForKey:OLAPIEndpointDefaultsName];
    NSLog(@"Endpoint: %@", endpoint);
    NSLog(@"Updates in post: %lu", (unsigned long)locationUpdates.count);
    
    [_httpClient POST:endpoint parameters:postData success:^(NSURLSessionDataTask *task, id responseObject) {
        NSLog(@"Response: %@", responseObject);

        if([responseObject objectForKey:@"error"]) {
            [self notify:[responseObject objectForKey:@"error"] withTitle:@"Error"];
            [self sendingFinished];
        } else {
            self.lastSentDate = NSDate.date;
            
            [self.db accessCollection:OLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
                for(NSString *key in syncedUpdates) {
                    [accessor removeDictionaryForKey:key];
                }
            }];

            [self sendingFinished];
        }
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@"Error: %@", error);
        [self notify:error.description withTitle:@"Error"];
        [self sendingFinished];
    }];
    
}

- (NSDate *)lastSentDate {
    return (NSDate *)[[NSUserDefaults standardUserDefaults] objectForKey:OLLastSentDateDefaultsName];
}

- (void)setLastSentDate:(NSDate *)lastSentDate {
    [[NSUserDefaults standardUserDefaults] setObject:lastSentDate forKey:OLLastSentDateDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)notify:(NSString *)message withTitle:(NSString *)title
{
    if([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:@"Close" otherButtonTitles:nil];
        [alert show];
    } else {
        UILocalNotification* localNotification = [[UILocalNotification alloc] init];
        localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:1];
        localNotification.alertBody = [NSString stringWithFormat:@"%@: %@", title, message];
        localNotification.timeZone = [NSTimeZone defaultTimeZone];
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
    }
}

- (void)debugSteps
{
    NSDate *startDate = [NSDate dateWithTimeIntervalSinceNow:-86400];
    
    
}

#pragma mark -

- (void)setSendingInterval:(NSNumber *)newValue {
    [[NSUserDefaults standardUserDefaults] setValue:newValue forKey:OLSendIntervalDefaultsName];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _sendingInterval = newValue;
}

- (NSNumber *)sendingInterval {
    if(_sendingInterval)
        return _sendingInterval;
    
    _sendingInterval = (NSNumber *)[[NSUserDefaults standardUserDefaults] valueForKey:OLSendIntervalDefaultsName];
    return _sendingInterval;
}

@end
