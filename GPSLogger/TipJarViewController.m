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
        NSLog(@"User can make payments");
        
        //If you have more than one in-app purchase, and would like
        //to have the user purchase a different product, simply define
        //another function and replace kRemoveAdsProductIdentifier with
        //the identifier for the other product
        
        [self.activityIndicator startAnimating];
        self.activityIndicator.hidden = NO;
        SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:@[
            @"app.p3k.overland.Wanderer",
            @"app.p3k.overland.Trailblazer",
            @"app.p3k.overland.Explorer",
            @"app.p3k.overland.Adventurer",
            @"app.p3k.overland.Cosmonaut",
            @"app.p3k.overland.Monthly.Commuter",
            @"app.p3k.overland.Monthly.Mariner",
            @"app.p3k.overland.Monthly.Aviator",
            @"app.p3k.overland.Monthly.Globetrotter",
            @"app.p3k.overland.Yearly.Commuter",
            @"app.p3k.overland.Yearly.Mariner",
            @"app.p3k.overland.Yearly.Aviator",
            @"app.p3k.overland.Yearly.Globetrotter"
        ]]];
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
    NSLog(@"Products %@", response.products);
    int count = (int)[response.products count];
    if(count > 0){
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.onetimeTips = [[NSMutableArray alloc] initWithCapacity:count];
            self.monthlyTips = [[NSMutableArray alloc] initWithCapacity:count];
            self.yearlyTips = [[NSMutableArray alloc] initWithCapacity:count];

            for(SKProduct *product in response.products) {
                if(product.subscriptionGroupIdentifier == nil) {
                    [self.onetimeTips addObject:product];
                } else {
                    if(product.subscriptionPeriod.unit == SKProductPeriodUnitYear) {
                        [self.yearlyTips addObject:product];
                    } else {
                        [self.monthlyTips addObject:product];
                    }
                }
            }
            
            [self.onetimeTips sortUsingComparator:^NSComparisonResult(SKProduct *obj1, SKProduct *obj2) {
                return [obj1.price doubleValue] > [obj2.price doubleValue];
            }];
            [self.monthlyTips sortUsingComparator:^NSComparisonResult(SKProduct *obj1, SKProduct *obj2) {
                return [obj1.price doubleValue] > [obj2.price doubleValue];
            }];
            [self.yearlyTips sortUsingComparator:^NSComparisonResult(SKProduct *obj1, SKProduct *obj2) {
                return [obj1.price doubleValue] > [obj2.price doubleValue];
            }];

            [self.tableView reloadData];
            [self.activityIndicator stopAnimating];
            self.activityIndicator.hidden = YES;
        });
    } else {
        NSLog(@"No products available");
        //this is called if your product id is not valid, this shouldn't be called unless that happens.
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
    GLTipTypes type = (int)indexPath.section;
    NSMutableArray *products;
    switch(type) {
        case kGLTipTypeYearly: 
            products = self.yearlyTips;
            break;
        case kGLTipTypeMonthly: 
            products = self.monthlyTips;
            break;
        case kGLTipTypeOneTime:
            products = self.onetimeTips;
            break;
    }
    return [products objectAtIndex:indexPath.row];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];

    UILabel *tipNameLabel = [c viewWithTag:500];
//    UILabel *tipDescriptionLabel = [c viewWithTag:600];
    UILabel *priceLabel = [c viewWithTag:700];
    UILabel *frequencyLabel = [c viewWithTag:701];
    
    SKProduct *product = [self productForIndexPath:indexPath];
    
    tipNameLabel.text = product.localizedTitle;
//    tipDescriptionLabel.text = product.localizedDescription;

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
    
    return c;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SKProduct *product = [self productForIndexPath:indexPath];
    NSLog(@"Purchasing %@", product.localizedTitle);
    [self purchase:product];
}

@end
