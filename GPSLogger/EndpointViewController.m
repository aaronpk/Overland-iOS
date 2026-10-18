//
//  EndpointViewController.m
//  GPSLogger
//
//  Created by Aaron Parecki on 10/3/17.
//  Copyright © 2017 Aaron Parecki. All rights reserved.
//

#import "EndpointViewController.h"
#import "GLManager.h"
#import "CustomHeadersViewController.h"

@interface EndpointViewController ()

// Edits from the custom headers screen are held here until the Save button is tapped
@property (strong, nonatomic) NSArray *pendingCustomHeaders;
@property (nonatomic) BOOL customHeadersWereEdited;

@end

@implementation EndpointViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.pendingCustomHeaders = [[GLManager sharedManager] customHeaders];
}

- (void)viewWillAppear:(BOOL)animated {
    self.apiEndpointField.text = [GLManager sharedManager].apiEndpointURL;
    self.accessTokenField.text = [GLManager sharedManager].apiAccessToken;
    self.deviceIdField.text = [GLManager sharedManager].deviceId;
    self.apiEndpointField.backgroundColor = [UIColor clearColor];

    self.customHeadersButton.backgroundColor = [self.customHeadersButton.tintColor colorWithAlphaComponent:0.12];
    self.customHeadersButton.layer.cornerRadius = 8;
    self.customHeadersButton.clipsToBounds = YES;

    [self updateCustomHeadersButtonTitle];
}

- (void)updateCustomHeadersButtonTitle {
    NSArray *headers = self.pendingCustomHeaders;
    if (headers.count > 0) {
        [self.customHeadersButton setTitle:[NSString stringWithFormat:@"Custom Headers (%lu)", (unsigned long)headers.count] forState:UIControlStateNormal];
    } else {
        [self.customHeadersButton setTitle:@"Custom Headers" forState:UIControlStateNormal];
    }
}

- (IBAction)saveButtonWasTapped:(UIButton *)sender {
    NSURL *newURL = [NSURL URLWithString:self.apiEndpointField.text];

    if(newURL != nil && ([newURL.scheme isEqualToString:@"https"] || [newURL.scheme isEqualToString:@"http"])) {
        self.apiEndpointField.backgroundColor = [UIColor clearColor];

        [[GLManager sharedManager] saveNewDeviceId:self.deviceIdField.text];
        [[GLManager sharedManager] saveNewAPIEndpoint:self.apiEndpointField.text andAccessToken:self.accessTokenField.text];
        [self saveCustomHeadersIfEdited];

        [[NSNotificationCenter defaultCenter] postNotificationName:GLSettingsChangedNotification object:self];

        [self dismissViewControllerAnimated:YES completion:nil];
    } else if(self.apiEndpointField.text.length == 0) {

        [[GLManager sharedManager] saveNewDeviceId:self.deviceIdField.text];
        [[GLManager sharedManager] saveNewAPIEndpoint:nil andAccessToken:nil];
        [self saveCustomHeadersIfEdited];

        [[NSNotificationCenter defaultCenter] postNotificationName:GLSettingsChangedNotification object:self];

        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        self.apiEndpointField.backgroundColor = [UIColor colorWithRed:1.0 green:0.82 blue:0.82 alpha:1.0];
    }
}

// Called after saveNewAPIEndpoint, which clears custom headers if the host changed.
// Headers the user edited on this screen are kept even if the host changed.
- (void)saveCustomHeadersIfEdited {
    if(self.customHeadersWereEdited) {
        [[GLManager sharedManager] saveCustomHeaders:self.pendingCustomHeaders];
    }
}

- (IBAction)customHeadersButtonTapped:(UIButton *)sender {
    CustomHeadersViewController *vc = [[CustomHeadersViewController alloc] initWithStyle:UITableViewStylePlain];
    vc.initialHeaders = self.pendingCustomHeaders;
    __weak EndpointViewController *weakSelf = self;
    vc.completionHandler = ^(NSArray *headers) {
        weakSelf.pendingCustomHeaders = headers;
        weakSelf.customHeadersWereEdited = YES;
        [weakSelf updateCustomHeadersButtonTitle];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil];
}

@end
