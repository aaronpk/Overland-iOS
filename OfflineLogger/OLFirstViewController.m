//
//  OLFirstViewController.m
//  OfflineLogger
//
//  Created by Aaron Parecki on 10/21/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import "OLFirstViewController.h"
#import "OLManager.h"

@interface OLFirstViewController ()

@property (strong, nonatomic) NSTimer *viewRefreshTimer;

@end

@implementation OLFirstViewController

NSArray *intervalMap;
NSArray *intervalMapStrings;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    intervalMap = @[@1, @5, @10, @15, @30, @60, @120, @300, @600, @1800, @-1];
    intervalMapStrings = @[@"1s", @"5s", @"10s", @"15s", @"30s", @"1m", @"2m", @"5m", @"10m", @"30m", @"off"];
}

- (void)viewDidAppear:(BOOL)animated {
    [self.sendingIndicator stopAnimating];
    
    if([OLManager sharedManager].trackingEnabled)
        self.trackingEnabledToggle.selectedSegmentIndex = 0;
    else
        self.trackingEnabledToggle.selectedSegmentIndex = 1;
    
    if([OLManager sharedManager].sendingInterval) {
        self.sendIntervalSlider.value = [intervalMap indexOfObject:[OLManager sharedManager].sendingInterval];
        [self updateSendIntervalLabel];
    }

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(newDataReceived)
												 name:OLNewDataNotification
											   object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(sendingStarted)
												 name:OLSendingStartedNotification
											   object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(sendingFinished)
												 name:OLSendingFinishedNotification
											   object:nil];

	self.viewRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                             target:self
                                                           selector:@selector(refreshView)
                                                           userInfo:nil
                                                            repeats:YES];
    [[OLManager sharedManager] queryStepCount:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)newDataReceived {
//    NSLog(@"New data received!");
//    NSLog(@"Location: %@", [OLManager sharedManager].lastLocation);
//    NSLog(@"Activity: %@", [OLManager sharedManager].lastMotion);
    [self refreshView];
}

- (void)sendingStarted {
    [self.sendingIndicator startAnimating];
    self.sendNowButton.enabled = NO;
}

- (void)sendingFinished {
    [self.sendingIndicator stopAnimating];
    self.sendNowButton.enabled = YES;
}

- (void)refreshView {
    CLLocation *location = [OLManager sharedManager].lastLocation;
    self.locationLabel.text = [NSString stringWithFormat:@"%.5f, %.5f +/- %dm", location.coordinate.latitude, location.coordinate.longitude, (int)round(location.horizontalAccuracy)];
    self.locationAltitudeLabel.text = [NSString stringWithFormat:@"Alt: %dm", (int)round(location.altitude)];
    int speed = (int)(round(location.speed*3.6));
    if(speed < 0) speed = 0;
    self.locationSpeedLabel.text = [NSString stringWithFormat:@"Spd: %dkm/h", speed];
    
    int age = -(int)round([OLManager sharedManager].lastLocation.timestamp.timeIntervalSinceNow);
    if(age == 1) age = 0;
    self.locationAgeLabel.text = [NSString stringWithFormat:@"%@", [OLFirstViewController timeFormatted:age]];
    
    NSMutableArray *motionTextParts = [[NSMutableArray alloc] init];
    CMMotionActivity *activity = [OLManager sharedManager].lastMotion;
    if(activity.walking)
        [motionTextParts addObject:@"Walking"];
    if(activity.running)
        [motionTextParts addObject:@"Running"];
    if(activity.automotive)
        [motionTextParts addObject:@"Driving"];
    if(activity.stationary)
        [motionTextParts addObject:@"Stationary"];
    self.motionTypeLabel.text = [motionTextParts componentsJoinedByString:@", "];
    
    self.motionStepsLabel.text = [NSString stringWithFormat:@"%@ steps in the last 24 hours", [OLManager sharedManager].lastStepCount];
    
    if([OLManager sharedManager].lastSentDate) {
        age = -(int)round([OLManager sharedManager].lastSentDate.timeIntervalSinceNow);
        self.queueAgeLabel.text = [NSString stringWithFormat:@"%@ ago", [OLFirstViewController timeFormatted:age]];
    } else {
        self.queueAgeLabel.text = @"not sent yet";
    }
    
    [[OLManager sharedManager] numberOfLocationsInQueue:^(long num) {
        self.queueLabel.text = [NSString stringWithFormat:@"%ld locations", num];
    }];
    
    if([OLManager sharedManager].sendInProgress)
        [self.sendingIndicator startAnimating];
    else
        [self.sendingIndicator stopAnimating];
}

- (IBAction)toggleLogging:(UISegmentedControl *)sender {
    NSLog(@"Logging: %@", [sender titleForSegmentAtIndex:sender.selectedSegmentIndex]);
    if(sender.selectedSegmentIndex == 0) {
        [[OLManager sharedManager] startAllUpdates];
    } else {
        [[OLManager sharedManager] stopAllUpdates];
    }
}

- (IBAction)sendQueue:(id)sender {
    [[OLManager sharedManager] sendQueueNow];
}

- (IBAction)debugSteps:(id)sender {
    [[OLManager sharedManager] gatherSteps:^(NSMutableArray *data) {
        NSLog(@"%@", data);
    }];
}

- (void)updateSendIntervalLabel {
    NSString *val = intervalMapStrings[(int)roundf([self.sendIntervalSlider value])];
    self.sendIntervalLabel.text = val;
}

- (IBAction)sendIntervalDragged:(UISlider *)sender {
    // Snap to whole numbers
    sender.value = roundf([sender value]);
    [self updateSendIntervalLabel];
}

- (IBAction)sendIntervalChanged:(UISlider *)sender {
    sender.value = roundf([sender value]);
    NSNumber *val = intervalMap[(int)roundf([self.sendIntervalSlider value])];
    NSLog(@"Changed - Send Every: %@", val);
    [self updateSendIntervalLabel];
    [OLManager sharedManager].sendingInterval = val;
}

+ (NSString *)timeFormatted:(int)totalSeconds {
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60) % 60;
    int hours = totalSeconds / 3600;
    
    if(hours == 0) {
        return [NSString stringWithFormat:@"%2d:%02d", minutes, seconds];
    } else {
        return [NSString stringWithFormat:@"%02d:%02d:%02d", hours, minutes, seconds];
    }
}

@end
