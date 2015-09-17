//
//  GLFirstViewController.h
//  GPSLogger
//
//  Created by Aaron Parecki on 10/21/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface GLFirstViewController : UIViewController

@property (strong, nonatomic) IBOutlet UISegmentedControl *trackingEnabledToggle;

@property (strong, nonatomic) IBOutlet UISlider *sendIntervalSlider;
@property (strong, nonatomic) IBOutlet UILabel *sendIntervalLabel;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *sendingIndicator;
@property (strong, nonatomic) IBOutlet UIButton *sendNowButton;

@property (strong, nonatomic) IBOutlet UILabel *locationLabel;
@property (strong, nonatomic) IBOutlet UILabel *locationSpeedLabel;
@property (strong, nonatomic) IBOutlet UILabel *locationAltitudeLabel;
@property (strong, nonatomic) IBOutlet UILabel *locationAgeLabel;

@property (strong, nonatomic) IBOutlet UILabel *motionStepsLabel;
@property (strong, nonatomic) IBOutlet UILabel *motionTypeLabel;

@property (strong, nonatomic) IBOutlet UILabel *queueLabel;
@property (strong, nonatomic) IBOutlet UILabel *queueAgeLabel;

- (IBAction)sendIntervalDragged:(UISlider *)sender;
- (IBAction)sendIntervalChanged:(UISlider *)sender;
- (IBAction)toggleLogging:(id)sender;
- (IBAction)sendQueue:(id)sender;

@end
