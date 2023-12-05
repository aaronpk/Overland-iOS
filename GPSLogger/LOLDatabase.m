//
//  LOLDatabase.m
//  loldb
//
//  Created by Andrew Pouliot on 12/12/11.
//  Copyright (c) 2011 Geoloqi, Inc. All rights reserved.
//

#import "LOLDatabase.h"

#import "sqlite3.h"

@interface _LOLDatabaseAccessor : NSObject <LOLDatabaseAccessor>
- (id)initWithDatabase:(LOLDatabase *)db collection:(NSString *)collection;
- (void)done;
@end

@implementation LOLDatabase {
@public
    sqlite3 *db;
}
@synthesize serializer;
@synthesize deserializer;

- (id)initWithPath:(NSString *)path;
{
    self = [super init];
    if (!self) return nil;
    
    int status = sqlite3_open([path UTF8String], &db);
    
    if (status != SQLITE_OK) {
        NSLog(@"Couldn't open database: %@", path);
        return nil;
    }
    
    NSString *sql = @"PRAGMA legacy_file_format = 0;";
    if (sqlite3_exec(db, [sql UTF8String], NULL, NULL, NULL) != SQLITE_OK) {
        sqlite3_close(db);
        NSLog(@"shit table failed to be created");
        return nil;
    }
    
    return self;
}

- (void)dealloc {
    sqlite3_close(db);
    
}

- (void)accessCollection:(NSString *)collection withBlock:(void (^)(id <LOLDatabaseAccessor>))block;
{
    _LOLDatabaseAccessor *a = [[_LOLDatabaseAccessor alloc] initWithDatabase:self collection:collection];
    block(a);
    [a done];
}

@end


@implementation _LOLDatabaseAccessor {
    NSString *_collection;
    LOLDatabase *_d;
    sqlite3_stmt *getByKeyStatement;
    sqlite3_stmt *setByKeyStatement;
    sqlite3_stmt *removeByKeyStatement;
    sqlite3_stmt *enumerateStatement;
    sqlite3_stmt *countStatement;
    sqlite3_stmt *deleteAllStatement;
}

- (id)initWithDatabase:(LOLDatabase *)db collection:(NSString *)collection;
{
    self = [super init];
    if (!self) return nil;
    
    _d = db;
    
    NSString *q = nil;
    int status = SQLITE_OK;
    
    q = @"BEGIN TRANSACTION;";
    if (sqlite3_exec(_d->db, [q UTF8String], NULL, NULL, NULL) != SQLITE_OK) {
        NSLog(@"Couldn't begin a transaction!");
    }
    
    q = [[NSString alloc] initWithFormat:@"CREATE TABLE IF NOT EXISTS '%@' ('key' CHAR PRIMARY KEY  NOT NULL  UNIQUE, 'data' BLOB);", collection];
    if (sqlite3_exec(_d->db, [q UTF8String], NULL, NULL, NULL) != SQLITE_OK) {
        NSLog(@"table failed to be created %s", sqlite3_errmsg(_d->db));
        return nil;
    }
    
    q = [[NSString alloc] initWithFormat:@"SELECT data FROM '%@' WHERE key = ? ;", collection];
    status = sqlite3_prepare_v2(_d->db, [q UTF8String], (int)q.length+1, &getByKeyStatement, NULL);
    if (status != SQLITE_OK) {
        NSLog(@"Error with get query! %s", sqlite3_errmsg(_d->db));
        return nil;
    }
    
    q = [[NSString alloc] initWithFormat:@"SELECT key,data FROM '%@';", collection];
    status = sqlite3_prepare_v2(_d->db, [q UTF8String], (int)q.length+1, &enumerateStatement, NULL);
    if (status != SQLITE_OK) {
        NSLog(@"Error with enumerate query! %s", sqlite3_errmsg(_d->db));
        return nil;
    }
    
    q = [[NSString alloc] initWithFormat:@"SELECT COUNT(1) FROM '%@';", collection];
    status = sqlite3_prepare_v2(_d->db, [q UTF8String], (int)q.length+1, &countStatement, NULL);
    if (status != SQLITE_OK) {
        NSLog(@"Error with count query! %s", sqlite3_errmsg(_d->db));
        return nil;
    }
    
    q = [[NSString alloc] initWithFormat:@"INSERT OR REPLACE INTO '%@' ('key', 'data') VALUES (?, ?);", collection];
    status = sqlite3_prepare_v2(_d->db, [q UTF8String], (int)q.length+1, &setByKeyStatement, NULL);
    if (status != SQLITE_OK) {
        NSLog(@"Error with set query! %s", sqlite3_errmsg(_d->db));
        return nil;
    }
    
    q = [[NSString alloc] initWithFormat:@"DELETE FROM '%@' WHERE key = ? ;", collection];
    status = sqlite3_prepare_v2(_d->db, [q UTF8String], (int)q.length+1, &removeByKeyStatement, NULL);
    if (status != SQLITE_OK) {
        NSLog(@"Error with delete query! %s", sqlite3_errmsg(_d->db));
        return nil;
    }

    q = [[NSString alloc] initWithFormat:@"DELETE FROM '%@';", collection];
    status = sqlite3_prepare_v2(_d->db, [q UTF8String], (int)q.length+1, &deleteAllStatement, NULL);
    if (status != SQLITE_OK) {
        NSLog(@"Error with delete all query! %s", sqlite3_errmsg(_d->db));
        return nil;
    }

    return self;
}

