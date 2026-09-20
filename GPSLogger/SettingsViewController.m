//
//  SecondViewController.m
//  GPSLogger
//
//  Created by Aaron Parecki on 9/17/15.
//  Copyright © 2015 Esri. All rights reserved.
//  Copyright © 2017 Aaron Parecki. All rights reserved.
//

#import "SettingsViewController.h"
#import "GLManager.h"

#import  <Intents/Intents.h>
#import <SafariServices/SafariServices.h>

@interface SettingsViewController ()

@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)viewWillAppear:(BOOL)animated {
    
    [self lockAllControls];
    self.settingsLockSlider.value = 0;

    [self updateVisibleSettings];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(authorizationStatusChanged)
                                                 name:GLAuthorizationStatusChangedNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateVisibleSettings)
                                                 name:GLSettingsChangedNotification
                                               object:nil];

}

- (void)viewDidDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)settingsLockSliderWasChanged:(UISlider *)sender {
    if(sender.value > 95) {
        [self unlockAllControls];
    } else {
        [self lockAllControls];
    }
}

- (void)lockAllControls {
    self.apiEndpointField.enabled = NO;
    self.trackingEnabledToggle.enabled = NO;
    self.trackingEnabledToggle.enabled = NO;
    self.continuousTrackingMode.enabled = NO;
    self.visitTrackingControl.enabled = NO;
    self.desiredAccuracy.enabled = NO;
    self.activityType.enabled = NO;
    self.showBackgroundLocationIndicator.enabled = NO;
    self.pausesAutomatically.enabled = NO;
    self.loggingMode.enabled = NO;
    self.pointsPerBatchControl.enabled = NO;
    self.resumesWithGeofence.enabled = NO;
    self.discardPointsWithinDistance.enabled = NO;
    self.discardPointsWithinSeconds.enabled = NO;
    self.discardPointsOutsideAccuracy.enabled = NO;
    self.discardDistanceSlider.enabled = NO;
    self.discardSecondsSlider.enabled = NO;
    self.discardAccuracySlider.enabled = NO;
    self.stopsAutomatically.enabled = NO;
    self.stopsAutomaticallyAfter.enabled = NO;
    self.enableNotifications.enabled = NO;
    self.locationAuthorizationStatus.enabled = NO;
    self.locationAuthorizationStatusWarning.enabled = NO;
    self.requestLocationPermissionsButton.enabled = NO;
}

- (void)unlockAllControls {
    self.apiEndpointField.enabled = YES;
    self.trackingEnabledToggle.enabled = YES;
    self.trackingEnabledToggle.enabled = YES;
    self.continuousTrackingMode.enabled = YES;
    self.visitTrackingControl.enabled = YES;
    self.desiredAccuracy.enabled = YES;
    self.activityType.enabled = YES;
    self.showBackgroundLocationIndicator.enabled = YES;
    self.pausesAutomatically.enabled = YES;
    self.loggingMode.enabled = YES;
    self.pointsPerBatchControl.enabled = YES;
    self.resumesWithGeofence.enabled = YES;
    self.discardPointsWithinDistance.enabled = YES;
    self.discardPointsWithinSeconds.enabled = YES;
    self.discardPointsOutsideAccuracy.enabled = YES;
    self.discardDistanceSlider.enabled = YES;
    self.discardSecondsSlider.enabled = YES;
    self.discardAccuracySlider.enabled = YES;
    self.enableNotifications.enabled = YES;
    self.locationAuthorizationStatus.enabled = YES;
    self.locationAuthorizationStatusWarning.enabled = YES;
    self.requestLocationPermissionsButton.enabled = YES;
    
    [self updateAutoPauseExclusivity];
}

- (BOOL)controlsUnlocked {
    return self.settingsLockSlider.value > 95;
}

