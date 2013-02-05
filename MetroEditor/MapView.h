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

// включает дополнительное промежуточное кеширование
//#define AGRESSIVE_CACHE
// количество слоёв кеширования
#define MAXCACHE 8

@interface MapView : NSView {

    CGRect visualFrame;
	CityMap *cityMap;
	Boolean stationSelected;
	
	NSMutableString *selectedStationName;
	NSInteger selectedStationLine;
		
	CALayer *selectedStationLayer;
    CALayer *selectedLocationLayer;
	NSString *nearestStationName;
	//
    CGFloat Scale, MaxScale, MinScale;
    CGLayerRef cacheLayer[MAXCACHE];
    int currentCacheLayer;
    // prerendered image
    VectorLayer *vectorLayer;
    VectorLayer *vectorLayer2;
    Station *nearestStation;
}

@property (assign) NSString *nearestStationName;

@property (nonatomic, retain) CALayer *selectedStationLayer;
@property (nonatomic, retain) CALayer *selectedLocationLayer;
@property (nonatomic, retain) Station *nearestStation;

//

@property Boolean stationSelected;
@property NSInteger selectedStationLine;
@property (nonatomic, retain) CityMap *cityMap;
@property (nonatomic, readonly) NSMutableString *selectedStationName;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) CGFloat Scale;
@property (nonatomic, readonly) CGFloat MaxScale;
@property (nonatomic, readonly) CGFloat MinScale;
@property (nonatomic, assign) MainViewController *vcontroller;
@property (nonatomic, readonly) NSDictionary *foundPaths;
@property (nonatomic, readonly) NSColor *backgroundColor;
@property (nonatomic, assign) DrawNameType drawName;

- (void)viewDidLoad;
// 

-(void) drawString: (NSString*) s withFont: (NSFont*) font inRect: (CGRect) contextRect ;
// find several paths and select first one
-(void) findPathFrom :(NSString*) fSt To:(NSString*) sSt FirstLine:(NSInteger) fStl LastLine:(NSInteger)sStl ;
// forget all paths
-(void) clearPath;
// number of paths which have been found
-(int)  pathsCount;
// select one of the paths (num must be less then pathsCount)
-(void) selectPath:(int)num;

// adjust map after resizing parent views
-(void)adjustMap;
// highlight the station nearest to location
-(void)setLocationAt:(Station*)st;
//highlighting station nearest to the point
- (void)highlightStationNearPoint:(CGPoint)point;

@end
