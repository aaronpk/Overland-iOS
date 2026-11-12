//
//  FirstViewController.m
//  GPSLogger
//
//  Created by Aaron Parecki on 9/17/15.
//  Copyright © 2015 Esri. All rights reserved.
//  Copyright © 2017 Aaron Parecki. All rights reserved.
//

#import "TrackingViewController.h"
#import "GLManager.h"
#import "GLTripActions.h"
#import "Overland-Swift.h"

@interface TrackingViewController ()

@property (strong, nonatomic) NSTimer *viewRefreshTimer;
// Shows why the last send failed, since notifications may be turned off
@property (strong, nonatomic) UIButton *sendErrorBanner;
// Today's path and the unsent points on the map
@property (strong, nonatomic) GLMapPathOverlays *pathOverlays;
// Opens the map full screen. It sits below the send error banner while that's showing.
@property (strong, nonatomic) UIButton *expandMapButton;
@property (strong, nonatomic) NSLayoutConstraint *expandMapButtonTop;
@property (strong, nonatomic) NSLayoutConstraint *expandMapButtonBelowBanner;
// On a wide screen, like an unfolded iPhone Duo, the map fills the left half and the stats and
// controls move to the right half. The storyboard's constraints stack them for a phone.
@property (strong, nonatomic) IBOutlet UIView *statsView;
@property (strong, nonatomic) IBOutlet UIStackView *controlsStack;
@property (strong, nonatomic) IBOutletCollection(NSLayoutConstraint) NSArray *phoneLayoutConstraints;
@property (strong, nonatomic) GLSplitLayout *splitLayout;

@end

@implementation TrackingViewController

NSArray *intervalMap;
NSArray *intervalMapStrings;
MKPointAnnotation *currentLocationAnnotation;
BOOL gestureInProgress = NO;
// When the user last panned, zoomed or rotated the map
NSDate *lastMapInteraction = nil;
// How long the map waits after that before following the current location again
static const NSTimeInterval kMapFollowPause = 30;

- (void)registerUserActivity {
    // On iOS 17 and later, the app's App Intents offer this in Siri and Shortcuts instead. Shortcuts
    // people already made from this activity still work, since SceneDelegate still handles it.
    if (@available(iOS 17.0, *)) {
        return;
    }

    NSString *bundleIDStarter = [NSString stringWithFormat:@"%@.startTracking", [[NSBundle mainBundle] bundleIdentifier]];
    
    NSUserActivity *activityStart = [[NSUserActivity alloc] initWithActivityType:bundleIDStarter];
    activityStart.title = @"Start Overland Tracking";
    activityStart.userInfo = @{@"tracking" : @"on"};
    [activityStart setEligibleForSearch:true];
    if (@available(iOS 12.0, *)) {
        [activityStart setEligibleForPrediction:true];
    }
    self.view.userActivity = activityStart;
    [activityStart becomeCurrent];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    intervalMap = @[@1, @5, @10, @15, @30, @60, @120, @300, @600, @1800, @-1];
    intervalMapStrings = @[@"1s", @"5s", @"10s", @"15s", @"30s", @"1m", @"2m", @"5m", @"10m", @"30m", @"off"];

    self.view.backgroundColor = [TrackingViewController backgroundPatternColor];
    
    [self.tripView.layer setCornerRadius:6.0];
    if (@available(iOS 26.0, *)) {
        // Styled with glass in setButton:title:color:fontSize:
    } else {
        [self.sendNowButton.layer setCornerRadius:4.0];
        [self.tripStartStopButton.layer setCornerRadius:4.0];
    }
    [self setUpSendErrorBanner];
    [self setUpExpandMapButton];
    [self updateSendErrorBanner];
    [self extendMapUnderTabBar];
    [self setUpWideLayout];
    if (@available(iOS 17.0, *)) {
        [self registerForTraitChanges:@[UITraitUserInterfaceStyle.class] withAction:@selector(redrawAllViews)];
    }
    [self setNeedsStatusBarAppearanceUpdate];
    
    // adding Shortcut Code
    // get Bundle ID and add ...
    [self registerUserActivity];
    
    // Watch for the user moving the map, alongside the map's own gestures
    NSArray<UIGestureRecognizer *> *recognizers = @[
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didTouchMap:)],
        [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(didTouchMap:)],
        [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(didTouchMap:)],
    ];
    for(UIGestureRecognizer *recognizer in recognizers) {
        recognizer.delegate = self;
        [self.mapView addGestureRecognizer:recognizer];
    }
    
    CLLocation *lastLocation = [GLManager sharedManager].lastLocation;
    self.mapView.showsUserLocation = NO;
    self.mapView.camera.centerCoordinate = lastLocation.coordinate;
    self.mapView.camera.altitude = [self mapAltitude];
    self.mapView.zoomEnabled = YES;
    
    currentLocationAnnotation = [[MKPointAnnotation alloc] initWithCoordinate:lastLocation.coordinate];
    [self.mapView addAnnotation:currentLocationAnnotation];

    self.pathOverlays = [[GLMapPathOverlays alloc] initWithMapView:self.mapView];

    // Longer mode names, like Self-Driving, shrink a little to fit under the icon
    self.currentModeLabel.adjustsFontSizeToFitWidth = YES;
    self.currentModeLabel.minimumScaleFactor = 0.75;
}