- (void)done;
{
    sqlite3_finalize(getByKeyStatement);
    sqlite3_finalize(setByKeyStatement);
    sqlite3_finalize(removeByKeyStatement);
    sqlite3_finalize(deleteAllStatement);
    sqlite3_finalize(enumerateStatement);
    sqlite3_finalize(countStatement);

    NSString *q = @"COMMIT TRANSACTION;";
    if (sqlite3_exec(_d->db, [q UTF8String], NULL, NULL, NULL) != SQLITE_OK) {
        NSLog(@"Couldn't end a transaction!");
    }
}

- (NSData *)dataForKey:(NSString *)key;
{
    sqlite3_bind_text(getByKeyStatement, 1, [key UTF8String], -1, SQLITE_TRANSIENT);
    
    NSData *fullData = nil;
    int status = sqlite3_step(getByKeyStatement);
    if (status == SQLITE_ROW) {
        const void *data = sqlite3_column_blob(getByKeyStatement, 0);
        size_t size = sqlite3_column_bytes(getByKeyStatement, 0);
        fullData = [[NSData alloc] initWithBytes:data length:size];
    } else if (status == SQLITE_ERROR) {
        NSLog(@"error getting by key: %s", sqlite3_errmsg(_d->db));
    }
    sqlite3_reset(getByKeyStatement);
    
    return fullData;
}

- (void)setData:(NSData *)data forKey:(NSString *)key;
{
    sqlite3_bind_text(setByKeyStatement, 1, [key UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_blob(setByKeyStatement, 2, data.bytes, (int)data.length, SQLITE_TRANSIENT);
    
    int status = sqlite3_step(setByKeyStatement);
    if (status != SQLITE_DONE) {
        NSLog(@"error setting by key %d: %s", status, sqlite3_errmsg(_d->db));
    }
    sqlite3_clear_bindings(setByKeyStatement);
    sqlite3_reset(setByKeyStatement);
}

- (NSDictionary *)dictionaryForKey:(NSString *)key;
{
    NSData *data = [self dataForKey:key];
    return data ? _d.deserializer(data) : nil;
}

- (void)setDictionary:(NSDictionary *)dict forKey:(NSString *)key;
{
    if (dict) {
        NSData *data = _d.serializer(dict);
        if (data) {
            [self setData:data forKey:key];
            return;
        }
    }
    [self setData:nil forKey:key];
}

- (void)removeDictionaryForKey:(NSString *)key;
{
    sqlite3_bind_text(removeByKeyStatement, 1, [key UTF8String], -1, SQLITE_TRANSIENT);
    
    int status = sqlite3_step(removeByKeyStatement);
    if (status != SQLITE_DONE) {
        //yay!
        NSLog(@"Error removing dictionary for key %@ : %s", key, sqlite3_errmsg(_d->db));
    }
    
    sqlite3_reset(removeByKeyStatement);
    
}

- (void)deleteAllData
{
    int status = sqlite3_step(deleteAllStatement);
    if (status != SQLITE_DONE) {
        NSLog(@"Error deleting all data : %s", sqlite3_errmsg(_d->db));
    }
    
    sqlite3_reset(deleteAllStatement);
}

- (void)enumerateKeysAndObjectsUsingBlock:(BOOL(^)(NSString *key, NSDictionary *object))block;
{
    if (!block) return;
    NSData *fullData = nil;
    int status = sqlite3_step(enumerateStatement);
    
    BOOL stop = NO;
    while (!stop && status == SQLITE_ROW) {
        NSString *key = [[NSString alloc] initWithUTF8String:(const char *)sqlite3_column_text(enumerateStatement, 0)];
        
        const void *dataPtr = sqlite3_column_blob(enumerateStatement, 1);
        size_t size = sqlite3_column_bytes(enumerateStatement, 1);
        fullData = [[NSData alloc] initWithBytes:dataPtr length:size];
        
        NSDictionary *object = fullData ? _d.deserializer(fullData) : nil;	
        
        stop = block(key, object);
        status = sqlite3_step(enumerateStatement);
    }
    sqlite3_reset(enumerateStatement);
}

- (void)countObjectsUsingBlock:(void (^)(long num))block {
    if (!block) return;
    
    long count = 0;
    while( sqlite3_step(countStatement) == SQLITE_ROW ) {
        count = (long)sqlite3_column_int(countStatement, 0);
    }
    
    block(count);
}

@end


