//
//  EndpointViewController.h
//  GPSLogger
//
//  Created by Aaron Parecki on 10/3/17.
//  Copyright © 2017 Aaron Parecki. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface EndpointViewController : UIViewController

@property (strong, nonatomic) IBOutlet UITextField *apiEndpointField;
@property (strong, nonatomic) IBOutlet UITextField *accessTokenField;
@property (strong, nonatomic) IBOutlet UITextField *deviceIdField;
@property (strong, nonatomic) IBOutlet UIButton *customHeadersButton;

- (IBAction)saveButtonWasTapped:(UIButton *)sender;
- (IBAction)customHeadersButtonTapped:(UIButton *)sender;

@end
