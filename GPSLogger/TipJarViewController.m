//
//  TipJarViewController.m
//  Overland
//
//  Created by Aaron Parecki on 12/19/23.
//  Copyright © 2023 Aaron Parecki. All rights reserved.
//

#import "TipJarViewController.h"
#import <SafariServices/SafariServices.h>
#import "GLManager.h"
#import "Overland-Swift.h"

@interface TipJarViewController () <UITableViewDataSource, UITableViewDelegate>

@end

@implementation TipJarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.yearlyTipsKeys = @[
        @"app.p3k.overland.Yearly.Commuter",
        @"app.p3k.overland.Yearly.Mariner",
        @"app.p3k.overland.Yearly.Aviator",
        @"app.p3k.overland.Yearly.Globetrotter"
    ];

    self.yearlyTips = [[NSMutableDictionary alloc] initWithCapacity:self.yearlyTipsKeys.count];
    [self.yearlyTips setObject:[@{@"name": @"Commuter"} mutableCopy] forKey:@"app.p3k.overland.Yearly.Commuter"];
    [self.yearlyTips setObject:[@{@"name": @"Mariner"} mutableCopy] forKey:@"app.p3k.overland.Yearly.Mariner"];
    [self.yearlyTips setObject:[@{@"name": @"Aviator"} mutableCopy] forKey:@"app.p3k.overland.Yearly.Aviator"];
    [self.yearlyTips setObject:[@{@"name": @"Globetrotter"} mutableCopy] forKey:@"app.p3k.overland.Yearly.Globetrotter"];
    
    self.monthlyTipsKeys = @[
        @"app.p3k.overland.Monthly.Commuter",
        @"app.p3k.overland.Monthly.Mariner",
        @"app.p3k.overland.Monthly.Aviator",
        @"app.p3k.overland.Monthly.Globetrotter"
    ];

    self.monthlyTips = [[NSMutableDictionary alloc] initWithCapacity:self.monthlyTipsKeys.count];
    [self.monthlyTips setObject:[@{@"name": @"Commuter"} mutableCopy] forKey:@"app.p3k.overland.Monthly.Commuter"];
    [self.monthlyTips setObject:[@{@"name": @"Mariner"} mutableCopy] forKey:@"app.p3k.overland.Monthly.Mariner"];
    [self.monthlyTips setObject:[@{@"name": @"Aviator"} mutableCopy] forKey:@"app.p3k.overland.Monthly.Aviator"];
    [self.monthlyTips setObject:[@{@"name": @"Globetrotter"} mutableCopy] forKey:@"app.p3k.overland.Monthly.Globetrotter"];

    self.onetimeTipsKeys = @[
        @"app.p3k.overland.Wanderer",
        @"app.p3k.overland.Trailblazer",
        @"app.p3k.overland.Explorer",
        @"app.p3k.overland.Adventurer",
        @"app.p3k.overland.Cosmonaut"
    ];

    self.onetimeTips = [[NSMutableDictionary alloc] initWithCapacity:self.onetimeTipsKeys.count];
    [self.onetimeTips setObject:[@{@"name": @"Wanderer"} mutableCopy] forKey:@"app.p3k.overland.Wanderer"];
    [self.onetimeTips setObject:[@{@"name": @"Trailblazer"} mutableCopy] forKey:@"app.p3k.overland.Trailblazer"];
    [self.onetimeTips setObject:[@{@"name": @"Explorer"} mutableCopy] forKey:@"app.p3k.overland.Explorer"];
    [self.onetimeTips setObject:[@{@"name": @"Adventurer"} mutableCopy] forKey:@"app.p3k.overland.Adventurer"];
    [self.onetimeTips setObject:[@{@"name": @"Cosmonaut"} mutableCopy] forKey:@"app.p3k.overland.Cosmonaut"];
    
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)viewWillAppear:(BOOL)animated {
    if(![TipJarStore shared].canMakePayments) {
        // Most likely due to parental controls
        NSLog(@"User cannot make payments");
        return;
    }

    NSMutableArray *identifiers = [NSMutableArray arrayWithArray:self.yearlyTipsKeys];
    [identifiers addObjectsFromArray:self.monthlyTipsKeys];
    [identifiers addObjectsFromArray:self.onetimeTipsKeys];

    [self.activityIndicator startAnimating];
    self.activityIndicator.hidden = NO;

    [[TipJarStore shared] loadProductsWithIdentifiers:identifiers completion:^(NSArray<TipJarProduct *> *products) {
        if(products.count == 0) {
            NSLog(@"No products available");
        }

        for(TipJarProduct *product in products) {
            NSMutableDictionary *item;
            if(!product.isSubscription) {
                item = [self.onetimeTips objectForKey:product.productID];
            } else if(product.isYearly) {
                item = [self.yearlyTips objectForKey:product.productID];
            } else {
                item = [self.monthlyTips objectForKey:product.productID];
            }
            [item setObject:product forKey:@"product"];
        }

        [self.tableView reloadData];
        [self.activityIndicator stopAnimating];
        self.activityIndicator.hidden = YES;
    }];
}

