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

@property (strong, nonatomic) IBOutlet UISegmentedControl *loggingMode;
@property (strong, nonatomic) IBOutlet UISegmentedControl *pointsPerBatchControl;
@property (strong, nonatomic) IBOutlet UISegmentedControl *discardPointsWithinDistance;
@property (strong, nonatomic) IBOutlet UISegmentedControl *discardPointsWithinSeconds;
@property (strong, nonatomic) IBOutlet UISwitch *preventScreenLockDuringTrip;

- (IBAction)settingsLockSliderWasChanged:(UISlider *)sender;

- (IBAction)desiredAccuracyWasChanged:(UISegmentedControl *)sender;
- (IBAction)activityTypeControlWasChanged:(UISegmentedControl *)sender;
- (IBAction)showBackgroundLocationIndicatorWasChanged:(UISegmentedControl *)sender;

- (IBAction)loggingModeWasChanged:(UISegmentedControl *)sender;
- (IBAction)pointsPerBatchWasChanged:(UISegmentedControl *)sender;
- (IBAction)discardPointsWithinDistanceWasChanged:(UISegmentedControl *)sender;
- (IBAction)discardPointsWithinSecondsWasChanged:(UISegmentedControl *)sender;
- (IBAction)togglePreventScreenLockDuringTripEnabled:(UISwitch *)sender;

@end

#endif /* TripSettingsViewController_h */
