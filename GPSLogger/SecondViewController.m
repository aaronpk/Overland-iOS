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


@end
