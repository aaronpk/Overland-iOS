//
//  OLSecondViewController.m
//  OfflineLogger
//
//  Created by Aaron Parecki on 10/21/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import "OLSecondViewController.h"
#import "OLManager.h"

@interface OLSecondViewController ()

@end

@implementation OLSecondViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewWillAppear:(BOOL)animated
{
    self.apiEndpointField.text = [[NSUserDefaults standardUserDefaults] stringForKey:OLAPIEndpointDefaultsName];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
