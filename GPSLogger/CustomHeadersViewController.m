//
//  CustomHeadersViewController.m
//  GPSLogger
//

#import "CustomHeadersViewController.h"
#import "GLManager.h"

static NSString *const HeaderCellIdentifier  = @"HeaderCell";
static NSString *const WarningCellIdentifier = @"WarningCell";
static NSString *const SpacerCellIdentifier  = @"SpacerCell";

#pragma mark - Row model

typedef NS_ENUM(NSInteger, RowType) {
    RowTypeCard,
    RowTypeWarning,
    RowTypeSpacer,
};

@interface RowItem : NSObject
@property (nonatomic) RowType type;
@property (nonatomic) NSInteger headerIndex;
@property (nonatomic, copy) NSString *warningText;
@end

@implementation RowItem
+ (instancetype)cardForIndex:(NSInteger)index {
    RowItem *item = [[RowItem alloc] init];
    item.type = RowTypeCard;
    item.headerIndex = index;
    return item;
}
+ (instancetype)warningForIndex:(NSInteger)index text:(NSString *)text {
    RowItem *item = [[RowItem alloc] init];
    item.type = RowTypeWarning;
    item.headerIndex = index;
    item.warningText = text;
    return item;
}
+ (instancetype)spacer {
    RowItem *item = [[RowItem alloc] init];
    item.type = RowTypeSpacer;
    item.headerIndex = -1;
    return item;
}
@end

#pragma mark - HeaderTableViewCell

@interface HeaderTableViewCell : UITableViewCell

@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UITextField *keyField;
@property (nonatomic, strong) UITextField *valueField;

@end

@implementation HeaderTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];

        _cardView = [[UIView alloc] init];
        _cardView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        _cardView.layer.cornerRadius = 10;
        _cardView.translatesAutoresizingMaskIntoConstraints = NO;

        _keyField = [[UITextField alloc] init];
        _keyField.placeholder = @"Header Name";
        _keyField.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _keyField.autocorrectionType = UITextAutocorrectionTypeNo;
        _keyField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _keyField.spellCheckingType = UITextSpellCheckingTypeNo;
        _keyField.smartDashesType = UITextSmartDashesTypeNo;
        _keyField.returnKeyType = UIReturnKeyNext;
        _keyField.clearButtonMode = UITextFieldViewModeWhileEditing;
        _keyField.translatesAutoresizingMaskIntoConstraints = NO;

        _valueField = [[UITextField alloc] init];
        _valueField.placeholder = @"Header Value";
        _valueField.font = [UIFont systemFontOfSize:15];
        _valueField.autocorrectionType = UITextAutocorrectionTypeNo;
        _valueField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _valueField.spellCheckingType = UITextSpellCheckingTypeNo;
        _valueField.smartDashesType = UITextSmartDashesTypeNo;
        _valueField.returnKeyType = UIReturnKeyDone;
        _valueField.clearButtonMode = UITextFieldViewModeWhileEditing;
        _valueField.translatesAutoresizingMaskIntoConstraints = NO;

        UIView *separator = [[UIView alloc] init];
        separator.backgroundColor = [UIColor separatorColor];
        separator.translatesAutoresizingMaskIntoConstraints = NO;

        [self.contentView addSubview:_cardView];
        [_cardView addSubview:_keyField];
        [_cardView addSubview:separator];
        [_cardView addSubview:_valueField];

        [NSLayoutConstraint activateConstraints:@[
            [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

            [_keyField.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:8],
            [_keyField.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:12],
            [_keyField.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-12],

            [separator.topAnchor constraintEqualToAnchor:_keyField.bottomAnchor constant:6],
            [separator.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:12],
            [separator.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-12],
            [separator.heightAnchor constraintEqualToConstant:0.5],

            [_valueField.topAnchor constraintEqualToAnchor:separator.bottomAnchor constant:6],
            [_valueField.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:12],
            [_valueField.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-12],
            [_valueField.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-8],
        ]];
    }
    return self;
}

@end

#pragma mark - WarningTableViewCell

