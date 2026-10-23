//
//  GLTripActions.m
//  Overland
//

#import "GLTripActions.h"
#import "GLManager.h"
#import "Overland-Swift.h"

@implementation GLTripActions

+ (void)startTripWithMode:(NSString *)mode {
    GLManager *manager = [GLManager sharedManager];
    if(manager.tripInProgress) {
        return;
    }
    if(mode != nil && [GLTripModeStore containsModeID:mode]) {
        manager.currentTripMode = mode;
    }

    // Keep track of whether tracking was on or off when this trip started
    [[NSUserDefaults standardUserDefaults] setBool:manager.trackingEnabled forKey:GLTripTrackingEnabledDefaultsName];

    [manager startTrip];
}

+ (void)endTripRestoringTracking {
    GLManager *manager = [GLManager sharedManager];
    if(!manager.tripInProgress) {
        return;
    }
    [manager endTrip];

    // If tracking was off when the trip started, turn it off now
    if([[NSUserDefaults standardUserDefaults] boolForKey:GLTripTrackingEnabledDefaultsName] == NO) {
        [manager stopAllUpdates];
    }
}

@end
