//
//  NSArray+map.h
//  Overland
//
//  Created by Aaron Parecki on 12/9/23.
//  Copyright © 2023 Aaron Parecki. All rights reserved.
//
#import <Foundation/Foundation.h>

@interface NSArray (Map)

- (NSArray *)mapObjectsUsingBlock:(id (^)(id obj, NSUInteger idx))block;

@end
