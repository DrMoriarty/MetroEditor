//
//  NSView+DisableSubAdditions.h
//  MetroEditor
//
//  Created by Vasiliy Makarov on 26.03.13.
//  Copyright (c) 2013 Vasiliy Makarov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSView (DisableSubAdditions)

- (void)disableSubViews;
- (void)enableSubViews;
- (void)setSubViewsEnabled:(BOOL)enabled;

@end
