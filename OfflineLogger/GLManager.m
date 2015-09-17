//
//  GLManager.m
//  GPSLogger
//
//  Created by Aaron Parecki on 10/21/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import "GLManager.h"
#import "LOLDatabase.h"
#import "AFHTTPSessionManager.h"

@interface GLManager()

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CMMotionActivityManager *motionActivityManager;

@property BOOL trackingEnabled;
@property BOOL sendInProgress;
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
    SEL requestAlwaysAuthorization = NSSelectorFromString(@"requestWhenInUseAuthorization");
    if([self.locationManager respondsToSelector:requestAlwaysAuthorization]) {
        [self.locationManager performSelector:requestAlwaysAuthorization];
    }
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
        _locationManager.pausesLocationUpdatesAutomatically = NO;
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
    
    // Queue the point in the database
	[self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {

        NSMutableArray *motion = [[NSMutableArray alloc] init];
        CMMotionActivity *activity = [GLManager sharedManager].lastMotion;
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
    if(!self.sendInProgress &&
       [self.sendingInterval integerValue] > -1 &&
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
    
    [_httpClient POST:endpoint parameters:postData success:^(NSURLSessionDataTask *task, id responseObject) {
        NSLog(@"Response: %@", responseObject);

        if([responseObject objectForKey:@"result"] && [[responseObject objectForKey:@"result"] isEqualToString:@"ok"]) {
            self.lastSentDate = NSDate.date;
            
            [self.db accessCollection:GLLocationQueueName withBlock:^(id<LOLDatabaseAccessor> accessor) {
                for(NSString *key in syncedUpdates) {
                    [accessor removeDictionaryForKey:key];
                }
            }];
            
            [self sendingFinished];
        } else {

            if([responseObject objectForKey:@"error"]) {
                [self notify:[responseObject objectForKey:@"error"] withTitle:@"Error"];
                [self sendingFinished];
            } else {
                [self notify:[responseObject description] withTitle:@"Error"];
                [self sendingFinished];
            }
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
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
