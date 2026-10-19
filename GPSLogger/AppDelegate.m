//
//  AppDelegate.m
//  GPSLogger
//
//  Created by Aaron Parecki on 9/17/15.
//  Copyright © 2015 Esri. All rights reserved.
//

#import "AppDelegate.h"
#import "GLManager.h"
#import "NSArray+map.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

#pragma mark - UISceneSession lifecycle

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}

- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}

#pragma mark -

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    NSLog(@"Application launched with options: %@", launchOptions);
    
    [GLManager sharedManager];
    
    // This key is deprecated in iOS 26, but it's still the only way to tell that the app was
    // relaunched for a location event. It's only used for this tracking stat.
    if([launchOptions objectForKey:UIApplicationLaunchOptionsLocationKey]) {
        [[GLManager sharedManager] logAction:@"application_launched_with_location"];
    }

    return YES;
}

// The app uses scenes, so the foreground and background lifecycle events go to SceneDelegate

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    NSLog(@"Application is terminating");
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[GLManager sharedManager] applicationWillTerminate];
}

@end
