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

// Choosing between a server and iCloud Drive
@property (strong, nonatomic) UISegmentedControl *destinationControl;
@property (strong, nonatomic) UILabel *fileModeLabel;
@property (strong, nonatomic) UISegmentedControl *fileModeControl;
@property (copy, nonatomic) NSString *serverInfoText;

@end

@implementation EndpointViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.pendingCustomHeaders = [[GLManager sharedManager] customHeaders];
    self.serverInfoText = self.infoTextView.text;

    // Add the destination choice above the server fields, styled like the other field labels
    self.destinationControl = [[UISegmentedControl alloc] initWithItems:@[@"Server", @"iCloud Drive"]];
    [self.destinationControl addTarget:self action:@selector(destinationWasChanged:) forControlEvents:UIControlEventValueChanged];
    self.fileModeLabel = [self fieldLabelWithText:@"FILES"];
    self.fileModeControl = [[UISegmentedControl alloc] initWithItems:@[@"One per day", @"Trips only"]];
    [self.fileModeControl addTarget:self action:@selector(fileModeWasChanged:) forControlEvents:UIControlEventValueChanged];

    NSArray *views = @[[self fieldLabelWithText:@"DESTINATION"], self.destinationControl, self.fileModeLabel, self.fileModeControl];
    for (NSUInteger i = 0; i < views.count; i++) {
        [self.stackView insertArrangedSubview:views[i] atIndex:i];
    }
    [self.stackView setCustomSpacing:12 afterView:self.destinationControl];
    [self.stackView setCustomSpacing:12 afterView:self.fileModeControl];

    self.destinationControl.selectedSegmentIndex = [GLManager sharedManager].savesToICloudDrive ? 1 : 0;
    self.fileModeControl.selectedSegmentIndex = ([GLManager sharedManager].cloudFileMode == GLCloudFileModeTrips) ? 1 : 0;
    [self updateVisibleFields];
}

- (UILabel *)fieldLabelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont systemFontOfSize:14];
    label.textAlignment = NSTextAlignmentCenter;
    return label;
}

- (BOOL)iCloudDriveSelected {
    return self.destinationControl.selectedSegmentIndex == 1;
}

- (void)destinationWasChanged:(UISegmentedControl *)sender {
    [self.view endEditing:YES];
    [self updateVisibleFields];
}

- (void)fileModeWasChanged:(UISegmentedControl *)sender {
    [self updateVisibleFields];
}

// The server fields only apply when sending to a server. The device ID applies to both.
- (void)updateVisibleFields {
    BOOL iCloud = [self iCloudDriveSelected];
    for (UIView *view in @[self.endpointLabel, self.apiEndpointField, self.accessTokenLabel, self.accessTokenField, self.customHeadersButton]) {
        view.hidden = iCloud;
    }
    self.fileModeLabel.hidden = !iCloud;
    self.fileModeControl.hidden = !iCloud;

    if (iCloud) {
        NSString *files = (self.fileModeControl.selectedSegmentIndex == 1)
            ? @"Only points recorded during trips are saved, in one file per trip in the Trips folder, named by when the trip started."
            : @"Points are saved in one file per day, by the UTC date, such as 2026/10/2026-10-19.geojson.";
        self.infoTextView.text = [NSString stringWithFormat:@"This app can save its location data to GeoJSON files in iCloud Drive instead of sending it to a server. The files appear in the Overland folder in iCloud Drive, in the Files app and on your other devices.\n\n%@\n\nYou can optionally add a Device ID to identify this device. This string will be included in the properties of each point.", files];
    } else {
        self.infoTextView.text = self.serverInfoText;
    }
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
    if ([self iCloudDriveSelected]) {
        // The server settings are kept, so switching back to the server restores them
        [[GLManager sharedManager] saveNewDeviceId:self.deviceIdField.text];
        [GLManager sharedManager].savesToICloudDrive = YES;
        [GLManager sharedManager].cloudFileMode = (self.fileModeControl.selectedSegmentIndex == 1) ? GLCloudFileModeTrips : GLCloudFileModeDaily;
        [[NSNotificationCenter defaultCenter] postNotificationName:GLSettingsChangedNotification object:self];
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    [GLManager sharedManager].savesToICloudDrive = NO;

    NSURL *newURL = [NSURL URLWithString:self.apiEndpointField.text];

    if(newURL != nil && ([newURL.scheme isEqualToString:@"https"] || [newURL.scheme isEqualToString:@"http"])) {
        self.apiEndpointField.backgroundColor = [UIColor clearColor];

        [[GLManager sharedManager] saveNewDeviceId:self.deviceIdField.text];
        [[GLManager sharedManager] saveNewAPIEndpoint:self.apiEndpointField.text andAccessToken:self.accessTokenField.text];
        [[GLManager sharedManager] saveCustomHeaders:self.pendingCustomHeaders];

        [[NSNotificationCenter defaultCenter] postNotificationName:GLSettingsChangedNotification object:self];

        [self dismissViewControllerAnimated:YES completion:nil];
    } else if(self.apiEndpointField.text.length == 0) {

        [[GLManager sharedManager] saveNewDeviceId:self.deviceIdField.text];
        [[GLManager sharedManager] saveNewAPIEndpoint:nil andAccessToken:nil];
        [[GLManager sharedManager] saveCustomHeaders:self.pendingCustomHeaders];

        [[NSNotificationCenter defaultCenter] postNotificationName:GLSettingsChangedNotification object:self];

        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        self.apiEndpointField.backgroundColor = [UIColor colorWithRed:1.0 green:0.82 blue:0.82 alpha:1.0];
    }
}

- (IBAction)customHeadersButtonTapped:(UIButton *)sender {
    CustomHeadersViewController *vc = [[CustomHeadersViewController alloc] initWithStyle:UITableViewStylePlain];
    vc.initialHeaders = self.pendingCustomHeaders;
    __weak EndpointViewController *weakSelf = self;
    vc.completionHandler = ^(NSArray *headers) {
        weakSelf.pendingCustomHeaders = headers;
        [weakSelf updateCustomHeadersButtonTitle];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil];
}

@end