// The background image has light and dark versions, but a pattern color only uses the version it
// was made with. This color uses the version for the current appearance each time it changes.
+ (UIColor *)backgroundPatternColor {
    static UIColor *light;
    static UIColor *dark;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UITraitCollection *lightTraits = [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight];
        UITraitCollection *darkTraits = [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark];
        light = [UIColor colorWithPatternImage:[UIImage imageNamed:@"topobkg" inBundle:nil compatibleWithTraitCollection:lightTraits]];
        dark = [UIColor colorWithPatternImage:[UIImage imageNamed:@"topobkg" inBundle:nil compatibleWithTraitCollection:darkTraits]];
    });
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light;
    }];
}

// The labels don't always redraw when the appearance switches between light and dark, such as when
// the app was launched in the background and is then opened. Until something else redraws them,
// they keep text colored for the old appearance, like black text on the dark background. So redraw
// everything when the appearance changes or the app comes to the foreground.
- (void)redrawAllViews {
    [self setNeedsDisplayInViewAndSubviews:self.view];
}

- (void)setNeedsDisplayInViewAndSubviews:(UIView *)view {
    [view setNeedsDisplay];
    for(UIView *subview in view.subviews) {
        [self setNeedsDisplayInViewAndSubviews:subview];
    }
}

// On iOS 26 the tab bar floats over the content, so let the map run to the bottom of the screen
// behind it. The storyboard stops the map, its content view and the scroll view at the bottom layout
// guide, above the tab bar. The map keeps its logo and Legal link above the tab bar by itself.
- (void)extendMapUnderTabBar {
    if (@available(iOS 26.0, *)) {
        UIView *contentView = self.mapView.superview;
        UIView *scrollView = contentView.superview;
        NSArray *views = @[self.mapView, contentView, scrollView];

        for(NSLayoutConstraint *constraint in self.view.constraints) {
            if([constraint.firstItem conformsToProtocol:@protocol(UILayoutSupport)]
               && constraint.firstAttribute == NSLayoutAttributeTop
               && [views containsObject:constraint.secondItem]) {
                constraint.active = NO;
            }
        }
        for(UIView *view in views) {
            [view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
        }

        // The storyboard gives the tab bar a solid background, which would hide the map behind it
        self.tabBarController.tabBar.backgroundColor = nil;
    }
}

// The stats band's background still runs to the edge of the screen, but its text and the controls
// stay out of the area on the right that the status bar and the tab bar use when unfolded
- (void)setUpWideLayout {
    UIView *contentView = self.mapView.superview;
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    NSArray *wideConstraints = @[
        [self.statsView.leadingAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.locationSpeedUnitLabel.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-8],
        [self.controlsStack.leadingAnchor constraintEqualToAnchor:contentView.centerXAnchor constant:20],
        [self.controlsStack.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-20],
        [self.mapView.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [self.mapView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [self.mapView.trailingAnchor constraintEqualToAnchor:contentView.centerXAnchor],
    ];
    self.splitLayout = [[GLSplitLayout alloc] initWithPhoneConstraints:self.phoneLayoutConstraints wideConstraints:wideConstraints];
}

// Switches between the phone and wide layouts, such as when an iPhone Duo is folded or unfolded
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self.splitLayout updateForSize:self.view.bounds.size];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)viewWillAppear:(BOOL)animated {
    [self sendingFinished];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(redrawAllViews)
                                                 name:UISceneWillEnterForegroundNotification
                                               object:nil];

    [self updateVisibleSettings];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(newDataReceived)
                                                 name:GLNewDataNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(newActivityReceived)
                                                 name:GLNewActivityNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateVisibleSettings)
                                                 name:GLSettingsChangedNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sendingStarted)
                                                 name:GLSendingStartedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sendingFinished)
                                                 name:GLSendingFinishedNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateSendErrorBanner)
                                                 name:GLWifiOnlySending.changedNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateSendErrorBanner)
                                                 name:GLReducedResourceSending.changedNotification
                                               object:nil];

    // Switching between a server and iCloud Drive changes whether sending waits for Wi-Fi
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateSendErrorBanner)
                                                 name:GLSettingsChangedNotification
                                               object:nil];

    self.viewRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                             target:self
                                                           selector:@selector(refreshView)
                                                           userInfo:nil
                                                            repeats:YES];

    NSLocale *locale = [NSLocale currentLocale];
    self.usesMetricSystem = [[locale objectForKey:NSLocaleUsesMetricSystem] boolValue];
    if(self.usesMetricSystem) {
        self.tripDistanceUnitLabel.text = @"km";
    } else {
        self.tripDistanceUnitLabel.text = @"miles";
    }
}