// "Pause Automatically" and the manual stop radius both shut down continuous updates but
// resume differently, so only one of them may be armed at a time.
- (void)updateAutoPauseExclusivity {
    if(![self controlsUnlocked]) {
        return;
    }

    BOOL modeSupportsStops = self.continuousTrackingMode.selectedSegmentIndex == 3;
    BOOL autoPauseOn = self.pausesAutomatically.selectedSegmentIndex == 1;
    BOOL stopRadiusOn = modeSupportsStops && self.stopsAutomatically.selectedSegmentIndex != 0;

    self.stopsAutomatically.enabled = modeSupportsStops && !autoPauseOn;
    self.stopsAutomaticallyAfter.enabled = self.stopsAutomatically.enabled && stopRadiusOn;

    self.pausesAutomatically.enabled = !stopRadiusOn;
    self.resumesWithGeofence.enabled = !stopRadiusOn;
}

- (void)clearStopsAutomatically {
    self.stopsAutomatically.selectedSegmentIndex = 0;
    [GLManager sharedManager].stopsAutomaticallyRadius = -1;
}

- (void)authorizationStatusChanged {
    self.locationAuthorizationStatus.text = [GLManager sharedManager].authorizationStatusAsString;
    if (@available(iOS 14.0, *)) {
        if([GLManager sharedManager].locationManager.authorizationStatus != kCLAuthorizationStatusAuthorizedAlways) {
            self.locationAuthorizationStatusWarning.hidden = false;
            self.requestLocationPermissionsButton.hidden = false;
            self.locationAuthorizationStatusSection.hidden = false;
        } else {
            self.locationAuthorizationStatusWarning.hidden = true;
            self.requestLocationPermissionsButton.hidden = true;
            self.locationAuthorizationStatusSection.hidden = true;
        }
    }
}

- (BOOL)preciseSettings {
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    return [standardUserDefaults boolForKey:GLPreciseSettingsDefaults];
}

