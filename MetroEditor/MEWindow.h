//
//  MEWindow.h
//  MetroEditor
//
//  Created by Vasiliy Makarov on 20.02.13.
//  Copyright (c) 2013 Vasiliy Makarov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MapView.h"
#import "CityMap.h"

@interface MEWindow : NSWindow <NSTableViewDelegate, NSTableViewDataSource> {
    __weak Station *_selectedStation;
    __weak Segment *_selectedSegment;
    __weak Line *_selectedLine;
}

@property (nonatomic, strong) CityMap* cityMap;
@property (nonatomic, strong) IBOutlet MapView* mapView;
@property (nonatomic, strong) IBOutlet NSScrollView* scroll;
@property (nonatomic, strong) IBOutlet NSSlider* slider;
@property (nonatomic, strong) IBOutlet NSTextField *stationName;
@property (nonatomic, strong) IBOutlet NSTextField *lineName;
@property (nonatomic, strong) IBOutlet NSColorWell *lineColor;
@property (nonatomic, strong) IBOutlet NSButton *splineSegment;
@property (nonatomic, strong) IBOutlet NSBox *segmentBox;
@property (nonatomic, strong) IBOutlet NSBox *stationBox;
@property (nonatomic, strong) IBOutlet NSBox *lineBox;
@property (nonatomic, strong) IBOutlet NSTableView *table;

- (IBAction)openDocument:(id)sender;
- (IBAction)scaleChanged:(id)sender;
-(IBAction)stationNameChanged:(id)sender;
-(IBAction)lineNameChanged:(id)sender;
-(IBAction)lineColorChanged:(id)sender;
-(IBAction)splineChanged:(id)sender;
-(IBAction)alignHorizontal:(id)sender;
-(IBAction)alignVertical:(id)sender;
-(IBAction)removeSegment:(id)sender;
-(IBAction)removeStation:(id)sender;
-(IBAction)removeLine:(id)sender;

-(void)scaleBy:(CGFloat)factor;

-(void)selectStation:(Station*)st;
-(void)selectSegment:(Segment*)seg;
-(void)selectLine:(Line*)line;
-(Station*)selectedStation;
-(Segment*)selectedSegment;
-(Line*)selectedLine;
@end
