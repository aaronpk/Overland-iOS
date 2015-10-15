//
//  TripModeViewController.m
//  GPSLogger
//
//  Created by Aaron Parecki on 10/15/15.
//  Copyright © 2015 Aaron Parecki. All rights reserved.
//

#import "TripModeViewController.h"
#import "GLManager.h"

@interface TripModeViewController ()

@end

@implementation TripModeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Navigation

/*
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark -

- (IBAction)tripModeButtonWasTapped:(UITapGestureRecognizer *)sender {
    [GLManager sharedManager].currentTripMode = [GLManager GLTripModes][sender.view.tag];
    [self dismissViewControllerAnimated:YES completion:^{}];
}


@end
