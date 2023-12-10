//
//  SceneDelegate.m
//  Overland
//
//  Created by Aaron Parecki on 12/10/23.
//  Copyright © 2023 Aaron Parecki. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SceneDelegate.h"
#import "GLManager.h"
#import "NSArray+map.h"

@implementation SceneDelegate

- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
}


- (void)sceneDidBecomeActive:(UIScene *)scene {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
}


- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:GLPurgeQueueOnNextLaunchDefaultsName]) {
        [[GLManager sharedManager] deleteAllData];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:GLPurgeQueueOnNextLaunchDefaultsName];
    }

}


- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.
    
    NSLog(@"Application is entering the background");
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[GLManager sharedManager] applicationDidEnterBackground];
}


- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    UIOpenURLContext *context = [URLContexts anyObject];
    NSURL *url = context.URL;
    
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
}

- (NSString *)queryValueForKey:(NSString *)key fromQueryItems:(NSArray *)queryItems
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name=%@", key];
    NSURLQueryItem *queryItem = [[queryItems filteredArrayUsingPredicate:predicate] firstObject];
    return queryItem.value;
}

#pragma mark - Quick Actions

// https://developer.apple.com/documentation/uikit/menus_and_shortcuts/add_home_screen_quick_actions?language=objc

- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
    
    [[GLManager sharedManager] applicationWillResignActive];

    UIApplication *app = UIApplication.sharedApplication;

    // Register home screen actions
    if(![GLManager sharedManager].tripInProgress) {
        NSArray *tripModes = [[GLManager sharedManager] tripModesByFrequency];
        app.shortcutItems = [tripModes mapObjectsUsingBlock:^id(id obj, NSUInteger idx) {
            UIApplicationShortcutIcon *icon = [UIApplicationShortcutIcon iconWithTemplateImageName:obj];
            return [[UIApplicationShortcutItem alloc] initWithType:obj
                                                    localizedTitle:obj
                                                 localizedSubtitle:nil
                                                              icon:icon
                                                          userInfo:nil];
        }];
    } else {
        
        UIApplicationShortcutIcon *icon = [UIApplicationShortcutIcon iconWithSystemImageName:@"stop.circle.fill"];
        UIApplicationShortcutItem *item = [[UIApplicationShortcutItem alloc] initWithType:@"stop"
                                                                           localizedTitle:@"Stop Trip"
                                                                        localizedSubtitle:nil
                                                                                     icon:icon
                                                                                 userInfo:nil];
        app.shortcutItems = @[item];
    }
}


- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    // If the app isn’t already loaded, it’s launched and passes details of the shortcut item in through the connectionOptions parameter of the scene:willConnectToSession:options: function.

    if(connectionOptions.shortcutItem != nil) {
        NSLog(@"App launched. connectionOptions = %@", connectionOptions);
        [self handleLaunchFromShortcutItem:connectionOptions.shortcutItem];
    }
}

- (void)windowScene:(UIWindowScene *)windowScene performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler {
    // If your app is already loaded, the system calls the windowScene:performActionForShortcutItem:completionHandler: function of your scene delegate.
    NSLog(@"Quick Action requested when app already loaded");
    NSLog(@"shortcutItem = %@", shortcutItem);
    
    [self handleLaunchFromShortcutItem:shortcutItem];
}

- (void)handleLaunchFromShortcutItem:(UIApplicationShortcutItem *)shortcutItem {
    if([shortcutItem.type isEqualToString:@"stop"]) {
        [[GLManager sharedManager] endTrip];
    } else {
        [GLManager sharedManager].currentTripMode = shortcutItem.type;
        [[GLManager sharedManager] startTrip];
    }
}


@end