- (void)updateVisibleSettings {
    if([GLManager sharedManager].apiEndpointURL != nil) {
        self.apiEndpointField.text = [GLManager sharedManager].apiEndpointURL;
    } else {
        self.apiEndpointField.text = @"tap to set endpoint";
    }

    self.trackingEnabledToggle.selectedSegmentIndex = ([GLManager sharedManager].trackingEnabled ? 1 : 0);
    self.pausesAutomatically.selectedSegmentIndex = ([GLManager sharedManager].pausesAutomatically ? 1 : 0);
    self.showBackgroundLocationIndicator.selectedSegmentIndex = ([GLManager sharedManager].showBackgroundLocationIndicator ? 1 : 0);
    self.enableNotifications.on = [GLManager sharedManager].notificationsEnabled;
    
    [self authorizationStatusChanged];
    
    self.activityType.selectedSegmentIndex = [GLManager sharedManager].activityType - 1;

    GLTrackingMode trackingMode = [GLManager sharedManager].trackingMode;
    switch(trackingMode) {
        case kGLTrackingModeOff:
            self.continuousTrackingMode.selectedSegmentIndex = 0;
            break;
        case kGLTrackingModeStandard:
            self.continuousTrackingMode.selectedSegmentIndex = 1;
            break;
        case kGLTrackingModeSignificant:
            self.continuousTrackingMode.selectedSegmentIndex = 2;
            break;
        case kGLTrackingModeStandardAndSignificant:
            self.continuousTrackingMode.selectedSegmentIndex = 3;
            break;
    }
    
    self.visitTrackingControl.selectedSegmentIndex = ([GLManager sharedManager].visitTrackingEnabled ? 1 : 0);
    
    GLLoggingMode loggingMode = [GLManager sharedManager].loggingMode;
    switch(loggingMode) {
        case kGLLoggingModeAllData:
            self.loggingMode.selectedSegmentIndex = 0;
            break;
        case kGLLoggingModeOnlyLatest:
            self.loggingMode.selectedSegmentIndex = 1;
            break;
        case kGLLoggingModeOwntracks:
            self.loggingMode.selectedSegmentIndex = 2;
            break;
    }
    
    CLLocationDistance gDist = [GLManager sharedManager].resumesAfterDistance;
    int gIdx = 0;
    switch((int)gDist) {
        case -1:
            gIdx = 0; break;
        case 100:
            gIdx = 1; break;
        case 200:
            gIdx = 2; break;
        case 500:
            gIdx = 3; break;
        case 1000:
            gIdx = 4; break;
        case 2000:
            gIdx = 5; break;
    }
    self.resumesWithGeofence.selectedSegmentIndex = gIdx;
    
    CLLocationDistance discardDistance = [GLManager sharedManager].discardPointsWithinDistance;
    NSInteger distanceIndex = 0;
    if (discardDistance == -1) {
        distanceIndex = 0;
    } else if (discardDistance < 10) {  // Any value from 1 up to (but not including) 10
        distanceIndex = 1;
    } else if (discardDistance < 50) {  // Values 10 up to 49 will yield index 2
        distanceIndex = 2;
    } else if (discardDistance < 100) { // 50 to 99 → index 3
        distanceIndex = 3;
    } else if (discardDistance < 500) { // 100 to 499 → index 4
        distanceIndex = 4;
    } else {                          // 500 or above → index 5
        distanceIndex = 5;
    }
    self.discardPointsWithinDistance.selectedSegmentIndex = distanceIndex;
    
    int discardSeconds = [GLManager sharedManager].discardPointsWithinSeconds;
    NSInteger secondsIndex = 0;
    if (discardSeconds < 5) {         // 1 to 4 seconds rounds to index 0
        secondsIndex = 0;
    } else if (discardSeconds < 10) { // 5 to 9 seconds → index 1
        secondsIndex = 1;
    } else if (discardSeconds < 30) { // 10 to 29 seconds → index 2
        secondsIndex = 2;
    } else if (discardSeconds < 60) { // 30 to 59 seconds → index 3
        secondsIndex = 3;
    } else if (discardSeconds < 120) { // 60 to 119 seconds → index 4
        secondsIndex = 4;
    } else {                         // 120 seconds or more → index 5
        secondsIndex = 5;
    }
    self.discardPointsWithinSeconds.selectedSegmentIndex = secondsIndex;
    
    CLLocationAccuracy discardAccuracy = [GLManager sharedManager].discardPointsOutsideAccuracy;
    NSInteger accuracyIndex = 0;
    if (discardAccuracy == -1) {
        accuracyIndex = 0;
    } else if (discardAccuracy < 50) {  // Any value from 1 up to (but not including) 50
        accuracyIndex = 1;
    } else if (discardAccuracy < 100) {  // Values 50 up to 99 will yield index 2
        accuracyIndex = 2;
    } else if (discardAccuracy < 500) { // 100 to 499 → index 3
        accuracyIndex = 3;
    } else if (discardAccuracy < 1000) { // 499 to 1000 → index 4
        accuracyIndex = 4;
    } else {                          // 1000 or above → index 5
        accuracyIndex = 5;
    }
    self.discardPointsOutsideAccuracy.selectedSegmentIndex = accuracyIndex;
    
    self.discardDistanceSlider.value = [GLManager sharedManager].discardPointsWithinDistance;
    self.discardSecondsSlider.value = [GLManager sharedManager].discardPointsWithinSeconds;
    self.discardAccuracySlider.value = [GLManager sharedManager].discardPointsOutsideAccuracy;
    
    
    CLLocationDistance stopRadius = [GLManager sharedManager].stopsAutomaticallyRadius;
    NSInteger stopRadiusIndex = 0;
    if (stopRadius == -1) {
        stopRadiusIndex = 0;
    } else if (stopRadius < 20) {  // Any value from 1 up to (but not including) 20
        stopRadiusIndex = 1;
    } else if (stopRadius < 50) {  // Values 20 up to 49 will yield index 2
        stopRadiusIndex = 2;
    } else if (stopRadius < 100) { // 50 to 99 → index 3
        stopRadiusIndex = 3;
    } else if (stopRadius < 200) { // 100 to 199 → index 4
        stopRadiusIndex = 4;
    } else {                          // 200 or above → index 5
        stopRadiusIndex = 5;
    }
    self.stopsAutomatically.selectedSegmentIndex = stopRadiusIndex;
    
    
    CLLocationDistance stopAfter = [GLManager sharedManager].stopsAutomaticallyAfterSeconds;
    NSInteger stopAfterIndex = 0;
    if (stopAfter < 60*2) {  // Any value from 1 up to (but not including) 2 minutes
        stopAfterIndex = 0;
    } else if (stopAfter < 60*5) {  // Values 2min up to 5min will yield index 2
        stopAfterIndex = 1;
    } else if (stopAfter < 60*10) { // 5min to 10min → index 3
        stopAfterIndex = 2;
    } else if (stopAfter < 60*20) { // 10min to 20min → index 4
        stopAfterIndex = 3;
    } else {                          // 20min or above → index 5
        stopAfterIndex = 4;
    }
    self.stopsAutomaticallyAfter.selectedSegmentIndex = stopAfterIndex;
    
    CLLocationAccuracy d = [GLManager sharedManager].desiredAccuracy;
    if(d == kCLLocationAccuracyBestForNavigation) {
        self.desiredAccuracy.selectedSegmentIndex = 0;
    } else if(d == kCLLocationAccuracyBest) {
        self.desiredAccuracy.selectedSegmentIndex = 1;
    } else if(d == kCLLocationAccuracyNearestTenMeters) {
        self.desiredAccuracy.selectedSegmentIndex = 2;
    } else if(d == kCLLocationAccuracyHundredMeters) {
        self.desiredAccuracy.selectedSegmentIndex = 3;
    } else if(d == kCLLocationAccuracyKilometer) {
        self.desiredAccuracy.selectedSegmentIndex = 4;
    } else if(d == kCLLocationAccuracyThreeKilometers) {
        self.desiredAccuracy.selectedSegmentIndex = 5;
    }
    
    int pointsPerBatch = [GLManager sharedManager].pointsPerBatch;
    if(pointsPerBatch == 50) {
        self.pointsPerBatchControl.selectedSegmentIndex = 0;
    } else if(pointsPerBatch == 100) {
        self.pointsPerBatchControl.selectedSegmentIndex = 1;
    } else if(pointsPerBatch == 200) {
        self.pointsPerBatchControl.selectedSegmentIndex = 2;
    } else if(pointsPerBatch == 500) {
        self.pointsPerBatchControl.selectedSegmentIndex = 3;
    } else if(pointsPerBatch == 1000) {
        self.pointsPerBatchControl.selectedSegmentIndex = 4;
    }
    
    BOOL usePrecise = [self preciseSettings];
        
    // Toggle discardPointsWithinDistance UI: show slider if precise, segmented control otherwise.
    self.discardPointsWithinDistance.hidden = usePrecise;
    self.discardDistanceSlider.hidden = !usePrecise;
    
    // Similarly, do the same for discardPointsWithinSeconds.
    self.discardPointsWithinSeconds.hidden = usePrecise;
    self.discardSecondsSlider.hidden = !usePrecise;
    
    // Analog for accuracy
    self.discardPointsOutsideAccuracy.hidden = usePrecise;
    self.discardAccuracySlider.hidden = !usePrecise;
    
    
    if (usePrecise) {
        self.discardDistanceSlider.value = [GLManager sharedManager].discardPointsWithinDistance;
        self.discardSecondsSlider.value = [GLManager sharedManager].discardPointsWithinSeconds;
        self.discardAccuracySlider.value = [GLManager sharedManager].discardPointsOutsideAccuracy;
        if (self.discardDistanceSlider.value <= 0) {
            self.discardDistanceValueLabel.text = @"Min Distance Between Points: Off";
        } else {
            self.discardDistanceValueLabel.text = [NSString stringWithFormat:@"Min Distance Between Points: %.0f m", self.discardDistanceSlider.value];
        }
        self.discardSecondsValueLabel.text = [NSString stringWithFormat:@"Min Time Between Points: %.0f s", self.discardSecondsSlider.value];
        if (self.discardAccuracySlider.value <= 0) {
            self.discardAccuracyValueLabel.text = @"Max Accuracy of Points: Off";
        } else {
            self.discardAccuracyValueLabel.text = [NSString stringWithFormat:@"Max Accuracy of Points: %.0f m", self.discardAccuracySlider.value];
        }
    } else {
        self.discardDistanceValueLabel.text = @"Min Distance Between Points";
        self.discardSecondsValueLabel.text = @"Min Time Between Points";
        self.discardAccuracyValueLabel.text = @"Max Accuracy of Points";
    }
    
    [self updateAutoPauseExclusivity];
}