#pragma mark - StoreKit

- (void)purchase:(TipJarProduct *)product {
    [[TipJarStore shared] purchase:product fromViewController:self completion:^(TipJarPurchaseResult result, NSString *errorMessage) {
        switch(result) {
            case TipJarPurchaseResultPurchased:
                NSLog(@"Purchased %@", product.productID);
                [self showAlertWithTitle:@"Thank You!" message:@"Thanks for supporting Overland!"];
                break;
            case TipJarPurchaseResultPending:
                NSLog(@"Purchase of %@ is pending", product.productID);
                break;
            case TipJarPurchaseResultCancelled:
                NSLog(@"Purchase of %@ was cancelled", product.productID);
                break;
            case TipJarPurchaseResultFailed:
                [self showAlertWithTitle:@"Purchase Failed" message:errorMessage ?: @"The purchase couldn't be completed."];
                break;
        }
    }];
}

#pragma mark - TableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    GLTipTypes type = (int)section;
    switch(type) {
        case kGLTipTypeYearly: return self.yearlyTips.count;
        case kGLTipTypeMonthly: return self.monthlyTips.count;
        case kGLTipTypeOneTime: return self.onetimeTips.count;
        case kGLTipTypeFooter: return 1;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    GLTipTypes type = (int)section;
    switch(type) {
        case kGLTipTypeYearly: return @"Yearly Tips";
        case kGLTipTypeMonthly: return @"Monthly Tips";
        case kGLTipTypeOneTime: return @"One-Time Tips";
        case kGLTipTypeFooter: return @"";
    }
}

-(TipJarProduct *)productForIndexPath:(NSIndexPath *)indexPath {
    NSMutableDictionary *item = [self itemForIndexPath:indexPath];
    return [item objectForKey:@"product"];
}

-(NSMutableDictionary *)itemForIndexPath:(NSIndexPath *)indexPath {
    GLTipTypes type = (int)indexPath.section;
    NSArray *keys;
    NSMutableDictionary *products;
    switch(type) {
        case kGLTipTypeYearly:
            keys = self.yearlyTipsKeys;
            products = self.yearlyTips;
            break;
        case kGLTipTypeMonthly:
            keys = self.monthlyTipsKeys;
            products = self.monthlyTips;
            break;
        case kGLTipTypeOneTime:
            keys = self.onetimeTipsKeys;
            products = self.onetimeTips;
            break;
        case kGLTipTypeFooter:
            return nil;
            break;
    }
    NSString *key = [keys objectAtIndex:indexPath.row];
    return [products objectForKey:key];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    
    NSMutableDictionary *item = [self itemForIndexPath:indexPath];

    if(item == nil) {
        UITableViewCell *t = [tableView dequeueReusableCellWithIdentifier:@"terms" forIndexPath:indexPath];
        return t;
    }
    
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];

    UILabel *tipNameLabel = [c viewWithTag:500];
    UILabel *priceLabel = [c viewWithTag:700];
    UILabel *frequencyLabel = [c viewWithTag:701];
    
    TipJarProduct *product = [self productForIndexPath:indexPath];

    tipNameLabel.text = [item objectForKey:@"name"];

    if(product) {
        priceLabel.text = product.displayPrice;
        frequencyLabel.text = product.frequency;
    } else {
        priceLabel.text = @" ";
        frequencyLabel.text = @" ";
    }
    
    return c;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    TipJarProduct *product = [self productForIndexPath:indexPath];
    if(product) {
        NSLog(@"Purchasing %@", product.productID);
        [self purchase:product];
    }
}

- (IBAction)termsOfUseWasPressed:(UIButton *)sender {
    NSURL *url = [NSURL URLWithString:@"https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"];
    SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:url];
    [self presentViewController:safariViewController animated:YES completion:nil];
}

- (IBAction)privacyPolicyWasPressed:(UIButton *)sender {
    NSURL *url = [NSURL URLWithString:@"https://overland.p3k.app/privacy"];
    SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:url];
    // safariViewController.delegate = self;
    [self presentViewController:safariViewController animated:YES completion:nil];
}

- (IBAction)restorePurchasesWasPressed:(UIButton *)sender {
    NSLog(@"Restoring purchases");
    [[TipJarStore shared] restorePurchasesWithCompletion:^(NSString *errorMessage) {
        if(errorMessage) {
            [self showAlertWithTitle:@"Restore Failed" message:errorMessage];
        } else {
            [self showAlertWithTitle:@"Purchases Restored" message:@"Your purchases have been restored"];
        }
    }];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
                                   message:message
                                   preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
       handler:^(UIAlertAction * action) {}];

    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
