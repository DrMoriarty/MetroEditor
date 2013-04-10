//
//  NSOutputStream+WriteNSString.m
//  MetroEditor
//
//  Created by Vasiliy Makarov on 09.04.13.
//  Copyright (c) 2013 Vasiliy Makarov. All rights reserved.
//

#import "NSOutputStream+WriteNSString.h"

@implementation NSOutputStream (WriteNSString)

-(NSInteger)write:(NSString*)string
{
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    const uint8_t *d = [data bytes];
    return [self write:d maxLength:[data length]];
}

@end
