//
//  TipJarViewController.m
//  Overland
//
//  Created by Aaron Parecki on 12/19/23.
//  Copyright © 2023 Aaron Parecki. All rights reserved.
//

#import "TipJarViewController.h"
#import <StoreKit/StoreKit.h>

@interface TipJarViewController () <SKProductsRequestDelegate, SKPaymentTransactionObserver, UITableViewDataSource, UITableViewDelegate>

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
    if([SKPaymentQueue canMakePayments]){

        NSMutableSet *products = [NSMutableSet setWithArray:[self.yearlyTips allKeys]];
        [products addObjectsFromArray:[self.monthlyTips allKeys]];
        [products addObjectsFromArray:[self.onetimeTips allKeys]];

        [self.activityIndicator startAnimating];
        self.activityIndicator.hidden = NO;
        
        // NSLog(@"Fetching product details");
        SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:products];
        productsRequest.delegate = self;
        [productsRequest start];
    }
    else{
        NSLog(@"User cannot make payments due to parental controls");
        //this is called the user cannot make payments, most likely due to parental controls
        
    }
    
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark - StoreKit

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    int count = (int)[response.products count];
    if(count > 0){
//        NSLog(@"Products %@", response.products);
        dispatch_async(dispatch_get_main_queue(), ^{
            
            for(SKProduct *product in response.products) {
                NSMutableDictionary *item;
                if(product.subscriptionGroupIdentifier == nil) {
                    item = [self.onetimeTips objectForKey:product.productIdentifier];
                } else {
                    if(product.subscriptionPeriod.unit == SKProductPeriodUnitYear) {
                        item = [self.yearlyTips objectForKey:product.productIdentifier];
                    } else {
                        item = [self.monthlyTips objectForKey:product.productIdentifier];
                    }
                }
                [item setObject:product forKey:@"product"];
            }
            
            [self.tableView reloadData];
            [self.activityIndicator stopAnimating];
            self.activityIndicator.hidden = YES;
        });
    } else {
        NSLog(@"No products available");
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicator stopAnimating];
            self.activityIndicator.hidden = YES;
        });
    }
}

- (void)purchase:(SKProduct *)product{
    SKPayment *payment = [SKPayment paymentWithProduct:product];

    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    NSLog(@"received restored transactions: %i", (int)queue.transactions.count);
    for(SKPaymentTransaction *transaction in queue.transactions){
        if(transaction.transactionState == SKPaymentTransactionStateRestored){
            //called when the user successfully restores a purchase
            NSLog(@"Transaction state -> Restored");

            //if you have more than one in-app purchase product,
            //you restore the correct product for the identifier.
            //For example, you could use
            //if(productID == kRemoveAdsProductIdentifier)
            //to get the product identifier for the
            //restored purchases, you can use
            //
            //NSString *productID = transaction.payment.productIdentifier;
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            break;
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions{
    for(SKPaymentTransaction *transaction in transactions){
        //if you have multiple in app purchases in your app,
        //you can get the product identifier of this transaction
        //by using transaction.payment.productIdentifier
        //
        //then, check the identifier against the product IDs
        //that you have defined to check which product the user
        //just purchased

        switch(transaction.transactionState){
            case SKPaymentTransactionStatePurchasing: 
                NSLog(@"Transaction state -> Purchasing");
                // called when the user is in the process of purchasing, do not add any of your own code here.
                break;
            case SKPaymentTransactionStatePurchased:
                // this is called when the user has successfully purchased the item

                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                NSLog(@"Transaction state -> Purchased");
                break;
            case SKPaymentTransactionStateRestored:
                NSLog(@"Transaction state -> Restored");
                //add the same code as you did from SKPaymentTransactionStatePurchased here
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                //called when the transaction does not finish
                if(transaction.error.code == SKErrorPaymentCancelled){
                    NSLog(@"Transaction state -> Cancelled");
                    //the user cancelled the payment ;(
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            case SKPaymentTransactionStateDeferred:
                NSLog(@"Payment transaction deferred");
                break;
        }
    }
}

#pragma mark - TableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    GLTipTypes type = (int)section;
    switch(type) {
        case kGLTipTypeYearly: return self.yearlyTips.count;
        case kGLTipTypeMonthly: return self.monthlyTips.count;
        case kGLTipTypeOneTime: return self.onetimeTips.count;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    GLTipTypes type = (int)section;
    switch(type) {
        case kGLTipTypeYearly: return @"Yearly Tips";
        case kGLTipTypeMonthly: return @"Monthly Tips";
        case kGLTipTypeOneTime: return @"One-Time Tips";
    }
}

-(SKProduct *)productForIndexPath:(NSIndexPath *)indexPath {
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
    }
    NSString *key = [keys objectAtIndex:indexPath.row];
    return [products objectForKey:key];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];

    UILabel *tipNameLabel = [c viewWithTag:500];
    UILabel *priceLabel = [c viewWithTag:700];
    UILabel *frequencyLabel = [c viewWithTag:701];
    
    NSMutableDictionary *item = [self itemForIndexPath:indexPath];
    SKProduct *product = [self productForIndexPath:indexPath];

    tipNameLabel.text = [item objectForKey:@"name"];

    if(product) {
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
        [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        [numberFormatter setLocale:product.priceLocale];
        priceLabel.text = [numberFormatter stringFromNumber:product.price];
        
        if(product.subscriptionGroupIdentifier == nil) {
            frequencyLabel.text = @"one time";
        } else {
            switch(product.subscriptionPeriod.unit) {
                case SKProductPeriodUnitDay:
                    frequencyLabel.text = @"daily"; break;
                case SKProductPeriodUnitWeek:
                    frequencyLabel.text = @"weekly"; break;
                case SKProductPeriodUnitMonth:
                    frequencyLabel.text = @"monthly"; break;
                case SKProductPeriodUnitYear:
                    frequencyLabel.text = @"yearly"; break;
            }
        }
    } else {
        priceLabel.text = @" ";
        frequencyLabel.text = @" ";
    }
        
    
    return c;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SKProduct *product = [self productForIndexPath:indexPath];
    if(product) {
        NSLog(@"Purchasing %@", product.localizedTitle);
        [self purchase:product];
    }
}

@end
