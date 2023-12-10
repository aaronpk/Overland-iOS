//
//  AppDelegate.m
//  GPSLogger
//
//  Created by Aaron Parecki on 9/17/15.
//  Copyright © 2015 Esri. All rights reserved.
//

#import "AppDelegate.h"
#import "GLManager.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    NSLog(@"Application launched with options: %@", launchOptions);
    
    [GLManager sharedManager];
    
    if([launchOptions objectForKey:UIApplicationLaunchOptionsLocationKey]) {
        [[GLManager sharedManager] logAction:@"application_launched_with_location"];
    }

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    [[GLManager sharedManager] applicationWillResignActive];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    NSLog(@"Application is entering the background");
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[GLManager sharedManager] applicationDidEnterBackground];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    if([[NSUserDefaults standardUserDefaults] boolForKey:GLPurgeQueueOnNextLaunchDefaultsName]) {
        [[GLManager sharedManager] deleteAllData];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:GLPurgeQueueOnNextLaunchDefaultsName];
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    NSLog(@"Application is terminating");
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[GLManager sharedManager] applicationWillTerminate];
}

// App launched by clicking a URL
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if([[url host] isEqualToString:@"setup"]) {
        NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        NSArray *queryItems  = urlComponents.queryItems;
        NSString *endpoint = [self queryValueForKey:@"url" fromQueryItems:queryItems];
        NSString *token    = [self queryValueForKey:@"token" fromQueryItems:queryItems];
        NSString *deviceId = [self queryValueForKey:@"device_id" fromQueryItems:queryItems];
        NSString *uniqueId = [self queryValueForKey:@"unique_id" fromQueryItems:queryItems];
        NSLog(@"Saving new config endpoint=%@ token=%@ device_id=%@ unique_id=%@", endpoint, token, deviceId, uniqueId);
        [[GLManager sharedManager] saveNewDeviceId:deviceId];
        [[GLManager sharedManager] saveNewAPIEndpoint:endpoint andAccessToken:token];
        [[NSUserDefaults standardUserDefaults] setBool:[uniqueId isEqualToString:@"yes"] forKey:GLIncludeUniqueIdDefaultsName];
    }
    
    return YES;
}

- (NSString *)queryValueForKey:(NSString *)key fromQueryItems:(NSArray *)queryItems
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name=%@", key];
    NSURLQueryItem *queryItem = [[queryItems filteredArrayUsingPredicate:predicate] firstObject];
    return queryItem.value;
}
           
- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler
{
    // get Bundle ID and add ...
    NSString *bundleIDStarter = [NSString stringWithFormat:@"%@.startTracking", [[NSBundle mainBundle] bundleIdentifier]];
    
    // Check to make sure it's the correct activity type
    if ([userActivity.activityType isEqualToString:bundleIDStarter])
    {
        NSLog(@"startTracking - called from shortcut");
        
        [[GLManager sharedManager] startAllUpdates];
        
        return YES;
    }
    
    return NO;
}

@end
