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
    
    if([GLManager sharedManager].trackingEnabled)
        self.trackingEnabledToggle.selectedSegmentIndex = 0;
    else
        self.trackingEnabledToggle.selectedSegmentIndex = 1;
    
    self.pausesAutomatically.on = [GLManager sharedManager].pausesAutomatically;
    self.enableNotifications.on = [GLManager sharedManager].notificationsEnabled;
    
    self.preventScreenLockDuringTrip.on = [[NSUserDefaults standardUserDefaults] boolForKey:GLScreenLockEnabledDefaultsName];

    if([GLManager sharedManager].apiEndpointURL != nil) {
        self.apiEndpointField.text = [GLManager sharedManager].apiEndpointURL;
    } else {
        self.apiEndpointField.text = @"tap to set endpoint";
    }

    [self authorizationStatusChanged];
    
    self.activityType.selectedSegmentIndex = [GLManager sharedManager].activityType - 1;

    GLSignificantLocationMode slMode = [GLManager sharedManager].significantLocationMode;
    switch(slMode) {
        case kGLSignificantLocationDisabled:
            self.significantLocationMode.selectedSegmentIndex = 0;
            break;
        case kGLSignificantLocationEnabled:
            self.significantLocationMode.selectedSegmentIndex = 1;
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
    
    CLLocationDistance dist = [GLManager sharedManager].defersLocationUpdates;
    if(dist == 0) {
        self.defersLocationUpdates.selectedSegmentIndex = 0;
    } else if(dist == 100.0) {
        self.defersLocationUpdates.selectedSegmentIndex = 1;
    } else if(dist == 1000.0) {
        self.defersLocationUpdates.selectedSegmentIndex = 2;
    } else if(dist == 5000.0) {
        self.defersLocationUpdates.selectedSegmentIndex = 3;
    } else {
        self.defersLocationUpdates.selectedSegmentIndex = 4;
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

- (void)authorizationStatusChanged {
    self.locationAuthorizationStatus.text = [GLManager sharedManager].authorizationStatusAsString;
    if (@available(iOS 14.0, *)) {
        if([GLManager sharedManager].locationManager.authorizationStatus != kCLAuthorizationStatusAuthorizedAlways) {
            self.locationAuthorizationStatusWarning.hidden = false;
            self.requestLocationPermissionsButton.hidden = false;
        } else {
            self.locationAuthorizationStatusWarning.hidden = true;
            self.requestLocationPermissionsButton.hidden = true;
        }
    }
}

- (IBAction)toggleLogging:(UISegmentedControl *)sender {
    NSLog(@"Logging: %@", [sender titleForSegmentAtIndex:sender.selectedSegmentIndex]);
    
    if(sender.selectedSegmentIndex == 0) {
        [[GLManager sharedManager] startAllUpdates];
    } else {
        [[GLManager sharedManager] stopAllUpdates];
    }
}

- (IBAction)requestLocationPermissionsWasPressed:(UIButton *)sender {
    [[GLManager sharedManager] requestAuthorizationPermission];
}

- (IBAction)togglePausesAutomatically:(UISwitch *)sender {
    [GLManager sharedManager].pausesAutomatically = sender.on;
    if(sender.on == NO) {
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
        self.pausesAutomatically.on = YES;
        [GLManager sharedManager].pausesAutomatically = YES;
    }
    [GLManager sharedManager].resumesAfterDistance = distance;
}

- (IBAction)significantLocationModeWasChanged:(UISegmentedControl *)sender {
    GLSignificantLocationMode m = kGLSignificantLocationDisabled;
    switch(sender.selectedSegmentIndex) {
        case 0:
            m = kGLSignificantLocationDisabled; break;
        case 1:
            m = kGLSignificantLocationEnabled; break;
    }
    [GLManager sharedManager].significantLocationMode = m;
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
    // Deferred updates only work when desired accuracy is Navigation or Best, so change to "Best" if it's worse
    if(sender.selectedSegmentIndex >= 2) {
        self.defersLocationUpdates.selectedSegmentIndex = 0;
        [GLManager sharedManager].defersLocationUpdates = 0;
    }
    if(d != -999)
        [GLManager sharedManager].desiredAccuracy = d;
}

- (IBAction)defersLocationUpdatesWasChanged:(UISegmentedControl *)sender {
    CLLocationDistance d = CLLocationDistanceMax;
    switch(sender.selectedSegmentIndex) {
        case 0:
            d = 0; break;
        case 1:
            d = 100.0; break;
        case 2:
            d = 1000.0; break;
        case 3:
            d = 5000.0; break;
        case 4:
            d = CLLocationDistanceMax; break;
    }
    if(d > 0) {
        // Deferred updates only work when desired accuracy is Navigation or Best, so change to "Best" if it's worse
        if(self.desiredAccuracy.selectedSegmentIndex >= 2) {
            self.desiredAccuracy.selectedSegmentIndex = 1;
            [GLManager sharedManager].desiredAccuracy = kCLLocationAccuracyBest;
        }
    }
    [GLManager sharedManager].defersLocationUpdates = d;
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

- (IBAction)togglePreventScreenLockDuringTripEnabled:(UISwitch *)sender {
    if(sender.on) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:GLScreenLockEnabledDefaultsName];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:GLScreenLockEnabledDefaultsName];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
