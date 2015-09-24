//
//  SecondViewController.m
//  GPSLogger
//
//  Created by Aaron Parecki on 9/17/15.
//  Copyright © 2015 Esri. All rights reserved.
//

#import "SecondViewController.h"
#import "GLManager.h"

@interface SecondViewController ()

@end

@implementation SecondViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)viewWillAppear:(BOOL)animated {
    self.pausesAutomatically.on = [GLManager sharedManager].pausesAutomatically;
    self.apiEndpointField.text = [[NSUserDefaults standardUserDefaults] stringForKey:GLAPIEndpointDefaultsName];
    self.activityType.selectedSegmentIndex = [GLManager sharedManager].activityType - 1;
    
    CLLocationAccuracy d = [GLManager sharedManager].desiredAccuracy;
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
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)togglePausesAutomatically:(UISwitch *)sender {
    [GLManager sharedManager].pausesAutomatically = sender.on;
}

- (IBAction)activityTypeControlWasChanged:(UISegmentedControl *)sender {
    [GLManager sharedManager].activityType = sender.selectedSegmentIndex + 1; // activityType is an enum starting at 1
}

- (IBAction)desiredAccuracyWasChanged:(UISegmentedControl *)sender {
    NSLog(@"Setting desiredAccuracy: %d", sender.selectedSegmentIndex);
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
        [GLManager sharedManager].desiredAccuracy = d;
}


@end
