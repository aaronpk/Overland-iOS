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
    [[GLManager sharedManager] applicationDidEnterBackground];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    NSLog(@"Application is terminating");
    [[GLManager sharedManager] applicationWillTerminate];
}

// App launched by clicking a URL
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if([[url host] isEqualToString:@"setup"]) {
        NSString *endpoint = [[url query] stringByRemovingPercentEncoding];
        NSLog(@"Saving new API Endpoint: %@", endpoint);
        [[NSUserDefaults standardUserDefaults] setObject:endpoint forKey:GLAPIEndpointDefaultsName];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    return YES;
}

@end
