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
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *activityIndicator;

@property (nonatomic, strong) NSMutableDictionary *onetimeTips;
@property (nonatomic, strong) NSArray *onetimeTipsKeys;
@property (nonatomic, strong) NSMutableDictionary *monthlyTips;
@property (nonatomic, strong) NSArray *monthlyTipsKeys;
@property (nonatomic, strong) NSMutableDictionary *yearlyTips;
@property (nonatomic, strong) NSArray *yearlyTipsKeys;

@end

NS_ASSUME_NONNULL_END
