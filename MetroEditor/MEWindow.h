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
    CGFloat mapScale;
}

@property (nonatomic, strong) CityMap* cityMap;
@property (nonatomic, strong) IBOutlet MapView* mapView;
@property (nonatomic, strong) IBOutlet NSScrollView* scroll;
@property (nonatomic, strong) IBOutlet NSSlider* slider;

- (IBAction)openDocument:(id)sender;
- (IBAction)scaleChanged:(id)sender;

@end
