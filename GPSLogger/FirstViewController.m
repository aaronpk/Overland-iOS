//
//  FirstViewController.m
//  GPSLogger
//
//  Created by Aaron Parecki on 9/17/15.
//  Copyright © 2015 Esri. All rights reserved.
//

#import "FirstViewController.h"
#import "GLManager.h"

static NSString *const GLTripTrackingEnabledDefaultsName = @"GLTripTrackingEnabledDefaults";

@interface FirstViewController ()

@property (strong, nonatomic) NSTimer *viewRefreshTimer;

@end

@implementation FirstViewController

NSArray *intervalMap;
NSArray *intervalMapStrings;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    intervalMap = @[@1, @5, @10, @15, @30, @60, @120, @300, @600, @1800, @-1];
    intervalMapStrings = @[@"1s", @"5s", @"10s", @"15s", @"30s", @"1m", @"2m", @"5m", @"10m", @"30m", @"off"];
    
    [[GLManager sharedManager] accountInfo:^(NSString *name) {
        self.accountInfo.text = name;
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)viewWillAppear:(BOOL)animated {
    [self sendingFinished];
    
    if([GLManager sharedManager].trackingEnabled)
        self.trackingEnabledToggle.selectedSegmentIndex = 0;
    else
        self.trackingEnabledToggle.selectedSegmentIndex = 1;
    
    if([GLManager sharedManager].sendingInterval) {
        self.sendIntervalSlider.value = [intervalMap indexOfObject:[GLManager sharedManager].sendingInterval];
        [self updateSendIntervalLabel];
    }
    
    [self updateTripState];
    self.currentModeImage.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@.png", [GLManager sharedManager].currentTripMode]];
    self.currentModeLabel.text = [GLManager sharedManager].currentTripMode;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(newDataReceived)
                                                 name:GLNewDataNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sendingStarted)
                                                 name:GLSendingStartedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sendingFinished)
                                                 name:GLSendingFinishedNotification
                                               object:nil];

    self.viewRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                             target:self
                                                           selector:@selector(refreshView)
                                                           userInfo:nil
                                                            repeats:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [self.viewRefreshTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillUnload {
    [self.viewRefreshTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc {
    NSLog(@"view is deallocd");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Tracking Interface

- (void)newDataReceived {
    //    NSLog(@"New data received!");
    //    NSLog(@"Location: %@", [GLManager sharedManager].lastLocation);
    //    NSLog(@"Activity: %@", [GLManager sharedManager].lastMotion);
    self.locationAgeLabel.textColor = [UIColor blackColor];
    [self refreshView];
}

- (void)sendingStarted {
    self.sendNowButton.titleLabel.text = @"Sending...";
    self.sendNowButton.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:150.0/255.0 blue:107.0/255.0 alpha:1.0];
    self.sendNowButton.enabled = NO;
}

- (void)sendingFinished {
    self.sendNowButton.titleLabel.text = @"Send Now";
    self.sendNowButton.backgroundColor = [UIColor colorWithRed:106.0/255.0 green:212.0/255.0 blue:150.0/255.0 alpha:1.0];
    self.sendNowButton.enabled = YES;
}

- (void)refreshView {
    self.trackingEnabledToggle.selectedSegmentIndex = ([GLManager sharedManager].trackingEnabled ? 0 : 1);
    
    CLLocation *location = [GLManager sharedManager].lastLocation;
    self.locationLabel.text = [NSString stringWithFormat:@"%.5f\n%.5f", location.coordinate.latitude, location.coordinate.longitude];
    self.locationAltitudeLabel.text = [NSString stringWithFormat:@"+/-%dm %dm", (int)round(location.horizontalAccuracy), (int)round(location.altitude)];
    int speed = (int)(round(location.speed*2.23694));
    if(speed < 0) speed = 0;
    self.locationSpeedLabel.text = [NSString stringWithFormat:@"%d", speed];
    
    int age = -(int)round([GLManager sharedManager].lastLocation.timestamp.timeIntervalSinceNow);
    if(age == 1) age = 0;
    self.locationAgeLabel.text = [FirstViewController timeFormatted:age];
    
    CMMotionActivity *activity = [GLManager sharedManager].lastMotion;
    if(activity.walking)
        self.motionTypeLabel.text = @"walking";
    else if(activity.running)
        self.motionTypeLabel.text = @"running";
    else if(activity.cycling)
        self.motionTypeLabel.text = @"cycling";
    else if(activity.automotive)
        self.motionTypeLabel.text = @"driving";
    else if(activity.stationary)
        self.motionTypeLabel.text = @"stationary";
    else
        self.motionTypeLabel.text = @" ";
    
    if([GLManager sharedManager].lastSentDate) {
        age = -(int)round([GLManager sharedManager].lastSentDate.timeIntervalSinceNow);
        self.queueAgeLabel.text = [NSString stringWithFormat:@"%@", [FirstViewController timeFormatted:age]];
    } else {
        self.queueAgeLabel.text = @"n/a";
    }
    
    [[GLManager sharedManager] numberOfLocationsInQueue:^(long num) {
        self.queueLabel.text = [NSString stringWithFormat:@"%ld", num];
    }];

    [self updateTripState];

    if(![GLManager sharedManager].sendInProgress)
//        [self sendingStarted];
//    else
        [self sendingFinished];
    
    /*
    NSSet *regions = [GLManager sharedManager].monitoredRegions;
    self.monitoredRegionsLabel.text = @"";
    for(CLCircularRegion *region in regions) {
        self.monitoredRegionsLabel.text = [NSString stringWithFormat:@"%.6f,%.6f:%.0f\n%@", region.center.latitude, region.center.longitude, region.radius, self.monitoredRegionsLabel.text];
    }
    */
}

- (IBAction)toggleLogging:(UISegmentedControl *)sender {
    NSLog(@"Logging: %@", [sender titleForSegmentAtIndex:sender.selectedSegmentIndex]);
    if(sender.selectedSegmentIndex == 0) {
        [[GLManager sharedManager] startAllUpdates];
    } else {
        [[GLManager sharedManager] stopAllUpdates];
    }
}

- (IBAction)sendQueue:(id)sender {
    [[GLManager sharedManager] sendQueueNow];
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
    if([GLManager sharedManager].sendingInterval != val) {
        [self updateSendIntervalLabel];
        [GLManager sharedManager].sendingInterval = val;
    }
}

- (IBAction)locationAgeWasTapped:(id)sender {
    self.locationAgeLabel.textColor = [UIColor colorWithRed:(180.f/255.f) green:0 blue:0 alpha:1];
    [[GLManager sharedManager] refreshLocation];
}

#pragma mark - Trip Interface

- (void)updateTripState {
    if([GLManager sharedManager].tripInProgress) {
        [self.tripStartStopButton setTitle:@"Stop" forState:UIControlStateNormal];
        self.tripStartStopButton.backgroundColor = [UIColor colorWithRed:252.f/255.f green:109.f/255.f blue:111.f/255.f alpha:1];
        self.tripDurationLabel.text = [FirstViewController timeFormatted:[GLManager sharedManager].currentTripDuration];
        self.tripDistanceLabel.text = [NSString stringWithFormat:@"%0.2f", [GLManager sharedManager].currentTripDistance];
    } else {
        [self.tripStartStopButton setTitle:@"Start" forState:UIControlStateNormal];
        self.tripStartStopButton.backgroundColor = [UIColor colorWithRed:106.f/255.f green:212.f/255.f blue:150.f/255.f alpha:1];
        self.tripDistanceLabel.text = @" ";
        self.tripDurationLabel.text = @" ";
    }
}

- (IBAction)tripModeWasTapped:(UILongPressGestureRecognizer *)sender {
    if(sender.state == UIGestureRecognizerStateBegan) {
        [self performSegueWithIdentifier:@"tripMode" sender:self];
    }
}

- (IBAction)tripStartStopWasTapped:(id)sender {
    if([GLManager sharedManager].tripInProgress) {
        [[GLManager sharedManager] endTrip];
        
        // If tracking was off when the trip started, turn it off now
        if([[NSUserDefaults standardUserDefaults] boolForKey:GLTripTrackingEnabledDefaultsName] == NO) {
            [[GLManager sharedManager] stopAllUpdates];
        }
    } else {
        // Keep track of whether tracking was on or off when this trip started
        [[NSUserDefaults standardUserDefaults] setBool:[GLManager sharedManager].trackingEnabled forKey:GLTripTrackingEnabledDefaultsName];

        [[GLManager sharedManager] startAllUpdates];
        [[GLManager sharedManager] startTrip];
    }
    [self updateTripState];
}

#pragma mark -

+ (NSString *)timeFormatted:(int)totalSeconds {
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60) % 60;
    int hours = totalSeconds / 3600;
    
    if(hours == 0) {
        return [NSString stringWithFormat:@"%2d:%02d", minutes, seconds];
    } else {
        return [NSString stringWithFormat:@"%2d:%02d", hours, minutes];
    }
}

@end