- (void)updateVisibleSettings {
    if([GLManager sharedManager].sendingInterval) {
        self.sendIntervalSlider.value = [intervalMap indexOfObject:[GLManager sharedManager].sendingInterval];
        [self updateSendIntervalLabel];
    }
    
    [self updateTripMode];

    [self.pathOverlays attach];
}

- (void)viewDidDisappear:(BOOL)animated {
    [self.viewRefreshTimer invalidate];
    [self.pathOverlays detach];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillDisappear:(BOOL)animated {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (void)dealloc {
    NSLog(@"view is deallocd");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - MKMapViewDelegate

- (MKAnnotationView * _Nullable)mapView:(MKMapView *)mapView viewForAnnotation:(nonnull id<MKAnnotation>)annotation {
    if(annotation != currentLocationAnnotation) {
        return nil;
    }
    MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:@"current"];
    if(annotationView == nil) {
        annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"current"];
    } else {
        annotationView.annotation = annotation;
    }
    annotationView.image = [UIImage imageNamed:@"map-dot"];
    return annotationView;
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    return [self.pathOverlays rendererFor:overlay] ?: [[MKOverlayRenderer alloc] initWithOverlay:overlay];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)didTouchMap:(UIGestureRecognizer *)gestureRecognizer {
    lastMapInteraction = [NSDate date];
    switch(gestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
            gestureInProgress = YES;
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            gestureInProgress = NO;
            break;
        default:
            break;
    }
}

#pragma mark - Tracking Interface

- (void)newDataReceived {
    self.locationAgeLabel.textColor = [UIColor whiteColor];
    [self refreshView];
    [self updateMap];
}

- (void)newActivityReceived {
    [self refreshView];
}

// On iOS 26 and later the buttons use the system's prominent glass style, tinted with their color.
// Older versions keep the flat colored style.
- (void)setButton:(UIButton *)button title:(NSString *)title color:(UIColor *)color fontSize:(CGFloat)fontSize enabled:(BOOL)enabled {
    button.enabled = enabled;
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration prominentGlassButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleLarge;
        config.title = title;
        config.baseForegroundColor = [UIColor whiteColor];
        config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> *(NSDictionary<NSAttributedStringKey, id> *attributes) {
            NSMutableDictionary *updated = [attributes mutableCopy];
            updated[NSFontAttributeName] = [UIFont systemFontOfSize:fontSize weight:UIFontWeightSemibold];
            // Set the title color here, since a button that has been disabled can otherwise keep a grey title
            updated[NSForegroundColorAttributeName] = enabled ? [UIColor whiteColor] : [UIColor colorWithWhite:1 alpha:0.6];
            return updated;
        };
        button.tintColor = color;
        button.backgroundColor = nil;
        button.configuration = config;
    } else {
        [button setTitle:title forState:UIControlStateNormal];
        button.backgroundColor = color;
    }
}

