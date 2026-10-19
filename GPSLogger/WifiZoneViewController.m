//
//  WifiZoneViewController.m
//  Overland
//
//  Created by Aaron Parecki on 3/2/19.
//  Copyright © 2019 Aaron Parecki. All rights reserved.
//

#import "WifiZoneViewController.h"
#import "GLManager.h"

static NSString *const ZoneCellIdentifier  = @"ZoneCell";
static NSString *const FieldCellIdentifier = @"FieldCell";

typedef NS_ENUM(NSInteger, WifiZoneField) {
    WifiZoneFieldName,
    WifiZoneFieldLatitude,
    WifiZoneFieldLongitude,
    WifiZoneFieldCount,
};

#pragma mark - WifiZoneFieldCell

@interface WifiZoneFieldCell : UITableViewCell

@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UITextField *textField;

@end

@implementation WifiZoneFieldCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [UIFont systemFontOfSize:17];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_nameLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

        _textField = [[UITextField alloc] init];
        _textField.font = [UIFont systemFontOfSize:17];
        _textField.textAlignment = NSTextAlignmentRight;
        _textField.autocorrectionType = UITextAutocorrectionTypeNo;
        _textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _textField.spellCheckingType = UITextSpellCheckingTypeNo;
        _textField.smartDashesType = UITextSmartDashesTypeNo;
        _textField.smartQuotesType = UITextSmartQuotesTypeNo;
        _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        _textField.translatesAutoresizingMaskIntoConstraints = NO;

        [self.contentView addSubview:_nameLabel];
        [self.contentView addSubview:_textField];

        UILayoutGuide *margins = self.contentView.layoutMarginsGuide;
        [NSLayoutConstraint activateConstraints:@[
            [_nameLabel.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
            [_nameLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],

            [_textField.leadingAnchor constraintEqualToAnchor:_nameLabel.trailingAnchor constant:12],
            [_textField.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
            [_textField.topAnchor constraintEqualToAnchor:margins.topAnchor],
            [_textField.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor],
            [_textField.heightAnchor constraintGreaterThanOrEqualToConstant:30],
        ]];
    }
    return self;
}

@end

#pragma mark - WifiZoneEditViewController

// Edits one wifi zone. Nothing is saved here; the completion handler gets the edited zone.
@interface WifiZoneEditViewController : UITableViewController <UITextFieldDelegate>

// The zone to edit, or nil to add a new one
@property (nonatomic, copy) NSDictionary *zone;
// Names of the other zones, which this zone's name can't duplicate
@property (nonatomic, copy) NSArray<NSString *> *otherZoneNames;
@property (nonatomic, copy) void (^completionHandler)(NSDictionary *zone);

@property (nonatomic, strong) NSMutableArray<NSString *> *values;

@end

@implementation WifiZoneEditViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = self.zone ? @"Edit Wifi Zone" : @"New Wifi Zone";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                           target:self
                                                                                           action:@selector(saveButtonTapped:)];

    [self.tableView registerClass:[WifiZoneFieldCell class] forCellReuseIdentifier:FieldCellIdentifier];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;

    if (self.zone) {
        self.values = [@[self.zone[@"name"] ?: @"", self.zone[@"latitude"] ?: @"", self.zone[@"longitude"] ?: @""] mutableCopy];
    } else {
        // Start a new zone at the current wifi network and location
        NSString *latitude = @"";
        NSString *longitude = @"";
        CLLocation *loc = [GLManager sharedManager].lastLocation;
        if (loc) {
            latitude = [NSString stringWithFormat:@"%.5f", loc.coordinate.latitude];
            longitude = [NSString stringWithFormat:@"%.5f", loc.coordinate.longitude];
        }
        self.values = [@[[GLManager currentWifiHotSpotName] ?: @"", latitude, longitude] mutableCopy];

        // The cached wifi name may be out of date, so look it up again
        __weak WifiZoneEditViewController *weakSelf = self;
        [GLManager refreshCurrentWifiHotSpotName:^(NSString *wifiName) {
            [weakSelf fillInWifiName:wifiName];
        }];
    }

    [self updateSaveButton];
}

- (void)fillInWifiName:(NSString *)wifiName {
    WifiZoneFieldCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:WifiZoneFieldName inSection:0]];
    // Don't replace a name that's being typed
    if (wifiName.length == 0 || cell.textField.isEditing) {
        return;
    }
    self.values[WifiZoneFieldName] = wifiName;
    cell.textField.text = wifiName;
    [self updateSaveButton];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return WifiZoneFieldCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WifiZoneFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:FieldCellIdentifier forIndexPath:indexPath];
    cell.textField.delegate = self;
    cell.textField.tag = indexPath.row;
    cell.textField.text = self.values[indexPath.row];
    [cell.textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];

    switch (indexPath.row) {
        case WifiZoneFieldName:
            cell.nameLabel.text = @"Wifi Name";
            cell.textField.placeholder = @"SSID";
            cell.textField.keyboardType = UIKeyboardTypeDefault;
            cell.textField.returnKeyType = UIReturnKeyNext;
            break;
        case WifiZoneFieldLatitude:
            cell.nameLabel.text = @"Latitude";
            cell.textField.placeholder = @"45.52345";
            cell.textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
            cell.textField.returnKeyType = UIReturnKeyNext;
            break;
        case WifiZoneFieldLongitude:
            cell.nameLabel.text = @"Longitude";
            cell.textField.placeholder = @"-122.68134";
            cell.textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
            cell.textField.returnKeyType = UIReturnKeyDone;
            break;
    }
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString *problem = [self validationProblem];
    if (problem) {
        return problem;
    }
    return @"While you're connected to this wifi network, your location will be reported as this latitude and longitude.";
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidChange:(UITextField *)textField {
    self.values[textField.tag] = textField.text ?: @"";
    [self updateSaveButton];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField.tag < WifiZoneFieldLongitude) {
        WifiZoneFieldCell *next = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:textField.tag + 1 inSection:0]];
        [next.textField becomeFirstResponder];
    } else {
        [textField resignFirstResponder];
    }
    return YES;
}

