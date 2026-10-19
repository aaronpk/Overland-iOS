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
static NSString *const SwitchCellIdentifier = @"SwitchCell";

// The fields' values are stored at these indexes, and used as the text fields' tags
typedef NS_ENUM(NSInteger, WifiZoneField) {
    WifiZoneFieldName,
    WifiZoneFieldLatitude,
    WifiZoneFieldLongitude,
    WifiZoneFieldBSSID,
};

typedef NS_ENUM(NSInteger, WifiZoneSection) {
    // Wifi name, latitude and longitude
    WifiZoneSectionLocation,
    // The "This access point only" switch, and the access point's address when it's on
    WifiZoneSectionAccessPoint,
    WifiZoneSectionCount,
};

static NSString *const AccessPointPlaceholder = @"3c:22:fb:1a:00:11";

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
// The other zones. This zone can't have the same wifi name and access point as one of them.
@property (nonatomic, copy) NSArray<NSDictionary *> *otherZones;
@property (nonatomic, copy) void (^completionHandler)(NSDictionary *zone);

@property (nonatomic, strong) NSMutableArray<NSString *> *values;
@property (nonatomic) BOOL limitToAccessPoint;
// Once set, the access point lookup no longer changes the switch
@property (nonatomic) BOOL accessPointSwitchWasChanged;
@property (nonatomic, strong) UISwitch *accessPointSwitch;

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

    self.accessPointSwitch = [[UISwitch alloc] init];
    [self.accessPointSwitch addTarget:self action:@selector(accessPointSwitchWasChanged:) forControlEvents:UIControlEventValueChanged];

    if (self.zone) {
        NSString *bssid = self.zone[@"bssid"] ?: @"";
        self.values = [@[self.zone[@"name"] ?: @"", self.zone[@"latitude"] ?: @"", self.zone[@"longitude"] ?: @"", bssid] mutableCopy];
        self.limitToAccessPoint = (bssid.length > 0);
    } else {
        // Start a new zone at the current wifi network, access point and location
        NSString *latitude = @"";
        NSString *longitude = @"";
        // Use the device's own location, not a wifi zone's location that may have replaced it
        CLLocation *loc = [GLManager sharedManager].lastDeviceLocation ?: [GLManager sharedManager].lastLocation;
        if (loc) {
            latitude = [NSString stringWithFormat:@"%.5f", loc.coordinate.latitude];
            longitude = [NSString stringWithFormat:@"%.5f", loc.coordinate.longitude];
        }
        NSString *bssid = [GLManager currentWifiBSSID] ?: @"";
        self.values = [@[[GLManager currentWifiHotSpotName] ?: @"", latitude, longitude, bssid] mutableCopy];
        self.limitToAccessPoint = (bssid.length > 0);

        // The cached wifi network may be out of date, so look it up again
        __weak WifiZoneEditViewController *weakSelf = self;
        [GLManager refreshCurrentWifiHotSpotName:^(NSString *wifiName) {
            [weakSelf fillInWifiName:wifiName bssid:[GLManager currentWifiBSSID]];
        }];
    }
    self.accessPointSwitch.on = self.limitToAccessPoint;

    [self updateSaveButton];
}

- (void)fillInWifiName:(NSString *)wifiName bssid:(NSString *)bssid {
    // Don't replace values that are being typed
    WifiZoneFieldCell *nameCell = (WifiZoneFieldCell *)[self.tableView cellForRowAtIndexPath:[self indexPathForField:WifiZoneFieldName]];
    if (wifiName.length > 0 && !nameCell.textField.isEditing) {
        self.values[WifiZoneFieldName] = wifiName;
        nameCell.textField.text = wifiName;
    }

    WifiZoneFieldCell *bssidCell = (WifiZoneFieldCell *)[self.tableView cellForRowAtIndexPath:[self indexPathForField:WifiZoneFieldBSSID]];
    if (bssid.length > 0 && !bssidCell.textField.isEditing) {
        self.values[WifiZoneFieldBSSID] = bssid;
        bssidCell.textField.text = bssid;
        if (!self.accessPointSwitchWasChanged && !self.limitToAccessPoint) {
            [self setLimitToAccessPoint:YES animated:YES];
        }
    }

    [self updateSaveButton];
}

- (NSIndexPath *)indexPathForField:(WifiZoneField)field {
    if (field == WifiZoneFieldBSSID) {
        return [NSIndexPath indexPathForRow:1 inSection:WifiZoneSectionAccessPoint];
    }
    return [NSIndexPath indexPathForRow:field inSection:WifiZoneSectionLocation];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return WifiZoneSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == WifiZoneSectionAccessPoint) {
        return self.limitToAccessPoint ? 2 : 1;
    }
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == WifiZoneSectionAccessPoint && indexPath.row == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:SwitchCellIdentifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        cell.textLabel.text = @"This access point only";
        cell.accessoryView = self.accessPointSwitch;
        return cell;
    }

    WifiZoneField field = (indexPath.section == WifiZoneSectionAccessPoint) ? WifiZoneFieldBSSID : indexPath.row;
    WifiZoneFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:FieldCellIdentifier forIndexPath:indexPath];
    cell.textField.delegate = self;
    cell.textField.tag = field;
    cell.textField.text = self.values[field];
    [cell.textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];

    switch (field) {
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
        case WifiZoneFieldBSSID:
            cell.nameLabel.text = @"Address";
            cell.textField.placeholder = AccessPointPlaceholder;
            cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
            cell.textField.returnKeyType = UIReturnKeyDone;
            break;
    }
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSInteger problemSection;
    NSString *problem = [self validationProblemInSection:&problemSection];
    if (problem && problemSection == section) {
        return problem;
    }
    if (section == WifiZoneSectionAccessPoint) {
        return @"When this is on, the zone only applies while you're connected through this access point. A zone for one access point takes priority over a zone for the whole network.";
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
        WifiZoneFieldCell *next = [self.tableView cellForRowAtIndexPath:[self indexPathForField:textField.tag + 1]];
        [next.textField becomeFirstResponder];
    } else {
        [textField resignFirstResponder];
    }
    return YES;
}