- (IBAction)toggleLogging:(UISegmentedControl *)sender {
    NSLog(@"Logging: %@", [sender titleForSegmentAtIndex:sender.selectedSegmentIndex]);
    
    if(sender.selectedSegmentIndex == 1) {
        [[GLManager sharedManager] startAllUpdates];
    } else {
        [[GLManager sharedManager] stopAllUpdates];
    }
}

-(IBAction)loggingModeWasChanged:(UISegmentedControl *)sender {
    if(sender.selectedSegmentIndex == 0) {
        [GLManager sharedManager].loggingMode = kGLLoggingModeAllData;
    } else {
        
        [[GLManager sharedManager] numberOfLocationsInQueue:^(long num) {
            if(num == 0) {
                if(sender.selectedSegmentIndex == 1) {
                    [GLManager sharedManager].loggingMode = kGLLoggingModeOnlyLatest;
                } else {
                    [GLManager sharedManager].loggingMode = kGLLoggingModeOwntracks;
                }
            } else {
                
                NSString *string = [NSString stringWithFormat:@"This will delete the %d locations in the queue that are not yet sent", (int)num];
                UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Are you sure?"
                                                                               message:string
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault
                                                                     handler:^(UIAlertAction * action) {
                    sender.selectedSegmentIndex = 0;
                                                                     }];
                UIAlertAction* confirmAction = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault
                                                                     handler:^(UIAlertAction * action) {
                    if(sender.selectedSegmentIndex == 1) {
                        [GLManager sharedManager].loggingMode = kGLLoggingModeOnlyLatest;
                    } else {
                        [GLManager sharedManager].loggingMode = kGLLoggingModeOwntracks;
                    }

                }];
                [alert addAction:confirmAction];
                [alert addAction:cancelAction];
                [self presentViewController:alert animated:YES completion:nil];

            }
        }];
        
    }
}

