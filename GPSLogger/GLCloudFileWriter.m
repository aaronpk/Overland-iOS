//
//  GLCloudFileWriter.m
//  Overland
//
//  Each file is a GeoJSON FeatureCollection. To add features without reading the existing ones
//  back in, the file always ends with a known trailer, which is overwritten by the new features
//  followed by the trailer again. The file is valid GeoJSON after every write.
//

#import "GLCloudFileWriter.h"

static NSString *const GLCloudContainerIdentifier = @"iCloud.com.aaronpk.overland";
static NSString *const GLFeatureCollectionHeader = @"{\"type\":\"FeatureCollection\",\"features\":[\n";
static NSString *const GLFeatureCollectionTrailer = @"\n]}\n";

@implementation GLCloudFileWriter {
    dispatch_queue_t _queue;
    NSURL *_documentsURL;
    NSDateFormatter *_dailyPathFormatter;
    NSISO8601DateFormatter *_timestampParser;
}

+ (instancetype)sharedWriter {
    static GLCloudFileWriter *writer;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        writer = [[GLCloudFileWriter alloc] init];
    });
    return writer;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.aaronpk.overland.cloudfiles", DISPATCH_QUEUE_SERIAL);

        _dailyPathFormatter = [[NSDateFormatter alloc] init];
        _dailyPathFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        _dailyPathFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        _dailyPathFormatter.dateFormat = @"yyyy/MM/yyyy-MM-dd'.geojson'";

        _timestampParser = [[NSISO8601DateFormatter alloc] init];
    }
    return self;
}

- (void)writeFeatures:(NSArray<NSDictionary *> *)features mode:(GLCloudFileMode)mode completion:(void (^)(NSString *))completion {
    dispatch_async(_queue, ^{
        NSString *errorMessage = [self saveFeatures:features mode:mode];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(errorMessage);
        });
    });
}

#pragma mark - Private, on the writer's queue

// The Documents folder of the app's iCloud container, which appears in iCloud Drive as "Overland".
// Looking up the container can block, so this runs on the writer's queue.
- (NSURL *)documentsURL {
    if (_documentsURL == nil) {
        NSURL *container = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:GLCloudContainerIdentifier];
        if (container) {
            _documentsURL = [container URLByAppendingPathComponent:@"Documents" isDirectory:YES];
        }
    }
    return _documentsURL;
}

- (NSString *)saveFeatures:(NSArray<NSDictionary *> *)features mode:(GLCloudFileMode)mode {
    NSURL *documents = [self documentsURL];
    if (documents == nil) {
        return @"iCloud Drive isn't available. Sign in to iCloud and turn on iCloud Drive for Overland.";
    }

    // Group the features by file, keeping the order they were recorded in
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSMutableArray *> *featuresByPath = [NSMutableDictionary dictionary];
    for (NSDictionary *feature in features) {
        NSString *path = [self relativePathForFeature:feature mode:mode];
        if (path == nil) {
            // Not saved in this mode, such as a point outside a trip
            continue;
        }
        if (featuresByPath[path] == nil) {
            featuresByPath[path] = [NSMutableArray array];
            [paths addObject:path];
        }
        [featuresByPath[path] addObject:feature];
    }

    for (NSString *path in paths) {
        NSString *errorMessage = [self appendFeatures:featuresByPath[path] toURL:[documents URLByAppendingPathComponent:path]];
        if (errorMessage) {
            return errorMessage;
        }
    }
    return nil;
}

// The file a feature belongs in, relative to the Documents folder, or nil if it isn't saved
- (NSString *)relativePathForFeature:(NSDictionary *)feature mode:(GLCloudFileMode)mode {
    NSDictionary *properties = feature[@"properties"];
    if (![properties isKindOfClass:[NSDictionary class]]) {
        properties = nil;
    }

    if (mode == GLCloudFileModeTrips) {
        // Points in a trip have trip_id, and the record written when the trip ends has the same start
        id tripStart = [properties[@"type"] isEqual:@"trip"] ? properties[@"start"] : properties[@"trip_id"];
        if (![tripStart isKindOfClass:[NSString class]] || [tripStart length] == 0) {
            return nil;
        }
        // Colons aren't allowed in file names
        NSString *name = [[tripStart stringByReplacingOccurrencesOfString:@":" withString:@"-"]
                          stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
        return [NSString stringWithFormat:@"Trips/%@.geojson", name];
    }

    NSDate *date = nil;
    if ([properties[@"timestamp"] isKindOfClass:[NSString class]]) {
        date = [_timestampParser dateFromString:properties[@"timestamp"]];
    }
    return [_dailyPathFormatter stringFromDate:date ?: [NSDate date]];
}

- (NSString *)appendFeatures:(NSArray<NSDictionary *> *)features toURL:(NSURL *)url {
    NSData *separator = [@",\n" dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *body = [NSMutableData data];
    NSMutableArray *validFeatures = [NSMutableArray array];
    for (NSDictionary *feature in features) {
        if (![NSJSONSerialization isValidJSONObject:feature]) {
            continue;
        }
        if (body.length > 0) {
            [body appendData:separator];
        }
        [body appendData:[NSJSONSerialization dataWithJSONObject:feature options:0 error:nil]];
        [validFeatures addObject:feature];
    }
    if (body.length == 0) {
        return nil;
    }

    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:url.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&error]) {
        return error.localizedDescription;
    }

    // Coordinate with iCloud, which may be syncing the file
    __block NSString *errorMessage = nil;
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    [coordinator coordinateWritingItemAtURL:url options:NSFileCoordinatorWritingForMerging error:&error byAccessor:^(NSURL *writeURL) {
        errorMessage = [self appendBody:body features:validFeatures toFileAtURL:writeURL];
    }];
    if (error) {
        return error.localizedDescription;
    }
    return errorMessage;
}

