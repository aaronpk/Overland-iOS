//
//  OLAppDelegate.m
//  OfflineLogger
//
//  Created by Aaron Parecki on 10/21/13.
//  Copyright (c) 2013 Esri. All rights reserved.
//

#import "OLAppDelegate.h"
#import "OLManager.h"

@implementation OLAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [OLManager sharedManager];
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    NSLog(@"applicationDidEnterBackground");
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

// this should probably be put somewhere else, like a category or something
- (NSDictionary *)paramsFromURL:(NSURL *)url
{
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:20];
    NSString *queryString = [[url query] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSArray *paramsStrings = [queryString componentsSeparatedByString:@"&"]; // note this means URLs with un-encoded & will be broken
    for (NSString *param in paramsStrings) {
        NSArray *kvp = [param componentsSeparatedByString:@"="];
        NSString *key = [kvp objectAtIndex:0];
        NSString *value = [kvp objectAtIndex:1];
        [params setObject:value forKey:key];
    }
    return [NSDictionary dictionaryWithDictionary:params];
}

// App launched by clicking a URL
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    // set the api endpoint by opening a url in safar with the format:
    // olog://setup?hmac_key=super_secret_key&url=http://my.api.endpoint/for/locations
    if([[url host] isEqualToString:@"setup"]) {
        // grab the query string components
        NSDictionary *params = [self paramsFromURL:url];
        NSString *endpoint = [params objectForKey:@"url"];
        NSString *hmacKey = [params objectForKey:@"hmac_key"];
      
        NSLog(@"Saving new API Endpoint: %@", endpoint);
        NSLog(@"Saving new HMAC key: %@", hmacKey);
        [[NSUserDefaults standardUserDefaults] setObject:endpoint forKey:OLAPIEndpointDefaultsName];
        [[NSUserDefaults standardUserDefaults] setObject:hmacKey forKey:OLAPIHMACSignatureKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    NSLog(@"applicationWillTerminate");

    UILocalNotification* localNotification = [[UILocalNotification alloc] init];
    localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:1];
    localNotification.alertBody = @"The app quit!";
    localNotification.timeZone = [NSTimeZone defaultTimeZone];
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
}

@end
