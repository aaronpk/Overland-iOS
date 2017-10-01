//
//  FirstViewController.h
//  GPSLogger
//
//  Created by Aaron Parecki on 9/17/15.
//  Copyright © 2015 Esri. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FirstViewController : UIViewController

@property BOOL usesMetricSystem;

@property (strong, nonatomic) IBOutlet UILabel *accountInfo;

@property (strong, nonatomic) IBOutlet UISegmentedControl *trackingEnabledToggle;

@property (strong, nonatomic) IBOutlet UISlider *sendIntervalSlider;
@property (strong, nonatomic) IBOutlet UILabel *sendIntervalLabel;
@property (strong, nonatomic) IBOutlet UIButton *sendNowButton;

@property (strong, nonatomic) IBOutlet UILabel *locationLabel;
@property (strong, nonatomic) IBOutlet UILabel *locationSpeedLabel;
@property (strong, nonatomic) IBOutlet UILabel *locationAltitudeLabel;
@property (strong, nonatomic) IBOutlet UILabel *locationAgeLabel;

@property (strong, nonatomic) IBOutlet UILabel *motionTypeLabel;

@property (strong, nonatomic) IBOutlet UILabel *queueLabel;
@property (strong, nonatomic) IBOutlet UILabel *queueAgeLabel;

- (IBAction)sendIntervalDragged:(UISlider *)sender;
- (IBAction)sendIntervalChanged:(UISlider *)sender;
- (IBAction)toggleLogging:(id)sender;
- (IBAction)sendQueue:(id)sender;
- (IBAction)locationAgeWasTapped:(id)sender;

@property (strong, nonatomic) IBOutlet UIImageView *currentModeImage;
@property (strong, nonatomic) IBOutlet UILabel *currentModeLabel;
- (IBAction)tripModeWasTapped:(id)sender;
@property (strong, nonatomic) IBOutlet UILabel *tripDurationLabel;
@property (strong, nonatomic) IBOutlet UILabel *tripDistanceLabel;
@property (strong, nonatomic) IBOutlet UILabel *tripDistanceUnitLabel;
@property (strong, nonatomic) IBOutlet UIButton *tripStartStopButton;
- (IBAction)tripStartStopWasTapped:(id)sender;

@property (strong, nonatomic) IBOutlet UILabel *tripStats;

@property (strong, nonatomic) IBOutlet UILabel *locationNameLabel;

@end

