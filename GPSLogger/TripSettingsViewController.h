//
//  TripSettingsViewController.h
//  Overland
//
//  Created by Aaron Parecki on 12/5/23.
//  Copyright © 2023 Aaron Parecki. All rights reserved.
//

#ifndef TripSettingsViewController_h
#define TripSettingsViewController_h

#import <UIKit/UIKit.h>

@interface TripSettingsViewController : UIViewController

@property (strong, nonatomic) IBOutlet UISlider *settingsLockSlider;
@property (strong, nonatomic) IBOutlet UISegmentedControl *desiredAccuracy;
@property (strong, nonatomic) IBOutlet UISegmentedControl *activityType;
@property (strong, nonatomic) IBOutlet UISegmentedControl *showBackgroundLocationIndicator;
@property (strong, nonatomic) IBOutlet UISegmentedControl *pausesAutomatically;

@property (strong, nonatomic) IBOutlet UISegmentedControl *loggingMode;
@property (strong, nonatomic) IBOutlet UISegmentedControl *pointsPerBatchControl;
@property (strong, nonatomic) IBOutlet UISlider *autoStopRadius;
@property (strong, nonatomic) IBOutlet UILabel *autoStopRadiusLabel;
@property (strong, nonatomic) IBOutlet UISlider *autoStopTime;
@property (strong, nonatomic) IBOutlet UILabel *autoStopTimeLabel;
@property (strong, nonatomic) IBOutlet UISlider *discardPointsWithinDistance;
@property (strong, nonatomic) IBOutlet UILabel *discardPointsWithinDistanceLabel;
@property (strong, nonatomic) IBOutlet UISlider *discardPointsWithinSeconds;
@property (strong, nonatomic) IBOutlet UILabel *discardPointsWithinSecondsLabel;
@property (strong, nonatomic) IBOutlet UISlider *discardPointsWorseThanAccuracy;
@property (strong, nonatomic) IBOutlet UILabel *discardPointsWorseThanAccuracyLabel;
@property (strong, nonatomic) IBOutlet UISwitch *discardPointsWithoutGPS;
@property (strong, nonatomic) IBOutlet UISwitch *discardPointsWhileStationary;
@property (strong, nonatomic) IBOutlet UISwitch *preventScreenLockDuringTrip;
@property (strong, nonatomic) IBOutlet UISwitch *showLiveActivityDuringTrip;

- (IBAction)settingsLockSliderWasChanged:(UISlider *)sender;

- (IBAction)desiredAccuracyWasChanged:(UISegmentedControl *)sender;
- (IBAction)activityTypeControlWasChanged:(UISegmentedControl *)sender;
- (IBAction)showBackgroundLocationIndicatorWasChanged:(UISegmentedControl *)sender;
- (IBAction)pausesAutomaticallyWasChanged:(UISegmentedControl *)sender;

- (IBAction)loggingModeWasChanged:(UISegmentedControl *)sender;
- (IBAction)pointsPerBatchWasChanged:(UISegmentedControl *)sender;
- (IBAction)autoStopRadiusWasChanged:(UISlider *)sender;
- (IBAction)autoStopTimeWasChanged:(UISlider *)sender;
- (IBAction)discardPointsWithinDistanceWasChanged:(UISlider *)sender;
- (IBAction)discardPointsWithinSecondsWasChanged:(UISlider *)sender;
- (IBAction)discardPointsWorseThanAccuracyWasChanged:(UISlider *)sender;
- (IBAction)toggleDiscardPointsWithoutGPS:(UISwitch *)sender;
- (IBAction)toggleDiscardPointsWhileStationary:(UISwitch *)sender;
- (IBAction)togglePreventScreenLockDuringTripEnabled:(UISwitch *)sender;
- (IBAction)toggleShowLiveActivityDuringTripEnabled:(UISwitch *)sender;

@end

#endif /* TripSettingsViewController_h */
