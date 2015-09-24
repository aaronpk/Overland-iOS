//
//  SecondViewController.h
//  GPSLogger
//
//  Created by Aaron Parecki on 9/17/15.
//  Copyright © 2015 Esri. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SecondViewController : UIViewController

@property (strong, nonatomic) IBOutlet UITextField *apiEndpointField;
@property (strong, nonatomic) IBOutlet UISwitch *pausesAutomatically;
@property (strong, nonatomic) IBOutlet UISegmentedControl *activityType;

- (IBAction)togglePausesAutomatically:(id)sender;
- (IBAction)activityTypeControlWasChanged:(id)sender;

@end