@interface WarningTableViewCell : UITableViewCell

@property (nonatomic, strong) UILabel *warningLabel;

@end

@implementation WarningTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];

        _warningLabel = [[UILabel alloc] init];
        _warningLabel.font = [UIFont systemFontOfSize:12];
        _warningLabel.textColor = [UIColor systemRedColor];
        _warningLabel.numberOfLines = 0;
        _warningLabel.translatesAutoresizingMaskIntoConstraints = NO;

        [self.contentView addSubview:_warningLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_warningLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:2],
            [_warningLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:28],
            [_warningLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-28],
            [_warningLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        ]];
    }
    return self;
}

@end

#pragma mark - SpacerTableViewCell

@interface SpacerTableViewCell : UITableViewCell
@end

@implementation SpacerTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
    }
    return self;
}

@end

#pragma mark - CustomHeadersViewController

@interface CustomHeadersViewController () <UITextFieldDelegate>

@property (nonatomic, strong) NSMutableArray *headers;
@property (nonatomic, strong) NSArray<RowItem *> *rows;
@property (nonatomic) BOOL transitioningBetweenFields;

@end

@implementation CustomHeadersViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Custom Headers";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                           target:self
                                                                                           action:@selector(addHeader:)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                          target:self
                                                                                          action:@selector(doneButtonTapped:)];

    [self.tableView registerClass:[HeaderTableViewCell class] forCellReuseIdentifier:HeaderCellIdentifier];
    [self.tableView registerClass:[WarningTableViewCell class] forCellReuseIdentifier:WarningCellIdentifier];
    [self.tableView registerClass:[SpacerTableViewCell class] forCellReuseIdentifier:SpacerCellIdentifier];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;

    UILabel *footerLabel = [[UILabel alloc] init];
    footerLabel.text = @"Custom headers are sent with every request to the server.";
    footerLabel.font = [UIFont systemFontOfSize:12];
    footerLabel.textColor = [UIColor tertiaryLabelColor];
    footerLabel.textAlignment = NSTextAlignmentCenter;
    footerLabel.numberOfLines = 0;
    footerLabel.frame = CGRectMake(0, 0, 0, 30);
    self.tableView.tableFooterView = footerLabel;

    self.headers = [[[GLManager sharedManager] customHeaders] mutableCopy];
    [self rebuildRows];
}

