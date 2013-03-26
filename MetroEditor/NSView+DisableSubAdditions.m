//
//  NSView+DisableSubAdditions.m
//  MetroEditor
//
//  Created by Vasiliy Makarov on 26.03.13.
//  Copyright (c) 2013 Vasiliy Makarov. All rights reserved.
//

#import "NSView+DisableSubAdditions.h"

@implementation NSView (DisableSubAdditions)

- (void)disableSubViews
{
    [self setSubViewsEnabled:NO];
}

- (void)enableSubViews
{
    [self setSubViewsEnabled:YES];
}

- (void)setSubViewsEnabled:(BOOL)enabled
{
    NSView* currentView = NULL;
    NSEnumerator* viewEnumerator = [[self subviews] objectEnumerator];
    
    while( currentView = [viewEnumerator nextObject] )
    {
        if( [currentView respondsToSelector:@selector(setEnabled:)] )
        {
            [(NSControl*)currentView setEnabled:enabled];
        }
        [currentView setSubViewsEnabled:enabled];
        
        [currentView display];
    }
}
@end
