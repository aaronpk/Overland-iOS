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
    intervalMap = @[@1, @5, @10, @15, @30, @60, @120, @300, @600, @1800, @10000];
    intervalMapStrings = @[@"1s", @"5s", @"10s", @"15s", @"30s", @"1m", @"2m", @"5m", @"10m", @"30m", @"off"];
}

- (void)viewDidAppear:(BOOL)animated {
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(refreshView)
												 name:OLDataViewNeedsUpdateNotification
											   object:nil];

	self.viewRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                             target:self
                                                           selector:@selector(refreshView)
                                                           userInfo:nil
                                                            repeats:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)refreshView {
    NSLog(@"Refreshing View");
    CLLocation *location = [OLManager sharedManager].lastLocation;
    self.locationLabel.text = [NSString stringWithFormat:@"%.5f, %.5f", location.coordinate.latitude, location.coordinate.longitude];
    self.locationAccuracyLabel.text = [NSString stringWithFormat:@"+/- %dm", (int)round(location.horizontalAccuracy)];
    self.locationSpeedLabel.text = [NSString stringWithFormat:@"%dkm/h", (int)(round(location.speed*3.6))];
    
    int age = -(int)round([OLManager sharedManager].lastLocation.timestamp.timeIntervalSinceNow);
    self.locationAgeLabel.text = [NSString stringWithFormat:@"%d", age == 1 ? 0 : age];
}

- (IBAction)toggleLogging:(UISegmentedControl *)sender {
    NSLog(@"Logging: %@", [sender titleForSegmentAtIndex:sender.selectedSegmentIndex]);
    if(sender.selectedSegmentIndex == 0) {
        [[OLManager sharedManager] startAllUpdates];
    } else {
        [[OLManager sharedManager] stopAllUpdates];
    }
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
    NSString *val = intervalMap[(int)roundf([self.sendIntervalSlider value])];
    NSLog(@"Changed - Send Every: %@", val);
    [self updateSendIntervalLabel];
}

@end
