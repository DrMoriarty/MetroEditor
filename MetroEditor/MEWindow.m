//
//  MEWindow.m
//  MetroEditor
//
//  Created by Vasiliy Makarov on 20.02.13.
//  Copyright (c) 2013 Vasiliy Makarov. All rights reserved.
//

#import "MEWindow.h"

@implementation MEWindow

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if((self = [super initWithCoder:aDecoder])) {
    }
    return self;
}

-(id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag screen:(NSScreen *)screen
{
    if((self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag screen:screen])) {
    }
    return self;
}

-(id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
    if((self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag])) {
    }
    return self;
}

-(void) loadMap:(NSString*)mapFile
{
    mapFile = [mapFile stringByDeletingLastPathComponent];
    NSLog(@"map file: %@", mapFile);
    self.cityMap = [[CityMap alloc] init];
    [self.cityMap loadMap:mapFile];
    [self.mapView setCityMap:self.cityMap];
    mapScale = 1.f;
}

-(IBAction)openDocument:(id)sender
{
    // Create the File Open Dialog class.
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    // Enable the selection of files in the dialog.
    [openDlg setCanChooseFiles:YES];
    // Multiple files not allowed
    [openDlg setAllowsMultipleSelection:NO];
    // Can't select a directory
    [openDlg setCanChooseDirectories:NO];
    // Display the dialog. If the OK button was pressed,
    // process the files.
    [openDlg beginSheetModalForWindow:self completionHandler:^(NSInteger res) {
        if ( res == NSOKButton ) {
            // Get an array containing the full filenames of all
            // files and directories selected.
            NSArray* urls = [openDlg URLs];
            // Loop through all the files and process them.
            for(int i = 0; i < [urls count]; i++) {
                NSURL* url = [urls objectAtIndex:i];
                if([url isFileURL]) {
                    [self loadMap:[url path]];
                    break;
                }
            }
        }
    }];
}

-(IBAction)scaleChanged:(id)sender
{
    CGFloat scale = [self.slider floatValue] / 100.f;
    CGFloat sc = scale / mapScale;
    NSLog(@"scale changed to %f", sc);
    //[self.mapView scaleUnitSquareToSize:NSMakeSize(sc, sc)];
    //[self display];

    NSRect visible = [self.scroll documentVisibleRect];
    NSRect newrect = NSInsetRect(visible, NSWidth(visible)*(1 - 1/sc)/2.0, NSHeight(visible)*(1 - 1/sc)/2.0);
    NSRect frame = [self.scroll.documentView frame];
    [self.scroll.documentView scaleUnitSquareToSize:NSMakeSize(sc, sc)];
    [self.scroll.documentView setFrame:NSMakeRect(0, 0, frame.size.width * sc, frame.size.height * sc)];
    [[self.scroll documentView] scrollPoint:newrect.origin];
    mapScale = scale;
}

-(IBAction)stationNameChanged:(id)sender
{
    if(selectedStation) {
        [selectedStation setNameSource:[_textField stringValue]];
        [_mapView setNeedsDisplayInRect:[_mapView visibleRect]];
    }
}

-(IBAction)lineColorChanged:(id)sender
{
    if(selectedStation) {
        [selectedStation.line setColor:[_colorWell color]];
        [_mapView setNeedsDisplayInRect:[_mapView visibleRect]];
    }
}

-(void)selectStation:(Station *)st
{
    [_textField setStringValue:st.nameSource];
    [_colorWell setColor:st.line.color];
    selectedStation = st;
    [_mapView setNeedsDisplayInRect:[_mapView visibleRect]];
}

@end