- (IBAction)requestLocationPermissionsWasPressed:(UIButton *)sender {
    [[GLManager sharedManager] requestAuthorizationPermission];
}

- (IBAction)pausesAutomaticallyWasChanged:(UISegmentedControl *)sender {
    [GLManager sharedManager].pausesAutomatically = sender.selectedSegmentIndex == 1;
    if(sender.selectedSegmentIndex == 0) {
        self.resumesWithGeofence.selectedSegmentIndex = 0;
        [GLManager sharedManager].resumesAfterDistance = -1;
    } else {
        [self clearStopsAutomatically];
    }
    [self updateAutoPauseExclusivity];
}

- (IBAction)resumeWithGeofenceWasChanged:(UISegmentedControl *)sender {
    CLLocationDistance distance = -1;
    switch(sender.selectedSegmentIndex) {
        case 0:
            distance = -1; break;
        case 1:
            distance = 100; break;
        case 2:
            distance = 200; break;
        case 3:
            distance = 500; break;
        case 4:
            distance = 1000; break;
        case 5:
            distance = 2000; break;
    }
    if(distance > 0) {
        self.pausesAutomatically.selectedSegmentIndex = 1;
        [GLManager sharedManager].pausesAutomatically = YES;
    }
    [GLManager sharedManager].resumesAfterDistance = distance;
}