// The glass style dims a disabled button itself, so it keeps the normal color
- (UIColor *)disabledSendNowColor {
    if (@available(iOS 26.0, *)) {
        return [UIColor colorNamed:@"OverlandGreen"];
    }
    return [UIColor colorNamed:@"OverlandGreenSecondary"];
}

- (void)sendingStarted {
    [self setButton:self.sendNowButton title:@"Sending..." color:[self disabledSendNowColor] fontSize:15 enabled:NO];
}

// A banner at the top of the map, shown while the last send or save has failed, or while sending
// waits for Wi-Fi. Tapping it shows the whole message.
- (void)setUpSendErrorBanner {
    UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
    config.baseBackgroundColor = [UIColor systemRedColor];
    config.baseForegroundColor = [UIColor whiteColor];
    config.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    config.titleLineBreakMode = NSLineBreakByTruncatingTail;
    config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> *(NSDictionary<NSAttributedStringKey, id> *attributes) {
        NSMutableDictionary *updated = [attributes mutableCopy];
        updated[NSFontAttributeName] = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        return updated;
    };

    self.sendErrorBanner = [UIButton buttonWithConfiguration:config primaryAction:nil];
    self.sendErrorBanner.hidden = YES;
    self.sendErrorBanner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.sendErrorBanner addTarget:self action:@selector(sendErrorBannerWasTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.sendErrorBanner];

    [NSLayoutConstraint activateConstraints:@[
        [self.sendErrorBanner.topAnchor constraintEqualToAnchor:self.mapView.topAnchor constant:12],
        [self.sendErrorBanner.leadingAnchor constraintEqualToAnchor:self.mapView.leadingAnchor constant:12],
        [self.sendErrorBanner.trailingAnchor constraintEqualToAnchor:self.mapView.trailingAnchor constant:-12],
    ]];
}

// A round button in the top right corner of the map, which opens it full screen
- (void)setUpExpandMapButton {
    UIButtonConfiguration *config;
    if (@available(iOS 26.0, *)) {
        config = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        config = [UIButtonConfiguration filledButtonConfiguration];
        config.baseBackgroundColor = [UIColor secondarySystemBackgroundColor];
        config.baseForegroundColor = [UIColor labelColor];
    }
    config.image = [UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right"];
    config.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightMedium];
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;

    self.expandMapButton = [UIButton buttonWithConfiguration:config primaryAction:nil];
    self.expandMapButton.accessibilityLabel = @"Expand Map";
    self.expandMapButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.expandMapButton addTarget:self action:@selector(expandMapWasTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.expandMapButton];

    // The map's own compass would sit under this button, so it goes below it instead. It only
    // shows while the map is rotated.
    self.mapView.showsCompass = NO;
    MKCompassButton *compass = [MKCompassButton compassButtonWithMapView:self.mapView];
    compass.compassVisibility = MKFeatureVisibilityAdaptive;
    compass.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:compass];

    self.expandMapButtonTop = [self.expandMapButton.topAnchor constraintEqualToAnchor:self.mapView.topAnchor constant:12];
    self.expandMapButtonBelowBanner = [self.expandMapButton.topAnchor constraintEqualToAnchor:self.sendErrorBanner.bottomAnchor constant:10];
    [NSLayoutConstraint activateConstraints:@[
        self.expandMapButtonTop,
        [self.expandMapButton.trailingAnchor constraintEqualToAnchor:self.mapView.trailingAnchor constant:-12],
        [self.expandMapButton.widthAnchor constraintEqualToConstant:40],
        [self.expandMapButton.heightAnchor constraintEqualToConstant:40],
        [compass.topAnchor constraintEqualToAnchor:self.expandMapButton.bottomAnchor constant:10],
        [compass.centerXAnchor constraintEqualToAnchor:self.expandMapButton.centerXAnchor],
    ]];
}

