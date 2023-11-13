//
//  WifiZoneViewController.h
//  Overland
//
//  Created by Aaron Parecki on 3/2/19.
//  Copyright © 2019 Aaron Parecki. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WifiZoneViewController : UIViewController

@property (strong, nonatomic) IBOutlet UITextField *wifiNameField;
@property (strong, nonatomic) IBOutlet UITextField *latitudeField;
@property (strong, nonatomic) IBOutlet UITextField *longitudeField;
@property (strong, nonatomic) IBOutlet UIButton *resetButton;

- (IBAction)saveButtonWasTapped:(UIButton *)sender;
- (IBAction)resetButtonWasTapped:(UIButton *)sender;

@end

NS_ASSUME_NONNULL_END
