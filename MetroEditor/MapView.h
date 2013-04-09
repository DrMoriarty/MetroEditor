//
//  MapView.h
//  tube
//
//  Created by Alex 1 on 9/24/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CityMap.h"
//#import "SelectedPathMap.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreLocation/CoreLocation.h>
#import "VectorLayer.h"
//#import "ActiveView.h"

extern int const imagesCount;

@class MainViewController;

enum {SELECT_NONE=0, SELECT_SINGLE, SELECT_MULTI};

@interface MapView : NSView {

    CGRect visualFrame;
	CityMap *cityMap;
	Boolean stationSelected;
	
	NSMutableString *selectedStationName;
	NSInteger selectedStationLine;
		
	CALayer *selectedStationLayer;
    CALayer *selectedLocationLayer;
	__weak NSString *nearestStationName;
	//
    CGFloat Scale, MaxScale, MinScale;
    // prerendered image
    VectorLayer *vectorLayer;
    VectorLayer *vectorLayer2;
    Station *nearestStation;
    NSMutableSet *selectedStations;
    int makeSelection;
    Station *currentStation;
    Segment *currentSegment;
    int currentSegmentPoint;
    CGRect multiSelectRect;
    BOOL selectText;
    NSImageView *sourceImage;
    
    NSMutableArray *undo;
}

@property (weak) NSString *nearestStationName;

@property (nonatomic, retain) CALayer *selectedStationLayer;
@property (nonatomic, retain) CALayer *selectedLocationLayer;
@property (nonatomic, retain) Station *nearestStation;

//

@property Boolean stationSelected;
@property NSInteger selectedStationLine;
@property (nonatomic, retain) CityMap *cityMap;
@property (nonatomic, readonly) NSMutableString *selectedStationName;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, assign) CGFloat Scale;
@property (nonatomic, readonly) CGFloat MaxScale;
@property (nonatomic, readonly) CGFloat MinScale;
@property (nonatomic, assign) MainViewController *vcontroller;
@property (nonatomic, readonly) NSDictionary *foundPaths;
@property (nonatomic, readonly) NSColor *backgroundColor;
@property (nonatomic, assign) DrawNameType drawName;

- (void)viewDidLoad;
// 

-(void) drawString: (NSString*) s withFont: (NSFont*) font inRect: (CGRect) contextRect ;

// adjust map after resizing parent views
-(void)adjustMap;
-(void)alignVertical;
-(void)alignHorizontal;

-(void)saveState;
-(BOOL)restoreState;

-(void)loadImage:(NSString*)imageFile;
-(void)unloadImage;

@end
