//
//  TripSettingsViewController.m
//  Overland
//
//  Created by Aaron Parecki on 12/5/23.
//  Copyright © 2023 Aaron Parecki. All rights reserved.
//

#import "TripSettingsViewController.h"
#import "GLManager.h"
#import "Overland-Swift.h"

#import  <Intents/Intents.h>

@interface TripSettingsViewController ()

@property (strong, nonatomic) UISwitch *saveToHealth;
@property (strong, nonatomic) UILabel *saveToHealthInfo;

@end

@implementation TripSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    // The boat activity type is only available in iOS 27
    if (@available(iOS 27.0, *)) {
        [self.activityType insertSegmentWithTitle:@"Boat" atIndex:self.activityType.numberOfSegments animated:NO];
    }

    if(HealthTripRecorder.isAvailable) {
        [self addHealthSetting];
    }
}

// The Apple Health row goes after the Live Activity row, in the storyboard's stack of settings
- (void)addHealthSetting {
    UIView *liveActivityRow = self.showLiveActivityDuringTrip.superview;
    UIStackView *settings = (UIStackView *)liveActivityRow.superview;
    NSUInteger index = [settings.arrangedSubviews indexOfObject:liveActivityRow];
    if(![settings isKindOfClass:[UIStackView class]] || index == NSNotFound) {
        return;
    }

    UILabel *label = [[UILabel alloc] init];
    label.text = @"Save to Apple Health";
    label.font = [UIFont systemFontOfSize:17];
    self.saveToHealth = [[UISwitch alloc] init];
    [self.saveToHealth setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [self.saveToHealth addTarget:self action:@selector(toggleSaveToHealth:) forControlEvents:UIControlEventValueChanged];
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[label, self.saveToHealth]];

    self.saveToHealthInfo = [[UILabel alloc] init];
    self.saveToHealthInfo.numberOfLines = 0;
    self.saveToHealthInfo.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.saveToHealthInfo.textColor = [UIColor secondaryLabelColor];

    [settings insertArrangedSubview:row atIndex:index + 1];
    [settings insertArrangedSubview:self.saveToHealthInfo atIndex:index + 2];
}

- (void)updateHealthSetting {
    if(self.saveToHealth == nil) {
        return;
    }
    self.saveToHealth.on = [HealthTripRecorder shared].isEnabled;
    NSString *info = @"Trips are saved as workouts with their route, for trip modes that have an Apple Health workout type, such as Walk, Run and Bicycle. If you also record workouts on Apple Watch, you may see both.";
    NSString *error = [HealthTripRecorder shared].lastError;
    if(error) {
        info = [NSString stringWithFormat:@"%@\n\n⚠️ %@", info, error];
    }
    self.saveToHealthInfo.text = info;
}

- (void)toggleSaveToHealth:(UISwitch *)sender {
    if(!sender.on) {
        [HealthTripRecorder shared].isEnabled = NO;
        [self updateHealthSetting];
        return;
    }
    [[HealthTripRecorder shared] requestAuthorizationWithCompletion:^(NSString *errorMessage) {
        if(errorMessage) {
            sender.on = NO;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Apple Health" message:errorMessage preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            [HealthTripRecorder shared].isEnabled = YES;
        }
        [self updateHealthSetting];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    
    [self lockAllControls];
    self.settingsLockSlider.value = 0;

    [self updateVisibleSettings];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateVisibleSettings)
                                                 name:GLSettingsChangedNotification
                                               object:nil];

}

- (void)viewDidDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateVisibleSettings {
    self.preventScreenLockDuringTrip.on = [[NSUserDefaults standardUserDefaults] boolForKey:GLScreenLockEnabledDefaultsName];
    self.showLiveActivityDuringTrip.on = [GLManager sharedManager].liveActivityEnabled;
    [self updateHealthSetting];

    self.activityType.selectedSegmentIndex = [GLManager sharedManager].activityTypeDuringTrip - 1;

    GLLoggingMode loggingMode = [GLManager sharedManager].loggingModeDuringTrip;
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
    
    self.showBackgroundLocationIndicator.selectedSegmentIndex = ([GLManager sharedManager].showBackgroundLocationIndicatorDuringTrip ? 1 : 0);
    
    self.pausesAutomatically.selectedSegmentIndex = ([GLManager sharedManager].pausesAutomaticallyDuringTrip ? 1 : 0);
    
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

    self.discardPointsWithoutGPS.on = [GLManager sharedManager].discardPointsWithoutGPSDuringTrip;
    self.discardPointsWhileStationary.on = [GLManager sharedManager].discardPointsWhileStationaryDuringTrip;

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
    self.pausesAutomatically.enabled = NO;
    self.preventScreenLockDuringTrip.enabled = NO;
    self.showLiveActivityDuringTrip.enabled = NO;
    self.loggingMode.enabled = NO;
    self.pointsPerBatchControl.enabled = NO;
    self.discardPointsWithinDistance.enabled = NO;
    self.discardPointsWithinSeconds.enabled = NO;
    self.discardPointsWithoutGPS.enabled = NO;
    self.discardPointsWhileStationary.enabled = NO;
    self.saveToHealth.enabled = NO;
}

- (void)unlockAllControls {
    self.desiredAccuracy.enabled = YES;
    self.activityType.enabled = YES;
    self.showBackgroundLocationIndicator.enabled = YES;
    self.pausesAutomatically.enabled = YES;
    self.preventScreenLockDuringTrip.enabled = YES;
    self.showLiveActivityDuringTrip.enabled = YES;
    self.loggingMode.enabled = YES;
    self.pointsPerBatchControl.enabled = YES;
    self.discardPointsWithinDistance.enabled = YES;
    self.discardPointsWithinSeconds.enabled = YES;
    self.discardPointsWithoutGPS.enabled = YES;
    self.discardPointsWhileStationary.enabled = YES;
    self.saveToHealth.enabled = YES;
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

- (IBAction)pausesAutomaticallyWasChanged:(UISegmentedControl *)sender {
    [GLManager sharedManager].pausesAutomaticallyDuringTrip = sender.selectedSegmentIndex == 1;
    if(sender.selectedSegmentIndex == 0) {
        [GLManager sharedManager].resumesAfterDistance = -1;
    }
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

- (IBAction)toggleDiscardPointsWithoutGPS:(UISwitch *)sender {
    [GLManager sharedManager].discardPointsWithoutGPSDuringTrip = sender.on;
}

- (IBAction)toggleDiscardPointsWhileStationary:(UISwitch *)sender {
    [GLManager sharedManager].discardPointsWhileStationaryDuringTrip = sender.on;
}

- (IBAction)toggleShowLiveActivityDuringTripEnabled:(UISwitch *)sender {
    [GLManager sharedManager].liveActivityEnabled = sender.on;
}

@end