- (IBAction)continuousTrackingModeWasChanged:(UISegmentedControl *)sender {
    GLTrackingMode m = kGLTrackingModeStandard;
    switch(sender.selectedSegmentIndex) {
        case 0:
            m = kGLTrackingModeOff; break;
        case 1:
            m = kGLTrackingModeStandard; break;
        case 2:
            m = kGLTrackingModeSignificant; break;
        case 3:
            m = kGLTrackingModeStandardAndSignificant; break;
    }
    [GLManager sharedManager].trackingMode = m;
    
    if(m != kGLTrackingModeStandardAndSignificant) {
        [self clearStopsAutomatically];
    }
    
    [self updateAutoPauseExclusivity];
}

- (IBAction)visitTrackingWasChanged:(UISegmentedControl *)sender {
    BOOL enabled = NO;
    switch(sender.selectedSegmentIndex) {
        case 0:
            enabled = NO; break;
        case 1:
            enabled = YES; break;
    }
    [GLManager sharedManager].visitTrackingEnabled = enabled;
}

- (IBAction)showBackgroundLocationIndicatorWasChanged:(UISegmentedControl *)sender {
    BOOL m = NO;
    switch(sender.selectedSegmentIndex) {
        case 0:
            m = NO; break;
        case 1:
            m = YES; break;
    }
    [GLManager sharedManager].showBackgroundLocationIndicator = m;
}

- (IBAction)discardPointsWithinDistanceWasChanged:(UISegmentedControl *)sender {
    CLLocationDistance distance = -1;
    switch(sender.selectedSegmentIndex) {
        case 0:
            distance = -1; break;
        case 1:
            distance = 1; break;
        case 2:
            distance = 10; break;
        case 3:
            distance = 50; break;
        case 4:
            distance = 100; break;
        case 5:
            distance = 500; break;
    }
    [GLManager sharedManager].discardPointsWithinDistance = distance;
}

- (IBAction)discardPointsWithinDistancePreciseWasChanged:(UISlider *)sender {
    int roundedValue = (int)roundf(sender.value);
    [GLManager sharedManager].discardPointsWithinDistance = roundedValue;
    if (roundedValue <= 0) {
        self.discardDistanceValueLabel.text = @"Min Distance Between Points: Off";
        return;
    }
    self.discardDistanceValueLabel.text = [NSString stringWithFormat:@"Min Distance Between Points: %d m", roundedValue];
}

- (IBAction)discardPointsOutsideAccuracyWasChanged:(UISegmentedControl *)sender {
    CLLocationAccuracy accuracy = -1;
    switch(sender.selectedSegmentIndex) {
        case 0:
            accuracy = -1; break;
        case 1:
            accuracy = 10; break;
        case 2:
            accuracy = 50; break;
        case 3:
            accuracy = 100; break;
        case 4:
            accuracy = 500; break;
        case 5:
            accuracy = 1000; break;
    }
    [GLManager sharedManager].discardPointsOutsideAccuracy = accuracy;
}

- (IBAction)discardPointsOutsideAccuracyPreciseWasChanged:(UISlider *)sender {
    int roundedValue = (int)roundf(sender.value);
    [GLManager sharedManager].discardPointsOutsideAccuracy = roundedValue;
    if (roundedValue <= 0) {
        self.discardAccuracyValueLabel.text = @"Max Accuracy of Points: Off";
        return;
    }
    self.discardAccuracyValueLabel.text = [NSString stringWithFormat:@"Max Accuracy of Points: %d m", roundedValue];
}

