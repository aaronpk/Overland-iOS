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

@interface TrackingViewController ()

@property (strong, nonatomic) NSTimer *viewRefreshTimer;

@end

@implementation TrackingViewController

NSArray *intervalMap;
NSArray *intervalMapStrings;
MKPointAnnotation *currentLocationAnnotation;
BOOL dragInProgress = NO;
BOOL mapWasDragged = NO;

- (void)registerUserActivity {
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
    
    //    [[GLManager sharedManager] accountInfo:^(NSString *name) {
    //        self.accountInfo.text = name;
    //    }];
    
    UIImage *pattern = [UIImage imageNamed:@"topobkg"];
    self.view.backgroundColor = [UIColor colorWithPatternImage:pattern];
    
    [self.tripView.layer setCornerRadius:6.0];
    [self.sendNowButton.layer setCornerRadius:4.0];
    [self.tripStartStopButton.layer setCornerRadius:4.0];
    [self setNeedsStatusBarAppearanceUpdate];
    
    // adding Shortcut Code
    // get Bundle ID and add ...
    [self registerUserActivity];
    
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didDragMap:)];
    [panRecognizer setDelegate:self];
    [self.mapView addGestureRecognizer:panRecognizer];
    
    CLLocation *lastLocation = [GLManager sharedManager].lastLocation;
    self.mapView.showsUserLocation = NO;
    self.mapView.camera.centerCoordinate = lastLocation.coordinate;
    self.mapView.camera.centerCoordinateDistance = 4000;
    self.mapView.zoomEnabled = YES;
    
    currentLocationAnnotation = [[MKPointAnnotation alloc] initWithCoordinate:lastLocation.coordinate];
    [self.mapView addAnnotation:currentLocationAnnotation];
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

    if([GLManager sharedManager].sendingInterval) {
        self.sendIntervalSlider.value = [intervalMap indexOfObject:[GLManager sharedManager].sendingInterval];
        [self updateSendIntervalLabel];
    }
    
    [self updateTripState];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(newDataReceived)
                                                 name:GLNewDataNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(newActivityReceived)
                                                 name:GLNewActivityNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sendingStarted)
                                                 name:GLSendingStartedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sendingFinished)
                                                 name:GLSendingFinishedNotification
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

- (void)viewDidDisappear:(BOOL)animated {
    [self.viewRefreshTimer invalidate];
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
    MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:@"current"];
    if(annotationView == nil) {
        annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"current"];
    } else {
        annotationView.annotation = annotation;
    }
    annotationView.image = [UIImage imageNamed:@"map-dot"];
    return annotationView;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)didDragMap:(UIGestureRecognizer *)gestureRecognizer {
//    [UIView setAnimationsEnabled:NO];
    if(gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        dragInProgress = YES;
        mapWasDragged = YES;
    }
    if(gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        dragInProgress = NO;
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

- (void)sendingStarted {
    self.sendNowButton.titleLabel.text = @"Sending...";
    self.sendNowButton.backgroundColor = [UIColor colorNamed:@"OverlandGreenSecondary"];
    self.sendNowButton.enabled = NO;
}

- (void)sendingFinished {
    self.sendNowButton.titleLabel.text = @"Send Now";
    if([[GLManager sharedManager] apiEndpointURL] == nil) {
        self.sendNowButton.backgroundColor = [UIColor colorNamed:@"OverlandGreenSecondary"];
        self.sendNowButton.enabled = NO;
    } else {
        self.sendNowButton.backgroundColor = [UIColor colorNamed:@"OverlandGreen"];
        self.sendNowButton.enabled = YES;
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

    // Pan the map if the map is not currently being dragged and the point is near the edge
    MKMapCamera *camera;
    if(outOfBounds && !dragInProgress) {
        if(outOfBounds) {
            // Reset
            mapWasDragged = NO;
        }
        camera = [[MKMapCamera alloc] init];
        camera.centerCoordinate = location.coordinate;
        camera.altitude = 4000;
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

- (void)updateTripState {
    self.currentModeImage.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@.png", [GLManager sharedManager].currentTripMode]];
    self.currentModeLabel.text = [GLManager sharedManager].currentTripMode;

    if([GLManager sharedManager].tripInProgress) {
        [self.tripStartStopButton setTitle:@"Stop" forState:UIControlStateNormal];
        self.tripStartStopButton.backgroundColor = [UIColor colorWithRed:252.f/255.f green:109.f/255.f blue:111.f/255.f alpha:1];
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
        [self.tripStartStopButton setTitle:@"Start" forState:UIControlStateNormal];
        self.tripStartStopButton.backgroundColor = [UIColor colorNamed:@"OverlandGreen"];
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
        [[GLManager sharedManager] endTrip];
        
        // If tracking was off when the trip started, turn it off now
        if([[NSUserDefaults standardUserDefaults] boolForKey:GLTripTrackingEnabledDefaultsName] == NO) {
            [[GLManager sharedManager] stopAllUpdates];
        }
    } else {
        // Keep track of whether tracking was on or off when this trip started
        [[NSUserDefaults standardUserDefaults] setBool:[GLManager sharedManager].trackingEnabled forKey:GLTripTrackingEnabledDefaultsName];

        [[GLManager sharedManager] startTrip];
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
