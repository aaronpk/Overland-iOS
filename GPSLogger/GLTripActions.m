//
//  GLTripActions.m
//  Overland
//

#import "GLTripActions.h"
#import "GLManager.h"
#import "NSArray+map.h"
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

+ (void)updateQuickActions {
    UIApplication *app = UIApplication.sharedApplication;

    if(![GLManager sharedManager].tripInProgress) {
        // Leave out modes that have been deleted
        NSArray *tripModes = [[[GLManager sharedManager] tripModesByFrequency] filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(NSString *mode, NSDictionary *bindings) {
                return [GLTripModeStore containsModeID:mode];
            }]];
        app.shortcutItems = [tripModes mapObjectsUsingBlock:^id(id obj, NSUInteger idx) {
            NSString *symbol = [GLTripModeStore symbolForModeID:obj];
            UIApplicationShortcutIcon *icon = [GLTripModeStore isCustomSymbol:symbol]
                ? [UIApplicationShortcutIcon iconWithTemplateImageName:symbol]
                : [UIApplicationShortcutIcon iconWithSystemImageName:symbol];
            return [[UIApplicationShortcutItem alloc] initWithType:obj
                                                    localizedTitle:[GLTripModeStore nameForModeID:obj]
                                                 localizedSubtitle:nil
                                                              icon:icon
                                                          userInfo:nil];
        }];
    } else {
        UIApplicationShortcutIcon *icon = [UIApplicationShortcutIcon iconWithSystemImageName:@"stop.circle.fill"];
        UIApplicationShortcutItem *item = [[UIApplicationShortcutItem alloc] initWithType:@"stop"
                                                                           localizedTitle:@"Stop Trip"
                                                                        localizedSubtitle:nil
                                                                                     icon:icon
                                                                                 userInfo:nil];
        app.shortcutItems = @[item];
    }
}

@end
