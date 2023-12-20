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

    if([GLManager sharedManager].apiEndpointURL != nil) {
        self.apiEndpointField.text = [GLManager sharedManager].apiEndpointURL;
    } else {
        self.apiEndpointField.text = @"tap to set endpoint";
    }

    self.trackingEnabledToggle.selectedSegmentIndex = ([GLManager sharedManager].trackingEnabled ? 1 : 0);
    self.pausesAutomatically.selectedSegmentIndex = ([GLManager sharedManager].pausesAutomatically ? 1 : 0);
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
    }
    
    switch([GLManager sharedManager].showBackgroundLocationIndicator) {
        case NO:
            self.showBackgroundLocationIndicator.selectedSegmentIndex = 0;
            break;
        case YES:
            self.showBackgroundLocationIndicator.selectedSegmentIndex = 1;
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
    int dIdx = 0;
    switch((int)discardDistance) {
        case -1:
            dIdx = 0; break;
        case 1:
            dIdx = 1; break;
        case 10:
            dIdx = 2; break;
        case 50:
            dIdx = 3; break;
        case 100:
            dIdx = 4; break;
        case 500:
            dIdx = 5; break;
    }
    self.discardPointsWithinDistance.selectedSegmentIndex = dIdx;
    
    int discardSeconds = [GLManager sharedManager].discardPointsWithinSeconds;
    switch(discardSeconds) {
        case 1:
            self.discardPointsWithinSeconds.selectedSegmentIndex = 0; break;
        case 5:
            self.discardPointsWithinSeconds.selectedSegmentIndex = 1; break;
        case 10:
            self.discardPointsWithinSeconds.selectedSegmentIndex = 2; break;
        case 30:
            self.discardPointsWithinSeconds.selectedSegmentIndex = 3; break;
        case 60:
            self.discardPointsWithinSeconds.selectedSegmentIndex = 4; break;
        case 120:
            self.discardPointsWithinSeconds.selectedSegmentIndex = 5; break;
    }
    
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(authorizationStatusChanged)
                                                 name:GLAuthorizationStatusChangedNotification
                                               object:nil];

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
    self.enableNotifications.enabled = YES;
    self.locationAuthorizationStatus.enabled = YES;
    self.locationAuthorizationStatusWarning.enabled = YES;
    self.requestLocationPermissionsButton.enabled = YES;
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
                [GLManager sharedManager].loggingMode = kGLLoggingModeOnlyLatest;
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
                    [GLManager sharedManager].loggingMode = kGLLoggingModeOnlyLatest;
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
    }
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

@end
