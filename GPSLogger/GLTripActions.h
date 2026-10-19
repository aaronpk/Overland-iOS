//
//  GLTripActions.h
//  Overland
//
//  Starting and ending a trip the way the Tracker screen does, for the other places a trip can be
//  started or ended from: Home Screen quick actions, Shortcuts, widgets and controls.
//  This only uses GLManager's public API.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GLTripActions : NSObject

// Starts a trip in the given mode, or the current mode if nil. Does nothing if a trip is running.
// Remembers whether tracking was on, so ending the trip can turn it back off.
+ (void)startTripWithMode:(nullable NSString *)mode;

// Ends the trip, and turns tracking off if it was off when the trip started. Does nothing if no
// trip is running.
+ (void)endTripRestoringTracking;

@end

NS_ASSUME_NONNULL_END
