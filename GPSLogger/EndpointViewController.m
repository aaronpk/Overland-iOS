//
//  EndpointViewController.m
//  GPSLogger
//
//  Created by Aaron Parecki on 10/3/17.
//  Copyright © 2017 Aaron Parecki. All rights reserved.
//

#import "EndpointViewController.h"
#import "GLManager.h"

@interface EndpointViewController ()

@end

@implementation EndpointViewController

- (void)viewWillAppear:(BOOL)animated {
    self.apiEndpointField.text = [GLManager sharedManager].apiEndpointURL;
    self.accessTokenField.text = [GLManager sharedManager].apiAccessToken;
    self.deviceIdField.text = [GLManager sharedManager].deviceId;
    self.apiEndpointField.backgroundColor = [UIColor clearColor];
}

- (IBAction)saveButtonWasTapped:(UIButton *)sender {
    NSURL *newURL = [NSURL URLWithString:self.apiEndpointField.text];

    if(newURL != nil && ([newURL.scheme isEqualToString:@"https"] || [newURL.scheme isEqualToString:@"http"])) {
        self.apiEndpointField.backgroundColor = [UIColor clearColor];
        
        [[GLManager sharedManager] saveNewDeviceId:self.deviceIdField.text];
        [[GLManager sharedManager] saveNewAPIEndpoint:self.apiEndpointField.text andAccessToken:self.accessTokenField.text];
        [self dismissViewControllerAnimated:YES completion:nil];
    } else if(self.apiEndpointField.text.length == 0) {

        [[GLManager sharedManager] saveNewDeviceId:self.deviceIdField.text];
        [[GLManager sharedManager] saveNewAPIEndpoint:nil andAccessToken:nil];
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        self.apiEndpointField.backgroundColor = [UIColor colorWithRed:1.0 green:0.82 blue:0.82 alpha:1.0];
    }
}

@end
