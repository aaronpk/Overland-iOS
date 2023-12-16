//
//  SecondViewController.h
//  GPSLogger
//
//  Created by Aaron Parecki on 9/17/15.
//  Copyright © 2015 Esri. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SettingsViewController : UIViewController

@property (strong, nonatomic) IBOutlet UISlider *settingsLockSlider;
@property (strong, nonatomic) IBOutlet UILabel *apiEndpointField;
@property (strong, nonatomic) IBOutlet UISegmentedControl *trackingEnabledToggle;
@property (strong, nonatomic) IBOutlet UISegmentedControl *continuousTrackingMode;
@property (strong, nonatomic) IBOutlet UISegmentedControl *visitTrackingControl;
@property (strong, nonatomic) IBOutlet UISegmentedControl *desiredAccuracy;
@property (strong, nonatomic) IBOutlet UISegmentedControl *activityType;
@property (strong, nonatomic) IBOutlet UISegmentedControl *showBackgroundLocationIndicator;
@property (strong, nonatomic) IBOutlet UISegmentedControl *pausesAutomatically;
@property (strong, nonatomic) IBOutlet UISegmentedControl *loggingMode;
@property (strong, nonatomic) IBOutlet UISegmentedControl *pointsPerBatchControl;
@property (strong, nonatomic) IBOutlet UISegmentedControl *resumesWithGeofence;
@property (strong, nonatomic) IBOutlet UISegmentedControl *discardPointsWithinDistance;
@property (strong, nonatomic) IBOutlet UISegmentedControl *discardPointsWithinSeconds;
@property (strong, nonatomic) IBOutlet UISwitch *enableNotifications;
@property (strong, nonatomic) IBOutlet UIStackView *locationAuthorizationStatusSection;
@property (strong, nonatomic) IBOutlet UILabel *locationAuthorizationStatus;
@property (strong, nonatomic) IBOutlet UILabel *locationAuthorizationStatusWarning;
@property (strong, nonatomic) IBOutlet UIButton *requestLocationPermissionsButton;

- (IBAction)settingsLockSliderWasChanged:(UISlider *)sender;
- (IBAction)toggleLogging:(UISegmentedControl *)sender;
- (IBAction)continuousTrackingModeWasChanged:(UISegmentedControl *)sender;
- (IBAction)visitTrackingWasChanged:(UISegmentedControl *)sender;
- (IBAction)desiredAccuracyWasChanged:(UISegmentedControl *)sender;
- (IBAction)activityTypeControlWasChanged:(UISegmentedControl *)sender;
- (IBAction)showBackgroundLocationIndicatorWasChanged:(UISegmentedControl *)sender;
- (IBAction)pausesAutomaticallyWasChanged:(UISegmentedControl *)sender;
- (IBAction)loggingModeWasChanged:(UISegmentedControl *)sender;
- (IBAction)pointsPerBatchWasChanged:(UISegmentedControl *)sender;
- (IBAction)resumeWithGeofenceWasChanged:(UISegmentedControl *)sender;
- (IBAction)discardPointsWithinDistanceWasChanged:(UISegmentedControl *)sender;
- (IBAction)discardPointsWithinSecondsWasChanged:(UISegmentedControl *)sender;
- (IBAction)toggleNotificationsEnabled:(UISwitch *)sender;
- (IBAction)requestLocationPermissionsWasPressed:(UIButton *)sender;

@end

