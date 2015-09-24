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

- (void)viewDidAppear:(BOOL)animated {
    self.pausesAutomatically.on = [GLManager sharedManager].pausesAutomatically;
    self.apiEndpointField.text = [[NSUserDefaults standardUserDefaults] stringForKey:GLAPIEndpointDefaultsName];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)togglePausesAutomatically:(UISwitch *)sender {
    [GLManager sharedManager].pausesAutomatically = sender.on;
}


@end