- (void)expandMapWasTapped:(id)sender {
    GLFullMapViewController *fullMap = [[GLFullMapViewController alloc] initWithRegion:self.mapView.region];
    [self presentViewController:fullMap animated:YES completion:nil];
}

- (void)updateSendErrorBanner {
    NSString *title = [GLManager sharedManager].lastSendErrorTitle;
    BOOL waitingForWifi = [GLWifiOnlySending shared].waitingForWifi;
    BOOL slowingSends = [GLReducedResourceSending shared].slowingSends;
    self.sendErrorBanner.hidden = (title == nil && !waitingForWifi && !slowingSends);
    self.expandMapButtonTop.active = self.sendErrorBanner.hidden;
    self.expandMapButtonBelowBanner.active = !self.sendErrorBanner.hidden;
    if (title) {
        UIButtonConfiguration *config = self.sendErrorBanner.configuration;
        config.title = [NSString stringWithFormat:@"⚠️ %@. Tap for details.", title];
        config.baseBackgroundColor = [UIColor systemRedColor];
        self.sendErrorBanner.configuration = config;
        [self.view bringSubviewToFront:self.sendErrorBanner];
    } else if (waitingForWifi) {
        UIButtonConfiguration *config = self.sendErrorBanner.configuration;
        config.title = @"Waiting for Wi-Fi to send";
        config.baseBackgroundColor = [UIColor systemGrayColor];
        self.sendErrorBanner.configuration = config;
        [self.view bringSubviewToFront:self.sendErrorBanner];
    } else if (slowingSends) {
        UIButtonConfiguration *config = self.sendErrorBanner.configuration;
        config.title = @"Sending every 5 minutes to save resources";
        config.baseBackgroundColor = [UIColor systemGrayColor];
        self.sendErrorBanner.configuration = config;
        [self.view bringSubviewToFront:self.sendErrorBanner];
    }
}

- (void)sendErrorBannerWasTapped:(UIButton *)sender {
    NSString *title = [GLManager sharedManager].lastSendErrorTitle;
    NSString *message = [GLManager sharedManager].lastSendErrorMessage;
    if (title == nil && [GLWifiOnlySending shared].waitingForWifi) {
        title = @"Waiting for Wi-Fi";
        message = @"\"Send only on Wi-Fi\" is on in Settings, so points stay in the queue until the phone is on Wi-Fi. Tap Send Now to send them anyway.";
    } else if (title == nil) {
        title = @"Sending Less Often";
        message = @"iOS has asked apps to cut back on their resource use, so Overland is sending every 5 minutes instead of at the Send Interval. Points are still recorded as usual. Tap Send Now to send them right away.";
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)sendingFinished {
    [self updateSendErrorBanner];
    if(![[GLManager sharedManager] hasDestination]) {
        [self setButton:self.sendNowButton title:@"Send Now" color:[self disabledSendNowColor] fontSize:15 enabled:NO];
    } else {
        [self setButton:self.sendNowButton title:@"Send Now" color:[UIColor colorNamed:@"OverlandGreen"] fontSize:15 enabled:YES];
    }
}

- (NSString *)speedUnitText {
    if(self.usesMetricSystem) {
        return @"KM/H";
    } else {
        return @"MPH";
    }
}

- (void)updateMap {
    CLLocation *location = [GLManager sharedManager].lastLocation;

    // Determine if the current location too close to the edge of the map
    MKMapPoint point = MKMapPointForCoordinate(location.coordinate);
    UIEdgeInsets insets = UIEdgeInsetsMake(-50, -50, -50, -50);
    MKMapRect smallerRect = [self.mapView mapRectThatFits:self.mapView.visibleMapRect edgePadding:insets];
    BOOL outOfBounds = !MKMapRectContainsPoint(smallerRect, point);

    // Leave the map where the user put it for a while, so they can look around today's path
    BOOL recentlyMoved = gestureInProgress
        || (lastMapInteraction != nil && -[lastMapInteraction timeIntervalSinceNow] < kMapFollowPause);

    // Pan the map if the point is near the edge, unless the user just moved it
    MKMapCamera *camera;
    if(outOfBounds && !recentlyMoved) {
        camera = [[MKMapCamera alloc] init];
        camera.centerCoordinate = location.coordinate;
        // camera.altitude = [self mapAltitude];
        camera.altitude = self.mapView.camera.altitude;
    }

    if(camera != nil) {
        [self.mapView setCamera:camera animated:YES];
    }

    [UIView animateWithDuration:1 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        currentLocationAnnotation.coordinate = location.coordinate;
    } completion:^(BOOL finished) {
        if(!finished) {
            currentLocationAnnotation.coordinate = location.coordinate;
        }
    }];
}

