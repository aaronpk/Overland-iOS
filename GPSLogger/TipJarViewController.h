//
//  TipJarViewController.h
//  Overland
//
//  Created by Aaron Parecki on 12/19/23.
//  Copyright © 2023 Aaron Parecki. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    kGLTipTypeMonthly,
    kGLTipTypeYearly,
    kGLTipTypeOneTime,
} GLTipTypes;

@interface TipJarViewController : UIViewController

@property (nonatomic, strong) IBOutlet UILabel *headerLabel;
@property (nonatomic, strong) IBOutlet UITableView *tableView;

@property (nonatomic, strong) NSMutableArray <SKProduct *> *onetimeTips;
@property (nonatomic, strong) NSMutableArray <SKProduct *> *monthlyTips;
@property (nonatomic, strong) NSMutableArray <SKProduct *> *yearlyTips;

@end

NS_ASSUME_NONNULL_END
