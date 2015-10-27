//
//  PebbleManager.h
//  GPSLogger
//
//  Created by Aaron Parecki on 10/27/15.
//  Copyright © 2015 Aaron Parecki. All rights reserved.
//

#import <Foundation/Foundation.h>
@import PebbleKit;

@interface PebbleManager : NSObject <PBPebbleCentralDelegate>

+ (PebbleManager *)sharedManager;

- (void)startWatchSession;
- (void)stopWatchSession;

- (void)refreshWatchface;
- (void)updateTripInfoWithTime:(NSTimeInterval)time distance:(double)distance speed:(double)speed;

@end