- (void)rebuildRows {
    NSMutableArray<RowItem *> *items = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)self.headers.count; i++) {
        if (i > 0) {
            [items addObject:[RowItem spacer]];
        }
        [items addObject:[RowItem cardForIndex:i]];
        NSString *warning = [self warningForHeaderIndex:i];
        if (warning) {
            [items addObject:[RowItem warningForIndex:i text:warning]];
        }
    }
    self.rows = [items copy];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.headers.count == 0) {
        UILabel *label = [[UILabel alloc] init];
        label.text = @"No custom headers.\nTap + to add one.";
        label.numberOfLines = 0;
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = [UIColor secondaryLabelColor];
        label.font = [UIFont systemFontOfSize:15];
        self.tableView.backgroundView = label;
    } else {
        self.tableView.backgroundView = nil;
    }
    return self.rows.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    RowItem *item = self.rows[indexPath.row];
    if (item.type == RowTypeSpacer) {
        return 6;
    }
    return UITableViewAutomaticDimension;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RowItem *item = self.rows[indexPath.row];

    if (item.type == RowTypeCard) {
        HeaderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:HeaderCellIdentifier forIndexPath:indexPath];
        NSDictionary *header = self.headers[item.headerIndex];

        cell.keyField.text = header[@"key"];
        cell.valueField.text = header[@"value"];

        cell.keyField.delegate = self;
        cell.valueField.delegate = self;

        NSString *warning = [self warningForHeaderIndex:item.headerIndex];
        cell.keyField.textColor = warning ? [UIColor systemRedColor] : [UIColor labelColor];

        return cell;
    } else if (item.type == RowTypeWarning) {
        WarningTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:WarningCellIdentifier forIndexPath:indexPath];
        cell.warningLabel.text = item.warningText;
        return cell;
    } else {
        return [tableView dequeueReusableCellWithIdentifier:SpacerCellIdentifier forIndexPath:indexPath];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    RowItem *item = self.rows[indexPath.row];
    return item.type == RowTypeCard;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        RowItem *item = self.rows[indexPath.row];
        [self.headers removeObjectAtIndex:item.headerIndex];
        [self saveHeaders];
        [self rebuildRows];
        [self.tableView reloadData];
    }
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidEndEditing:(UITextField *)textField {
    HeaderTableViewCell *cell = (HeaderTableViewCell *)[self cellForTextField:textField];
    if (cell == nil) return;

    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (indexPath == nil) return;

    RowItem *item = self.rows[indexPath.row];
    if (item.headerIndex >= (NSInteger)self.headers.count) return;

    NSString *key = cell.keyField.text ?: @"";
    NSString *value = cell.valueField.text ?: @"";

    self.headers[item.headerIndex] = @{@"key": key, @"value": value};
    [self saveHeaders];

    if (!self.transitioningBetweenFields) {
        [self rebuildRows];
        [self.tableView reloadData];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    HeaderTableViewCell *cell = (HeaderTableViewCell *)[self cellForTextField:textField];
    if (cell == nil) return YES;

    if (textField == cell.keyField) {
        self.transitioningBetweenFields = YES;
        [cell.valueField becomeFirstResponder];
        self.transitioningBetweenFields = NO;
    } else {
        [textField resignFirstResponder];
    }
    return YES;
}

- (UITableViewCell *)cellForTextField:(UITextField *)textField {
    UIView *view = textField.superview;
    while (view != nil && ![view isKindOfClass:[UITableViewCell class]]) {
        view = view.superview;
    }
    return (UITableViewCell *)view;
}

#pragma mark - Validation

- (NSString *)warningForHeaderIndex:(NSInteger)index {
    if (index >= (NSInteger)self.headers.count) return nil;

    NSString *key = self.headers[index][@"key"];
    if (key.length == 0) return nil;

    if ([key caseInsensitiveCompare:@"Authorization"] == NSOrderedSame) {
        return @"Use the Access Token field for authorization. This header will not be sent.";
    }

    for (NSInteger i = 0; i < (NSInteger)self.headers.count; i++) {
        if (i == index) continue;
        NSString *otherKey = self.headers[i][@"key"];
        if (otherKey.length > 0 && [key caseInsensitiveCompare:otherKey] == NSOrderedSame) {
            return @"Duplicate header name. This may cause unexpected behavior.";
        }
    }

    return nil;
}

#pragma mark - Actions

- (void)addHeader:(id)sender {
    [self.view endEditing:YES];

    [self.headers addObject:@{@"key": @"", @"value": @""}];
    [self rebuildRows];
    [self.tableView reloadData];

    NSInteger newHeaderIndex = self.headers.count - 1;
    for (NSInteger i = 0; i < (NSInteger)self.rows.count; i++) {
        RowItem *item = self.rows[i];
        if (item.type == RowTypeCard && item.headerIndex == newHeaderIndex) {
            NSIndexPath *path = [NSIndexPath indexPathForRow:i inSection:0];
            [self.tableView scrollToRowAtIndexPath:path atScrollPosition:UITableViewScrollPositionBottom animated:YES];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                HeaderTableViewCell *cell = [self.tableView cellForRowAtIndexPath:path];
                [cell.keyField becomeFirstResponder];
            });
            break;
        }
    }
}

- (void)saveHeaders {
    NSMutableArray *nonEmpty = [NSMutableArray array];
    for (NSDictionary *header in self.headers) {
        if ([header[@"key"] length] > 0 && [header[@"value"] length] > 0) {
            [nonEmpty addObject:header];
        }
    }
    [[GLManager sharedManager] saveCustomHeaders:[nonEmpty copy]];
}

- (void)doneButtonTapped:(id)sender {
    [self.view endEditing:YES];
    [self saveHeaders];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