- (IBAction)stopsAutomaticallyWasChanged:(UISegmentedControl *)sender {
    CLLocationDistance distance = -1;
    switch(sender.selectedSegmentIndex) {
        case 0:
            distance = -1; break;
        case 1:
            distance = 10; break;
        case 2:
            distance = 20; break;
        case 3:
            distance = 50; break;
        case 4:
            distance = 100; break;
        case 5:
            distance = 200; break;
    }
    [GLManager sharedManager].stopsAutomaticallyRadius = distance;
    
    if(distance > 0) {
        self.pausesAutomatically.selectedSegmentIndex = 0;
        [GLManager sharedManager].pausesAutomatically = NO;
        self.resumesWithGeofence.selectedSegmentIndex = 0;
        [GLManager sharedManager].resumesAfterDistance = -1;
    }
    
    [self updateAutoPauseExclusivity];
}

- (IBAction)stopsAutomaticallyAfterWasChanged:(UISegmentedControl *)sender {
    int seconds = -1;
    switch(sender.selectedSegmentIndex) {
        case 0:
            seconds = 60; break;
        case 1:
            seconds = 60*2; break;
        case 2:
            seconds = 60*5; break;
        case 3:
            seconds = 60*10; break;
        case 4:
            seconds = 60*20; break;
    }
    [GLManager sharedManager].stopsAutomaticallyAfterSeconds = seconds;
}

- (IBAction)discardPointsWithinSecondsPreciseWasChanged:(UISlider *)sender {
    int roundedValue = (int)roundf(sender.value);
    [GLManager sharedManager].discardPointsWithinSeconds = roundedValue;
    self.discardSecondsValueLabel.text = [NSString stringWithFormat:@"Min Time Between Points: %d s", roundedValue];
}

- (IBAction)discardPointsWithinSecondsWasChanged:(UISegmentedControl *)sender {
    int seconds = 1;
    switch(sender.selectedSegmentIndex) {
        case 0:
            seconds = 1; break;
        case 1:
            seconds = 5; break;
        case 2:
            seconds = 10; break;
        case 3:
            seconds = 30; break;
        case 4:
            seconds = 60; break;
        case 5:
            seconds = 120; break;
    }
    [GLManager sharedManager].discardPointsWithinSeconds = seconds;
}

- (IBAction)activityTypeControlWasChanged:(UISegmentedControl *)sender {
    [GLManager sharedManager].activityType = sender.selectedSegmentIndex + 1; // activityType is an enum starting at 1
}

- (IBAction)desiredAccuracyWasChanged:(UISegmentedControl *)sender {
    CLLocationAccuracy d = -999;
    switch(sender.selectedSegmentIndex) {
        case 0:
            d = kCLLocationAccuracyBestForNavigation; break;
        case 1:
            d = kCLLocationAccuracyBest; break;
        case 2:
            d = kCLLocationAccuracyNearestTenMeters; break;
        case 3:
            d = kCLLocationAccuracyHundredMeters; break;
        case 4:
            d = kCLLocationAccuracyKilometer; break;
        case 5:
            d = kCLLocationAccuracyThreeKilometers; break;
    }
    if(d != -999)
        [GLManager sharedManager].desiredAccuracy = d;
}

- (IBAction)pointsPerBatchWasChanged:(UISegmentedControl *)sender {
    int pointsPerBatch = 50;
    switch(sender.selectedSegmentIndex) {
        case 0:
            pointsPerBatch = 50; break;
        case 1:
            pointsPerBatch = 100; break;
        case 2:
            pointsPerBatch = 200; break;
        case 3:
            pointsPerBatch = 500; break;
        case 4:
            pointsPerBatch = 1000; break;        
    }
    [GLManager sharedManager].pointsPerBatch = pointsPerBatch;
}

- (IBAction)toggleNotificationsEnabled:(UISwitch *)sender {
    if(sender.on) {
        [[GLManager sharedManager] requestNotificationPermission];
    } else {
        [GLManager sharedManager].notificationsEnabled = NO;
    }
}

- (IBAction)privacyPolicyWasPressed:(UIButton *)sender {
    NSURL *url = [NSURL URLWithString:@"https://overland.p3k.app/privacy"];
    SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:url];
    // safariViewController.delegate = self;
    [self presentViewController:safariViewController animated:YES completion:nil];
}

@end