- (NSString *)appendBody:(NSData *)body features:(NSArray *)features toFileAtURL:(NSURL *)url {
    NSData *header = [GLFeatureCollectionHeader dataUsingEncoding:NSUTF8StringEncoding];
    NSData *trailer = [GLFeatureCollectionTrailer dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;

    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        NSMutableData *document = [NSMutableData dataWithData:header];
        [document appendData:body];
        [document appendData:trailer];
        return [document writeToURL:url options:NSDataWritingAtomic error:&error] ? nil : error.localizedDescription;
    }

    NSFileHandle *handle = [NSFileHandle fileHandleForUpdatingURL:url error:&error];
    if (handle == nil) {
        return error.localizedDescription;
    }

    unsigned long long size = 0;
    BOOL endsWithTrailer = NO;
    if ([handle seekToEndReturningOffset:&size error:&error] && size >= header.length + trailer.length) {
        [handle seekToOffset:size - trailer.length error:nil];
        endsWithTrailer = [[handle readDataUpToLength:trailer.length error:nil] isEqualToData:trailer];
    }

    if (endsWithTrailer) {
        // Overwrite the trailer with the new features and the trailer again, so the file is only
        // ever extended. A collection with no features yet doesn't need a separator.
        NSMutableData *tail = [NSMutableData data];
        if (size > header.length + trailer.length) {
            [tail appendData:[@",\n" dataUsingEncoding:NSUTF8StringEncoding]];
        }
        [tail appendData:body];
        [tail appendData:trailer];
        BOOL written = [handle seekToOffset:size - trailer.length error:&error] && [handle writeData:tail error:&error];
        [handle closeAndReturnError:nil];
        return written ? nil : error.localizedDescription;
    }
    [handle closeAndReturnError:nil];

    // The file was changed outside the app, so read it, add the features, and write it again
    return [self rewriteFileAtURL:url addingFeatures:features];
}

- (NSString *)rewriteFileAtURL:(NSURL *)url addingFeatures:(NSArray *)features {
    NSMutableArray *allFeatures = [NSMutableArray array];
    NSData *existing = [NSData dataWithContentsOfURL:url];
    NSDictionary *collection = existing ? [NSJSONSerialization JSONObjectWithData:existing options:0 error:nil] : nil;
    if ([collection isKindOfClass:[NSDictionary class]] && [collection[@"features"] isKindOfClass:[NSArray class]]) {
        [allFeatures addObjectsFromArray:collection[@"features"]];
    } else {
        // Keep a file that can't be read, rather than overwriting it, and start a new one
        NSString *name = [NSString stringWithFormat:@"%@ (unreadable %.0f).geojson",
                          url.URLByDeletingPathExtension.lastPathComponent, [[NSDate date] timeIntervalSince1970]];
        NSError *error = nil;
        if (![[NSFileManager defaultManager] moveItemAtURL:url toURL:[url.URLByDeletingLastPathComponent URLByAppendingPathComponent:name] error:&error]) {
            return error.localizedDescription;
        }
    }
    [allFeatures addObjectsFromArray:features];

    NSMutableData *document = [NSMutableData dataWithData:[GLFeatureCollectionHeader dataUsingEncoding:NSUTF8StringEncoding]];
    NSData *separator = [@",\n" dataUsingEncoding:NSUTF8StringEncoding];
    BOOL first = YES;
    for (id feature in allFeatures) {
        if (![NSJSONSerialization isValidJSONObject:feature]) {
            continue;
        }
        if (!first) {
            [document appendData:separator];
        }
        [document appendData:[NSJSONSerialization dataWithJSONObject:feature options:0 error:nil]];
        first = NO;
    }
    [document appendData:[GLFeatureCollectionTrailer dataUsingEncoding:NSUTF8StringEncoding]];

    NSError *error = nil;
    return [document writeToURL:url options:NSDataWritingAtomic error:&error] ? nil : error.localizedDescription;
}

@end