#pragma mark - Validation

- (NSString *)trimmedValue:(WifiZoneField)field {
    return [self.values[field] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (BOOL)isCoordinate:(NSString *)text withinLimit:(double)limit {
    NSScanner *scanner = [NSScanner scannerWithString:text];
    double value;
    return [scanner scanDouble:&value] && scanner.isAtEnd && fabs(value) <= limit;
}

// Why the zone can't be saved yet, or nil if it can
- (NSString *)validationProblem {
    NSString *name = [self trimmedValue:WifiZoneFieldName];
    if (name.length == 0) {
        return @"Enter the name of the wifi network.";
    }
    for (NSString *otherName in self.otherZoneNames) {
        if ([otherName isEqualToString:name]) {
            return @"There is already a zone for this wifi network.";
        }
    }
    if (![self isCoordinate:[self trimmedValue:WifiZoneFieldLatitude] withinLimit:90]) {
        return @"Enter a latitude between -90 and 90.";
    }
    if (![self isCoordinate:[self trimmedValue:WifiZoneFieldLongitude] withinLimit:180]) {
        return @"Enter a longitude between -180 and 180.";
    }
    return nil;
}

- (void)updateSaveButton {
    NSString *problem = [self validationProblem];
    self.navigationItem.rightBarButtonItem.enabled = (problem == nil);

    // Refresh the footer text without reloading the rows, which would end editing
    UITableViewHeaderFooterView *footer = [self.tableView footerViewForSection:0];
    if (footer) {
        [UIView performWithoutAnimation:^{
            [self.tableView beginUpdates];
            footer.textLabel.text = [self tableView:self.tableView titleForFooterInSection:0];
            [footer setNeedsLayout];
            [self.tableView endUpdates];
        }];
    }
}

#pragma mark - Actions

- (void)saveButtonTapped:(id)sender {
    [self.view endEditing:YES];
    if ([self validationProblem]) {
        return;
    }
    if (self.completionHandler) {
        self.completionHandler(@{
            @"name": [self trimmedValue:WifiZoneFieldName],
            @"latitude": [self trimmedValue:WifiZoneFieldLatitude],
            @"longitude": [self trimmedValue:WifiZoneFieldLongitude],
        });
    }
    [self.navigationController popViewControllerAnimated:YES];
}

@end

#pragma mark - WifiZoneViewController

@interface WifiZoneViewController ()

@property (nonatomic, strong) NSMutableArray *zones;

@end

@implementation WifiZoneViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Wifi Zones";

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                           target:self
                                                                                           action:@selector(addZone:)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                          target:self
                                                                                          action:@selector(doneButtonTapped:)];

    self.zones = [[GLManager sharedManager].wifiZones mutableCopy];
}

- (void)saveZones {
    [[GLManager sharedManager] saveWifiZones:[self.zones copy]];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.zones.count == 0) {
        UILabel *label = [[UILabel alloc] init];
        label.text = @"No wifi zones.\nTap + to add one.";
        label.numberOfLines = 0;
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = [UIColor secondaryLabelColor];
        label.font = [UIFont systemFontOfSize:15];
        self.tableView.backgroundView = label;
    } else {
        self.tableView.backgroundView = nil;
    }
    return self.zones.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ZoneCellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:ZoneCellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }
    NSDictionary *zone = self.zones[indexPath.row];
    cell.textLabel.text = zone[@"name"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@, %@", zone[@"latitude"], zone[@"longitude"]];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (self.zones.count == 0) {
        return nil;
    }
    return @"While you're connected to one of these wifi networks, your location will be reported as the zone's latitude and longitude instead of the phone's location.";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self showEditorForZoneAtIndex:indexPath.row];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.zones removeObjectAtIndex:indexPath.row];
        [[GLManager sharedManager] saveWifiZones:[self.zones copy]];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        if (self.zones.count == 0) {
            // Show the empty message and hide the footer
            [tableView reloadData];
        }
    }
}

#pragma mark - Actions

// Pass NSNotFound to add a new zone
- (void)showEditorForZoneAtIndex:(NSInteger)index {
    WifiZoneEditViewController *vc = [[WifiZoneEditViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];

    NSMutableArray *otherNames = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)self.zones.count; i++) {
        if (i != index) {
            [otherNames addObject:self.zones[i][@"name"]];
        }
    }
    vc.otherZoneNames = otherNames;

    if (index != NSNotFound) {
        vc.zone = self.zones[index];
    }

    __weak WifiZoneViewController *weakSelf = self;
    vc.completionHandler = ^(NSDictionary *zone) {
        if (index == NSNotFound) {
            [weakSelf.zones addObject:zone];
        } else {
            weakSelf.zones[index] = zone;
        }
        [weakSelf saveZones];
    };

    [self.navigationController pushViewController:vc animated:YES];
}

- (void)addZone:(id)sender {
    [self showEditorForZoneAtIndex:NSNotFound];
}

- (void)doneButtonTapped:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
