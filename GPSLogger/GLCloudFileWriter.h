//
//  GLCloudFileWriter.h
//  Overland
//
//  Saves location data as GeoJSON files in the app's iCloud Drive folder, as an alternative to
//  sending it to a server.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GLCloudFileMode) {
    // One file per UTC day with every point, e.g. 2026/10/2026-10-19.geojson
    GLCloudFileModeDaily,
    // One file per trip, e.g. Trips/2026-10-19T13-00-01Z.geojson. Points outside trips aren't saved.
    GLCloudFileModeTrips,
};

@interface GLCloudFileWriter : NSObject

+ (instancetype)sharedWriter;

// How to turn on iCloud Drive for the app, to show wherever it isn't available
+ (NSString *)setupInstructions;

// NO when not signed in to iCloud, or iCloud Drive is turned off for the app
+ (BOOL)isAvailable;

// Appends the features to their files. The completion is called on the main queue with nil on
// success, or a message to show if nothing could be saved.
- (void)writeFeatures:(NSArray<NSDictionary *> *)features
                 mode:(GLCloudFileMode)mode
           completion:(void (^)(NSString * _Nullable errorMessage))completion;

@end

NS_ASSUME_NONNULL_END
