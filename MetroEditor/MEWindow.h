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

@interface MEWindow : NSWindow {
    __weak Station *_selectedStation;
}

@property (nonatomic, strong) CityMap* cityMap;
@property (nonatomic, strong) IBOutlet MapView* mapView;
@property (nonatomic, strong) IBOutlet NSScrollView* scroll;
@property (nonatomic, strong) IBOutlet NSSlider* slider;
@property (nonatomic, strong) IBOutlet NSTextField *textField;
@property (nonatomic, strong) IBOutlet NSColorWell *colorWell;

- (IBAction)openDocument:(id)sender;
- (IBAction)scaleChanged:(id)sender;
-(void)scaleBy:(CGFloat)factor;

-(void)selectStation:(Station*)st;
-(Station*)selectedStation;
@end