#pragma mark - Access point

- (void)accessPointSwitchWasChanged:(UISwitch *)sender {
    self.accessPointSwitchWasChanged = YES;
    if (sender.on && [self trimmedValue:WifiZoneFieldBSSID].length == 0) {
        self.values[WifiZoneFieldBSSID] = [GLManager currentWifiBSSID] ?: @"";
    }
    [self setLimitToAccessPoint:sender.on animated:YES];
}

- (void)setLimitToAccessPoint:(BOOL)limit animated:(BOOL)animated {
    if (limit == self.limitToAccessPoint) {
        return;
    }
    [self.view endEditing:YES];
    self.limitToAccessPoint = limit;
    self.accessPointSwitch.on = limit;
    NSArray *rows = @[[self indexPathForField:WifiZoneFieldBSSID]];
    UITableViewRowAnimation animation = animated ? UITableViewRowAnimationFade : UITableViewRowAnimationNone;
    [self.tableView performBatchUpdates:^{
        if (limit) {
            [self.tableView insertRowsAtIndexPaths:rows withRowAnimation:animation];
        } else {
            [self.tableView deleteRowsAtIndexPaths:rows withRowAnimation:animation];
        }
    } completion:nil];
    [self updateSaveButton];
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

// The access point this zone is limited to, normalized, or an empty string for any access point.
// Nil if the address entered isn't valid.
- (NSString *)accessPoint {
    if (!self.limitToAccessPoint) {
        return @"";
    }
    return [GLManager normalizedBSSID:[self trimmedValue:WifiZoneFieldBSSID]];
}

// Why the zone can't be saved yet, or nil if it can. The section is where to show the problem.
- (NSString *)validationProblemInSection:(NSInteger *)section {
    *section = WifiZoneSectionLocation;
    NSString *name = [self trimmedValue:WifiZoneFieldName];
    if (name.length == 0) {
        return @"Enter the name of the wifi network.";
    }
    if (![self isCoordinate:[self trimmedValue:WifiZoneFieldLatitude] withinLimit:90]) {
        return @"Enter a latitude between -90 and 90.";
    }
    if (![self isCoordinate:[self trimmedValue:WifiZoneFieldLongitude] withinLimit:180]) {
        return @"Enter a longitude between -180 and 180.";
    }

    *section = WifiZoneSectionAccessPoint;
    NSString *accessPoint = [self accessPoint];
    if (accessPoint == nil) {
        return [NSString stringWithFormat:@"Enter the access point's address, like %@.", AccessPointPlaceholder];
    }
    for (NSDictionary *other in self.otherZones) {
        NSString *otherAccessPoint = [GLManager normalizedBSSID:other[@"bssid"]] ?: @"";
        if ([other[@"name"] isEqualToString:name] && [otherAccessPoint isEqualToString:accessPoint]) {
            return accessPoint.length > 0 ? @"There is already a zone for this access point." : @"There is already a zone for this whole wifi network.";
        }
    }
    return nil;
}

- (void)updateSaveButton {
    NSInteger problemSection;
    NSString *problem = [self validationProblemInSection:&problemSection];
    self.navigationItem.rightBarButtonItem.enabled = (problem == nil);

    // Refresh the footer text without reloading the rows, which would end editing
    [UIView performWithoutAnimation:^{
        [self.tableView beginUpdates];
        for (NSInteger section = 0; section < WifiZoneSectionCount; section++) {
            UITableViewHeaderFooterView *footer = [self.tableView footerViewForSection:section];
            footer.textLabel.text = [self tableView:self.tableView titleForFooterInSection:section];
            [footer setNeedsLayout];
        }
        [self.tableView endUpdates];
    }];
}

#pragma mark - Actions

- (void)saveButtonTapped:(id)sender {
    [self.view endEditing:YES];
    NSInteger problemSection;
    if ([self validationProblemInSection:&problemSection]) {
        return;
    }
    NSMutableDictionary *zone = [@{
        @"name": [self trimmedValue:WifiZoneFieldName],
        @"latitude": [self trimmedValue:WifiZoneFieldLatitude],
        @"longitude": [self trimmedValue:WifiZoneFieldLongitude],
    } mutableCopy];
    NSString *accessPoint = [self accessPoint];
    if (accessPoint.length > 0) {
        zone[@"bssid"] = accessPoint;
    }
    if (self.completionHandler) {
        self.completionHandler([zone copy]);
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
    NSString *accessPoint = [zone[@"bssid"] length] > 0 ? zone[@"bssid"] : @"Any access point";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@, %@", accessPoint, zone[@"latitude"], zone[@"longitude"]];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (self.zones.count == 0) {
        return nil;
    }
    return @"While you're connected to one of these wifi networks, your location will be reported as the zone's latitude and longitude instead of the phone's location. A zone for one access point takes priority over a zone for the whole network.";
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

    NSMutableArray *otherZones = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)self.zones.count; i++) {
        if (i != index) {
            [otherZones addObject:self.zones[i]];
        }
    }
    vc.otherZones = otherZones;

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
