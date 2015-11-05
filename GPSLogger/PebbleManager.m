//
//  PebbleManager.m
//  GPSLogger
//
//  Created by Aaron Parecki on 10/27/15.
//  Copyright © 2015 Aaron Parecki. All rights reserved.
//

#import "PebbleManager.h"
#import "GLManager.h"

@implementation PebbleManager {
    PBWatch *_targetWatch;
    bool sportsEnabled;
    NSDate *lastSent;
}

+ (PebbleManager *)sharedManager {
    static PebbleManager *_instance = nil;
    
    @synchronized (self) {
        if (_instance == nil) {
            _instance = [[self alloc] init];
            
            [[PBPebbleCentral defaultCentral] setDelegate:_instance];
            // Configure our communications channel to target the sports app:
            [[PBPebbleCentral defaultCentral] setAppUUID:PBSportsUUID];
            [[PBPebbleCentral defaultCentral] run];
            NSLog(@"Registered watches: %@", [[PBPebbleCentral defaultCentral] registeredWatches]);
        }
    }
    
    return _instance;
}

- (void)startWatchSession {
    NSLog(@"Pebble: Starting watch session with last connected watch: %@", [[PBPebbleCentral defaultCentral] lastConnectedWatch]);
    
    [self setTargetWatch:[[PBPebbleCentral defaultCentral] lastConnectedWatch]];

//    if(!sportsEnabled) return;
    [self configureWatchSession];
}

- (void)configureWatchSession {
    [_targetWatch sportsAppSetLabel:NO onSent:^(PBWatch *watch, NSError *error) {
        if(error) {
            NSLog(@"Pebble: Failed setting label to 'speed'");
        } else {
            NSLog(@"Pebble: Set label to 'speed'");
        }
    }];
    [_targetWatch sportsAppSetMetric:NO onSent:^(PBWatch *watch, NSError *error) {
        if(error) {
            NSLog(@"Pebble: Failed to set units to imperial");
        } else {
            NSLog(@"Pebble: Set units to imperial");
        }
    }];
    [_targetWatch sportsAppLaunch:^(PBWatch *watch, NSError *error) {
        if(error) {
            NSLog(@"Pebble: Failed sending launch command");
        } else {
            NSLog(@"Pebble: launch command sent");
        }
    }];
}

- (void)stopWatchSession {
    if(!sportsEnabled) return;

    [_targetWatch sportsAppKill:^(PBWatch *watch, NSError *error) {
        if(error) {
            NSLog(@"Pebble: Failed to kill session");
        } else {
            NSLog(@"Pebble: Successfully killed session");
        }
    }];
    [_targetWatch releaseSharedSession];
}

- (void)refreshWatchface {
    // Avoid sending more than one update per second to the watch
    if(lastSent == nil || [lastSent timeIntervalSinceNow] <= 1.0) {
        GLManager *m = [GLManager sharedManager];
        [self updateTripInfoWithTime:m.currentTripDuration distance:m.currentTripDistance*MetersToMiles speed:m.currentTripSpeed];
    }
}

- (void)updateTripInfoWithTime:(NSTimeInterval)time distance:(double)distance speed:(double)speed {
    NSDictionary *pebbleDict = @{
                                 PBSportsTimeKey: [PBSportsUpdate timeStringFromFloat:time],
                                 PBSportsDistanceKey: [NSString stringWithFormat:@"%2.02f", distance],
                                 PBSportsDataKey: [NSString stringWithFormat:@"%2.02f", speed]
                                 };
    [_targetWatch sportsAppUpdate:pebbleDict onSent:^(PBWatch *watch, NSError *error) {
        if(error) {
            NSLog(@"Pebble: Failed to send update");
        } else {
        }
    }];
}


#pragma mark -

- (void)setTargetWatch:(PBWatch*)watch {
    _targetWatch = watch;
    
    // Test if the Pebble's firmware supports AppMessages / Sports:
    [watch appMessagesGetIsSupported:^(PBWatch *watch, BOOL isAppMessagesSupported) {
        if (isAppMessagesSupported) {
            [[PBPebbleCentral defaultCentral] setAppUUID:PBSportsUUID];
            
            NSLog(@"Pebble: %@ supports AppMessages :D", [watch name]);
            sportsEnabled = YES;
            
            [self configureWatchSession];
        } else {
            
            NSLog(@"Pebble: %@ does NOT support AppMessages :'(", [watch name]);
            sportsEnabled = NO;
        }
    }];
}

#pragma mark - Pebble delegate

- (void)pebbleCentral:(PBPebbleCentral*)central watchDidConnect:(PBWatch*)watch isNew:(BOOL)isNew {
    NSLog(@"Pebble: watch %@ connected", watch.name);
    [self setTargetWatch:watch];
}

- (void)pebbleCentral:(PBPebbleCentral*)central watchDidDisconnect:(PBWatch*)watch {
    NSLog(@"Pebble: Watch %@ disconnected", watch.name);
    if (_targetWatch == watch || [watch isEqual:_targetWatch]) {
        [self setTargetWatch:nil];
    }
}

@end
