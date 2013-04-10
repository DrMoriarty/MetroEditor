//
//  MEWindow.m
//  MetroEditor
//
//  Created by Vasiliy Makarov on 20.02.13.
//  Copyright (c) 2013 Vasiliy Makarov. All rights reserved.
//

#import "MEWindow.h"
#import "NSView+DisableSubAdditions.h"

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
    _mapView.Scale = 1.f;
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

-(IBAction)saveDocument:(id)sender
{
    [_mapView.cityMap saveMap];
}

-(IBAction)scaleChanged:(id)sender
{
    CGFloat scale = [self.slider floatValue] / 100.f;
    CGFloat sc = scale / _mapView.Scale;
    NSLog(@"scale changed to %f", scale);
    //[self.mapView scaleUnitSquareToSize:NSMakeSize(sc, sc)];
    //[self display];

    NSRect visible = [self.scroll documentVisibleRect];
    NSRect newrect = NSInsetRect(visible, NSWidth(visible)*(1 - 1/sc)/2.0, NSHeight(visible)*(1 - 1/sc)/2.0);
    //NSRect frame = [self.scroll.documentView frame];
    //[self.scroll.documentView scaleUnitSquareToSize:NSMakeSize(sc, sc)];
    //[self.scroll.documentView setFrame:NSMakeRect(0, 0, frame.size.width * sc, frame.size.height * sc)];
    [self.scroll.documentView setFrameSize:NSMakeSize(_cityMap.w * scale, _cityMap.h * scale)];
    [self.scroll.documentView setBoundsSize:NSMakeSize(_cityMap.w, _cityMap.h)];
    [[self.scroll documentView] scrollPoint:newrect.origin];
    _mapView.Scale = scale;
}

-(void)scaleBy:(CGFloat)factor
{
    CGFloat scale = _mapView.Scale * factor;
    if(scale > 1) scale = 1;
    if(scale < 0.01) scale = 0.01;
    CGFloat sc = scale / _mapView.Scale;

    NSRect visible = [self.scroll documentVisibleRect];
    NSRect newrect = NSInsetRect(visible, NSWidth(visible)*(1 - 1/sc)/2.0, NSHeight(visible)*(1 - 1/sc)/2.0);
    //NSRect frame = [self.scroll.documentView frame];
    //[self.scroll.documentView scaleUnitSquareToSize:NSMakeSize(sc, sc)];
    //[self.scroll.documentView setFrame:NSMakeRect(0, 0, frame.size.width * sc, frame.size.height * sc)];
    [self.scroll.documentView setFrameSize:NSMakeSize(_cityMap.w * scale, _cityMap.h * scale)];
    [self.scroll.documentView setBoundsSize:NSMakeSize(_cityMap.w, _cityMap.h)];
    [[self.scroll documentView] scrollPoint:newrect.origin];
    _mapView.Scale = scale;
    [self.slider setFloatValue:scale*100];
}

-(IBAction)stationNameChanged:(id)sender
{
    if(_selectedStation) {
        [_mapView saveState];
        [_selectedStation setNameSource:[self.stationName stringValue]];
        [_mapView setNeedsDisplayInRect:[_mapView visibleRect]];
    }
}

-(IBAction)lineNameChanged:(id)sender
{
    if(_selectedLine) {
        [_mapView saveState];
        _selectedLine.name = [self.lineName stringValue];
    }
}

-(IBAction)lineColorChanged:(id)sender
{
    if(_selectedStation) {
        [_mapView saveState];
        [_selectedStation.line setColor:[self.lineColor color]];
        [_mapView setNeedsDisplayInRect:[_mapView visibleRect]];
    }
}

-(IBAction)splineChanged:(id)sender
{
    if(_selectedSegment) {
        [_mapView saveState];
        _selectedSegment.isSpline = self.splineSegment.state;
        [_mapView setNeedsDisplayInRect:[_mapView visibleRect]];
    }
}

-(IBAction)undo:(id)sender
{
    if([_mapView restoreState]) {
        [_mapView setNeedsDisplayInRect:[_mapView visibleRect]];
    }
}

-(void)selectStation:(Station *)st
{
    if(st != nil) {
        [self.stationBox enableSubViews];
        _selectedStation = st;
        [self.stationName setStringValue:st.nameSource];
        [_mapView setNeedsDisplayInRect:[_mapView visibleRect]];
    } else {
        [self.stationBox disableSubViews];
        _selectedStation = nil;
        [self.stationName setStringValue:@""];
        [_mapView setNeedsDisplayInRect:[_mapView visibleRect]];
    }
}

