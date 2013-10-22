//
//  OLFirstViewController.h
//  OfflineLogger
//
//  Created by Aaron Parecki on 10/21/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OLFirstViewController : UIViewController

@property (strong, nonatomic) IBOutlet UILabel *sendIntervalLabel;

- (IBAction)toggleLogging:(id)sender;
- (IBAction)sendIntervalChanged:(id)sender;


@end