- (int)mapAltitude {
    int altitude;
    if([GLTripModeStore closeZoomForModeID:[GLManager sharedManager].currentTripMode]) {
        altitude = 1000;
    } else {
        altitude = 3000;
    }
    return altitude;
}

- (void)refreshView {
    CLLocation *location = [GLManager sharedManager].lastLocation;
    self.locationLabel.text = [NSString stringWithFormat:@"%-4.4f\n%-4.4f", location.coordinate.latitude, location.coordinate.longitude];
    self.locationAltitudeLabel.text = [NSString stringWithFormat:@"+/-%dm %dm", (int)round(location.horizontalAccuracy), (int)round(location.altitude)];

    int speed;
    if(self.usesMetricSystem) {
        speed = (int)(round(location.speed*3.6));
    } else {
        speed = (int)(round(location.speed*2.23694));
    }
    if(speed < 0) speed = 0;
    self.locationSpeedLabel.text = [NSString stringWithFormat:@"%d", speed];

    int age = -(int)round([GLManager sharedManager].lastLocation.timestamp.timeIntervalSinceNow);
    if(age == 1) age = 0;
    self.locationAgeLabel.text = [TrackingViewController timeFormatted:age];
    
    NSString *motionTypeString;
    CMMotionActivity *activity = [GLManager sharedManager].lastMotion;
    if(activity.walking)
        motionTypeString = @"walking";
    else if(activity.running)
        motionTypeString = @"running";
    else if(activity.cycling)
        motionTypeString = @"cycling";
    else if(activity.automotive)
        motionTypeString = @"driving";
    else if(activity.stationary)
        motionTypeString = @"stationary";
    else {
        if([GLManager sharedManager].lastMotionString)
            motionTypeString = [GLManager sharedManager].lastMotionString;
        else
            motionTypeString = nil;
    }

    if(motionTypeString != nil) {
        self.motionTypeLabel.text = motionTypeString;
    } else {
        self.motionTypeLabel.text = @"";
    }
    
    self.locationSpeedUnitLabel.text = [self speedUnitText];

    if([GLManager sharedManager].lastSentDate) {
        age = -(int)round([GLManager sharedManager].lastSentDate.timeIntervalSinceNow);
        self.queueAgeLabel.text = [NSString stringWithFormat:@"%@", [TrackingViewController timeFormatted:age]];
    } else {
        self.queueAgeLabel.text = @"n/a";
    }
    
    [[GLManager sharedManager] numberOfLocationsInQueue:^(long num) {
        self.queueLabel.text = [NSString stringWithFormat:@"%ld", num];
    }];

    [self updateTripState];
    
}

- (IBAction)sendQueue:(id)sender {
    [[GLManager sharedManager] sendQueueNow];
}

- (void)updateSendIntervalLabel {
    NSString *val = intervalMapStrings[(int)roundf([self.sendIntervalSlider value])];
    self.sendIntervalLabel.text = val;
}

- (IBAction)sendIntervalDragged:(UISlider *)sender {
    // Snap to whole numbers
    sender.value = roundf([sender value]);
    [self updateSendIntervalLabel];
}

- (IBAction)sendIntervalChanged:(UISlider *)sender {
    sender.value = roundf([sender value]);
    NSNumber *val = intervalMap[(int)roundf([self.sendIntervalSlider value])];
    if([GLManager sharedManager].sendingInterval != val) {
        [self updateSendIntervalLabel];
        [GLManager sharedManager].sendingInterval = val;
        // A longer interval can end the "sending every 5 minutes" banner
        [self updateSendErrorBanner];
    }
}