-(void)selectSegment:(Segment *)seg
{
    if(seg != nil) {
        _selectedSegment = seg;
        [self.splineSegment setState:seg.isSpline];
        [self.segmentBox enableSubViews];
    } else {
        _selectedSegment = nil;
        [self.splineSegment setState:NSOffState];
        [self.segmentBox disableSubViews];
    }
}

-(void)selectLine:(Line *)line
{
    if(line != nil) {
        _selectedLine = line;
        [self.lineName setStringValue:line.name];
        [self.lineColor setColor:line.color];
        [self.lineBox enableSubViews];
    } else {
        _selectedLine = nil;
        [self.lineName setStringValue:@""];
        [self.lineColor setColor:[NSColor blackColor]];
        [self.lineBox disableSubViews];
    }
    [self.table reloadData];
}

-(Station*)selectedStation
{
    return _selectedStation;
}

-(Segment*)selectedSegment
{
    return _selectedSegment;
}

-(Line*)selectedLine
{
    return _selectedLine;
}

-(IBAction)alignHorizontal:(id)sender
{
    [_mapView alignHorizontal];
}

-(IBAction)alignVertical:(id)sender
{
    [_mapView alignVertical];
}

-(IBAction)removeSegment:(id)sender
{
    if(_selectedSegment != nil) {
        [_mapView saveState];
        [_selectedSegment.start.segment removeObject:_selectedSegment];
        [_selectedSegment.end.backSegment removeObject:_selectedSegment];
        [self selectSegment:nil];
        [_mapView setNeedsDisplayInRect:[_mapView visibleRect]];
    }
}

-(IBAction)removeStation:(id)sender
{
    if(_selectedStation != nil) {
        [_mapView saveState];
        for (Segment *s in _selectedStation.segment) {
            [s.end.backSegment removeObject:s];
        }
        for (Segment *s in _selectedStation.backSegment) {
            [s.start.segment removeObject:s];
        }
        [_selectedStation.segment removeAllObjects];
        [_selectedStation.backSegment removeAllObjects];
        if(_selectedStation.transfer) {
            [_selectedStation.transfer removeStation:_selectedStation];
            _selectedStation.transfer = nil;
        }
        [_selectedStation.line.stations removeObject:_selectedStation];
        _selectedStation.line = nil;
        [self selectStation:nil];
        [_mapView setNeedsDisplayInRect:[_mapView visibleRect]];
    }
}

-(IBAction)removeLine:(id)sender
{
    if(_selectedLine != nil) {
        [_mapView saveState];
        for(Station *s in _selectedLine.stations) {
            if(s.transfer != nil) {
                [s.transfer removeStation:s];
            }
            [s.segment removeAllObjects];
            [s.backSegment removeAllObjects];
        }
        [_selectedLine.stations removeAllObjects];
        [_mapView.cityMap.mapLines removeObject:_selectedLine];
        [self selectLine:nil];
        [_mapView setNeedsDisplayInRect:[_mapView visibleRect]];
    }
}

-(IBAction)loadImage:(id)sender
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
                    [_mapView loadImage:[url path]];
                    break;
                }
            }
        }
    }];
}

-(IBAction)unloadImage:(id)sender
{
    [_mapView unloadImage];
}

-(void)keyDown:(NSEvent *)theEvent
{
    NSUInteger mod = theEvent.modifierFlags;
    unsigned short code = theEvent.keyCode;
    if((mod & NSCommandKeyMask)) {
        if(code == 51) {
            // delete
            [self removeStation:nil];
        } else if(code == 6) {
            // undo
            if([_mapView restoreState]) {
                [_mapView setNeedsDisplayInRect:[_mapView visibleRect]];
            }
        }
    }
}

-(void)keyUp:(NSEvent *)theEvent
{
}



#pragma mark - NSTableViewDataSource

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if(self.selectedLine != nil) {
        return [self.selectedLine.stations count];
    } else {
        return 0;
    }
}

-(id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    Station *s = [_selectedLine.stations objectAtIndex:row];
    if([tableColumn.identifier isEqualToString:@"1"]) {
        return s.name;
    } else if([tableColumn.identifier isEqualToString:@"2"]) {
        return [NSValue valueWithPoint:s.gpsCoords];
    }
    return nil;
}

-(void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    
}

#pragma mark - NSTableViewDelegate


@end
