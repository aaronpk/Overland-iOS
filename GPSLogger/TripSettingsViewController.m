//
//  TripSettingsViewController.m
//  Overland
//
//  Created by Aaron Parecki on 12/5/23.
//  Copyright © 2023 Aaron Parecki. All rights reserved.
//

#import "TripSettingsViewController.h"
#import "GLManager.h"

#import  <Intents/Intents.h>

@interface TripSettingsViewController ()

@end

@implementation TripSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)viewWillAppear:(BOOL)animated {
    
    [self lockAllControls];
    self.settingsLockSlider.value = 0;

    self.preventScreenLockDuringTrip.on = [[NSUserDefaults standardUserDefaults] boolForKey:GLScreenLockEnabledDefaultsName];

    self.activityType.selectedSegmentIndex = [GLManager sharedManager].activityTypeDuringTrip - 1;

    GLLoggingMode loggingMode = [GLManager sharedManager].loggingModeDuringTrip;
    switch(loggingMode) {
        case kGLLoggingModeAllData:
            self.loggingMode.selectedSegmentIndex = 0;
            break;
        case kGLLoggingModeOnlyLatest:
            self.loggingMode.selectedSegmentIndex = 1;
            break;
    }
    
    switch([GLManager sharedManager].showBackgroundLocationIndicatorDuringTrip) {
        case NO:
            self.showBackgroundLocationIndicator.selectedSegmentIndex = 0;
            break;
        case YES:
            self.showBackgroundLocationIndicator.selectedSegmentIndex = 1;
            break;
    }
        
    CLLocationDistance discardDistance = [GLManager sharedManager].discardPointsWithinDistanceDuringTrip;
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
    
    int discardSeconds = [GLManager sharedManager].discardPointsWithinSecondsDuringTrip;
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
    
    CLLocationAccuracy d = [GLManager sharedManager].desiredAccuracyDuringTrip;
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
    
    int pointsPerBatch = [GLManager sharedManager].pointsPerBatchDuringTrip;
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
    self.desiredAccuracy.enabled = NO;
    self.activityType.enabled = NO;
    self.showBackgroundLocationIndicator.enabled = NO;
    self.preventScreenLockDuringTrip.enabled = NO;
    self.loggingMode.enabled = NO;
    self.pointsPerBatchControl.enabled = NO;
    self.discardPointsWithinDistance.enabled = NO;
    self.discardPointsWithinSeconds.enabled = NO;
}

- (void)unlockAllControls {
    self.desiredAccuracy.enabled = YES;
    self.activityType.enabled = YES;
    self.showBackgroundLocationIndicator.enabled = YES;
    self.preventScreenLockDuringTrip.enabled = YES;
    self.loggingMode.enabled = YES;
    self.pointsPerBatchControl.enabled = YES;
    self.discardPointsWithinDistance.enabled = YES;
    self.discardPointsWithinSeconds.enabled = YES;
}

-(IBAction)loggingModeWasChanged:(UISegmentedControl *)sender {
    if(sender.selectedSegmentIndex == 0) {
        [GLManager sharedManager].loggingModeDuringTrip = kGLLoggingModeAllData;
    } else {
        [GLManager sharedManager].loggingModeDuringTrip = kGLLoggingModeOnlyLatest;
    }
}

- (IBAction)showBackgroundLocationIndicatorWasChanged:(UISegmentedControl *)sender {
    BOOL m = NO;
    switch(sender.selectedSegmentIndex) {
        case 0:
            m = NO; break;
        case 1:
            m = YES; break;
    }
    [GLManager sharedManager].showBackgroundLocationIndicatorDuringTrip = m;
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
    [GLManager sharedManager].discardPointsWithinDistanceDuringTrip = distance;
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
    [GLManager sharedManager].discardPointsWithinSecondsDuringTrip = seconds;
}

- (IBAction)activityTypeControlWasChanged:(UISegmentedControl *)sender {
    [GLManager sharedManager].activityTypeDuringTrip = sender.selectedSegmentIndex + 1; // activityType is an enum starting at 1
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
        [GLManager sharedManager].desiredAccuracyDuringTrip = d;
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
    [GLManager sharedManager].pointsPerBatchDuringTrip = pointsPerBatch;
}

- (IBAction)togglePreventScreenLockDuringTripEnabled:(UISwitch *)sender {
    if(sender.on) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:GLScreenLockEnabledDefaultsName];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:GLScreenLockEnabledDefaultsName];
    }
}

@end