- (IBAction)locationAgeWasTapped:(id)sender {
    self.locationAgeLabel.textColor = [UIColor colorWithRed:(210.f/255.f) green:(30.f/255.f) blue:(30.f/255.f) alpha:1];
    [[GLManager sharedManager] refreshLocation];
}

- (IBAction)locationCoordinatesWasTapped:(UILongPressGestureRecognizer *)sender {
    if(sender.state == UIGestureRecognizerStateBegan) {
        CLLocation *location = [GLManager sharedManager].lastLocation;
        NSString *string = [NSString stringWithFormat:@"%.5f,%.5f", location.coordinate.latitude, location.coordinate.longitude];

        UIPasteboard *pb = [UIPasteboard generalPasteboard];
        [pb setString:string];
        NSLog(@"Copied %@", string);

        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Copied"
                                                                       message:string
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * action) {
                                                             }];
        [alert addAction:closeAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - Trip Interface

- (double)metersToDisplayUnits:(double)meters {
    if(self.usesMetricSystem) {
        return meters * 0.001;
    } else {
        return meters * 0.000621371;
    }
}

- (void)updateTripMode {
    NSString *mode = [GLManager sharedManager].currentTripMode;
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:40];
    self.currentModeImage.image = [[GLTripModeStore imageForSymbol:[GLTripModeStore symbolForModeID:mode]] imageWithConfiguration:config];
    self.currentModeLabel.text = [GLTripModeStore nameForModeID:mode];
}

- (void)updateTripState {
    [self updateTripMode];

    if([GLManager sharedManager].tripInProgress) {
        [self setButton:self.tripStartStopButton title:@"Stop" color:[UIColor colorWithRed:252.f/255.f green:109.f/255.f blue:111.f/255.f alpha:1] fontSize:16 enabled:YES];
        self.tripDurationLabel.text = [TrackingViewController timeFormatted:[GLManager sharedManager].currentTripDuration];
        self.tripDurationUnitLabel.text = [TrackingViewController timeUnits:[GLManager sharedManager].currentTripDuration];
        double distance = [self metersToDisplayUnits:[GLManager sharedManager].currentTripDistance];
        NSString *format;
        if(distance >= 1000) {
            format = @"%0.0f";
        } else if(distance >= 100) {
            format = @"%0.1f";
        } else {
            format = @"%0.2f";
        }
        self.tripDistanceLabel.text = [NSString stringWithFormat:format, distance];
        [self updateScreenLockSetting:YES];
    } else {
        [self setButton:self.tripStartStopButton title:@"Start" color:[UIColor colorNamed:@"OverlandGreen"] fontSize:16 enabled:YES];
        self.tripDistanceLabel.text = @" ";
        self.tripDurationLabel.text = @" ";
        [self updateScreenLockSetting:NO];
    }
}

- (void)updateScreenLockSetting:(bool)val {
    if([[NSUserDefaults standardUserDefaults] boolForKey:GLScreenLockEnabledDefaultsName]) {
        [UIApplication sharedApplication].idleTimerDisabled = val;
    }
}
 
- (IBAction)tripModeWasTapped:(UILongPressGestureRecognizer *)sender {
    if(sender.state == UIGestureRecognizerStateBegan) {
        [self performSegueWithIdentifier:@"tripMode" sender:self];
    }
}

- (IBAction)tripStartStopWasTapped:(id)sender {
    if([GLManager sharedManager].tripInProgress) {
        [GLTripActions endTripRestoringTracking];
        [IntentDonations tripEnded];
    } else {
        [GLTripActions startTripWithMode:nil];
        [IntentDonations tripStartedWithMode:[GLManager sharedManager].currentTripMode];
    }
    [self updateTripState];
}

#pragma mark -

+ (NSString *)timeFormatted:(int)totalSeconds {
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60) % 60;
    int hours = totalSeconds / 3600;
    
    if(hours == 0) {
        return [NSString stringWithFormat:@"%d:%02d", minutes, seconds];
    } else {
        return [NSString stringWithFormat:@"%d:%02d", hours, minutes];
    }
}

+ (NSString *)timeUnits:(int)totalSeconds {
    int hours = totalSeconds / 3600;
    if(hours == 0) {
        return @"minutes";
    } else {
        return @"hours";
    }
}

@end
