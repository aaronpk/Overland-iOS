//
//  OLManager.m
//  OfflineLogger
//
//  Created by Aaron Parecki on 10/21/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import "OLManager.h"

@interface OLManager()

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CMMotionActivityManager *motionActivityManager;
@property (strong, nonatomic) CMStepCounter *stepCounter;

@property (strong, nonatomic) CLLocation *lastLocation;
@property (strong, nonatomic) CMMotionActivity *lastMotion;
@property (strong, nonatomic) NSNumber *lastStepCount;

@end

@implementation OLManager

+ (OLManager *)sharedManager {
    static OLManager *_instance = nil;
    
    @synchronized (self) {
        if (_instance == nil) {
            _instance = [[self alloc] init];
        }
    }
    
    return _instance;
}

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

- (void)startAllUpdates {
    [self.locationManager startUpdatingLocation];
    [self.locationManager startUpdatingHeading];
    if(CMMotionActivityManager.isActivityAvailable) {
        [self.motionActivityManager startActivityUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMMotionActivity *activity) {
            [[NSNotificationCenter defaultCenter] postNotificationName:OLNewDataNotification object:self];
            self.lastMotion = activity;
        }];
    }
    if(CMStepCounter.isStepCountingAvailable) {
        // Request step count updates every 5 steps, but don't use the step count reported because then I'd have to keep track of the time I started counting steps. Instead, query the step API for the last hour's worth of steps.
        [self.stepCounter startStepCountingUpdatesToQueue:[NSOperationQueue mainQueue]
                                                 updateOn:5
                                              withHandler:^(NSInteger numberOfSteps, NSDate *timestamp, NSError *error) {
            [self queryStepCount:nil];
        }];
    }
}

- (void)queryStepCount:(void(^)(NSInteger numberOfSteps, NSError *error))callback {
    [self.stepCounter queryStepCountStartingFrom:[OLManager last24Hours]
                                              to:[NSDate date]
                                         toQueue:[NSOperationQueue mainQueue]
                                     withHandler:^(NSInteger numberOfSteps, NSError *error) {
                                         self.lastStepCount = [NSNumber numberWithInteger:numberOfSteps];
                                         if(callback) {
                                             callback(numberOfSteps, error);
                                         }
                                     }];
}

- (void)stopAllUpdates {
    [self.locationManager stopUpdatingHeading];
    [self.locationManager stopUpdatingLocation];
    if(CMMotionActivityManager.isActivityAvailable) {
        [self.motionActivityManager stopActivityUpdates];
        self.lastMotion = nil;
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    [[NSNotificationCenter defaultCenter] postNotificationName:OLNewDataNotification object:self];
    self.lastLocation = (CLLocation *)locations[0];
}

@end
