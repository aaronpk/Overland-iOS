//
//  OLFirstViewController.m
//  OfflineLogger
//
//  Created by Aaron Parecki on 10/21/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import "OLFirstViewController.h"

@interface OLFirstViewController ()

@end

@implementation OLFirstViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)toggleLogging:(UISegmentedControl *)sender {
    NSLog(@"Logging: %@", [sender titleForSegmentAtIndex:sender.selectedSegmentIndex]);
}

- (IBAction)sendIntervalChanged:(UISlider *)sender {
    NSLog(@"Send Every: %f", roundf([sender value]));
}


@end
