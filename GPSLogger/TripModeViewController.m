//
//  TripModeViewController.m
//  GPSLogger
//
//  Created by Aaron Parecki on 10/15/15.
//  Copyright © 2015 Aaron Parecki. All rights reserved.
//

#import "TripModeViewController.h"
#import "GLManager.h"
#import "Overland-Swift.h"

static NSString *const TripModeCellIdentifier = @"TripModeCell";

@interface TripModeCell : UICollectionViewCell
@property (strong, nonatomic) UIImageView *imageView;
@property (strong, nonatomic) UILabel *label;
@end

@implementation TripModeCell

- (instancetype)initWithFrame:(CGRect)frame {
    if(self = [super initWithFrame:frame]) {
        self.imageView = [[UIImageView alloc] init];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.imageView.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:36];
        self.label = [[UILabel alloc] init];
        self.label.font = [UIFont systemFontOfSize:13];
        self.label.textAlignment = NSTextAlignmentCenter;
        self.label.adjustsFontSizeToFitWidth = YES;
        self.label.minimumScaleFactor = 0.8;

        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.imageView, self.label]];
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 6;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:stack];
        [NSLayoutConstraint activateConstraints:@[
            [self.imageView.heightAnchor constraintEqualToConstant:48],
            [stack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [stack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [stack.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        ]];
        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;
    }
    return self;
}

@end

@interface TripModeViewController () <UICollectionViewDataSource, UICollectionViewDelegate>
@property (strong, nonatomic) NSArray<NSString *> *modes;
@end

@implementation TripModeViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.modes = GLTripModeStore.allModeIDs;

    UILabel *title = [[UILabel alloc] init];
    title.text = @"TRIP MODE";
    title.font = [UIFont systemFontOfSize:14];
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:title];

    // Three columns, like the original grid
    NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:
        [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0/3]
                                       heightDimension:[NSCollectionLayoutDimension fractionalHeightDimension:1]]];
    NSCollectionLayoutGroup *group = [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:
        [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1]
                                       heightDimension:[NSCollectionLayoutDimension absoluteDimension:90]]
                                                                         subitems:@[item]];
    NSCollectionLayoutSection *section = [NSCollectionLayoutSection sectionWithGroup:group];
    section.contentInsets = NSDirectionalEdgeInsetsMake(8, 20, 20, 20);
    UICollectionViewCompositionalLayout *layout = [[UICollectionViewCompositionalLayout alloc] initWithSection:section];

    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    collectionView.backgroundColor = UIColor.systemBackgroundColor;
    collectionView.dataSource = self;
    collectionView.delegate = self;
    [collectionView registerClass:TripModeCell.class forCellWithReuseIdentifier:TripModeCellIdentifier];
    collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [title.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [collectionView.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

#pragma mark - Collection view

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.modes.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    TripModeCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:TripModeCellIdentifier forIndexPath:indexPath];
    NSString *mode = self.modes[indexPath.item];
    BOOL selected = [mode isEqualToString:[GLManager sharedManager].currentTripMode];
    cell.imageView.image = [UIImage systemImageNamed:[GLTripModeStore symbolForModeID:mode]];
    cell.imageView.tintColor = selected ? [UIColor colorNamed:@"OverlandGreen"] : UIColor.labelColor;
    cell.label.text = [GLTripModeStore nameForModeID:mode];
    cell.label.font = selected ? [UIFont boldSystemFontOfSize:13] : [UIFont systemFontOfSize:13];
    cell.accessibilityLabel = cell.label.text;
    cell.accessibilityTraits = selected ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected) : UIAccessibilityTraitButton;
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [GLManager sharedManager].currentTripMode = self.modes[indexPath.item];
    [self dismissViewControllerAnimated:YES completion:^{}];
}

@end
