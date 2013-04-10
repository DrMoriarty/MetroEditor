//
//  NSOutputStream+WriteNSString.h
//  MetroEditor
//
//  Created by Vasiliy Makarov on 09.04.13.
//  Copyright (c) 2013 Vasiliy Makarov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSOutputStream (WriteNSString)

-(NSInteger)write:(NSString*)string;

@end
