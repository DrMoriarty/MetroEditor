//
//  MapView.m
//  tube
//
//  Created by Alex 1 on 9/24/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MapView.h"
#import "CityMap.h"
#import <Foundation/Foundation.h>
//#import "tubeAppDelegate.h"
#import "MyTiledLayer.h"
//#import "Schedule.h"
//#import "ManagedObjects.h"

@implementation MapView
@synthesize cityMap;
@synthesize selectedStationName;
@synthesize stationSelected;
@synthesize selectedStationLine;
@synthesize selectedStationLayer;
@synthesize selectedLocationLayer;
@synthesize Scale;
@synthesize MaxScale;
@synthesize MinScale;
@synthesize vcontroller;
@synthesize foundPaths;
@synthesize nearestStation;
@synthesize nearestStationName = nearestStationName;

+ (Class)layerClass
{
    return [MyTiledLayer class];
}

-(void) setTransform:(CGAffineTransform)transform
{
    super.transform = transform;
}

- (CGSize) size {
    return CGSizeMake(cityMap.w, cityMap.h);
}

-(NSColor*) backgroundColor
{
    return cityMap.backgroundColor;
}

-(DrawNameType) drawName
{
    return cityMap.drawName;
}

-(void) setDrawName:(DrawNameType)drawName
{
    if(drawName != cityMap.drawName) {
        cityMap.drawName = drawName;
    }
}

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        // Initialization code
        visualFrame = frame;
        for(int i=0; i<MAXCACHE; i++) cacheLayer[i] = nil;

		//близжайщней станции пока нет
		nearestStationName = @"";
        MinScale = 0.25f;
        MaxScale = 4.f;
        Scale = 2.f;
        selectedStationName = [[NSMutableString alloc] init];
		
    }
    return self;
}

-(void)setCityMap:(CityMap *)_cityMap
{
    cityMap = _cityMap;
    self.frame = CGRectMake(0, 0, cityMap.w, cityMap.h);
    MinScale = MIN( (float)visualFrame.size.width / cityMap.size.width, (float)visualFrame.size.height / cityMap.size.height);
    MaxScale = cityMap.maxScale;
    Scale = MinScale * 2.f;

    if(cityMap.backgroundImageFile != nil) {
        if(vectorLayer != nil) [vectorLayer loadFrom:cityMap.backgroundImageFile directory:cityMap.thisMapName];
        else vectorLayer = [[VectorLayer alloc] initWithFile:cityMap.backgroundImageFile andDir:cityMap.thisMapName];
    } else {
        vectorLayer = nil;
    }
    if(cityMap.foregroundImageFile != nil) {
        if(vectorLayer2 != nil) [vectorLayer2 loadFrom:cityMap.foregroundImageFile directory:cityMap.thisMapName];
        else vectorLayer2 = [[VectorLayer alloc] initWithFile:cityMap.foregroundImageFile andDir:cityMap.thisMapName];
    } else {
        vectorLayer2 = nil;
    }
}

-(void)drawRect:(CGRect)rect
{
    CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    [self drawLayer:nil inContext:context];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    for(int i=0; i<MAXCACHE; i++) CGLayerRelease(cacheLayer[i]);
}

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)context {

    CGContextSaveGState(context);
    CGRect r = CGContextGetClipBoundingBox(context);
	CGContextSetFillColorWithColor(context, [[NSColor whiteColor] CGColor]);
	CGContextFillRect(context, r);

#ifdef AGRESSIVE_CACHE
    CGFloat drawScale = 1024.f / MAX(r.size.width, r.size.height);
    CGFloat presentScale = 1.f/drawScale;
    int cc = currentCacheLayer;
    currentCacheLayer++;
    if(currentCacheLayer >= MAXCACHE) currentCacheLayer = 0;
    if(cacheLayer[cc] != nil) CGLayerRelease(cacheLayer[cc]);
    cacheLayer[cc] = CGLayerCreateWithContext(context, CGSizeMake(512, 512), NULL);
    CGContextRef ctx = CGLayerGetContext(cacheLayer[cc]);
    CGContextScaleCTM(ctx, drawScale, drawScale);
    CGContextTranslateCTM(ctx, -r.origin.x, -r.origin.y);
#else
    CGContextRef ctx = context;
#endif
    CGContextSetInterpolationQuality(ctx, kCGInterpolationNone);
    CGContextSetShouldAntialias(ctx, true);
    CGContextSetShouldSmoothFonts(ctx, false);
    CGContextSetAllowsFontSmoothing(ctx, false);
    
    if(vectorLayer) [vectorLayer draw:context inRect:r];
    cityMap.currentScale = 1.f;//scrollView.zoomScale / MaxScale;
    [cityMap drawMap:ctx inRect:r];
    [cityMap drawTransfers:ctx inRect:r];
    if(vectorLayer2) [vectorLayer2 draw:context inRect:r];
    [cityMap drawStations:ctx inRect:r]; 

#ifdef AGRESSIVE_CACHE
    CGContextTranslateCTM(context, r.origin.x, r.origin.y);
    CGContextScaleCTM(context, presentScale, presentScale);
    CGContextDrawLayerAtPoint(context, CGPointZero, cacheLayer[cc]);
#endif
    CGContextRestoreGState(context);
}

#pragma mark -

- (void)viewDidLoad 
{
    //[super viewDidLoad];
}

- (void) drawString: (NSString*) s withFont: (NSFont*) font inRect: (CGRect) contextRect {
	
    CGFloat fontHeight = font.pointSize;
    CGFloat yOffset = (contextRect.size.height - fontHeight) / 2.0;
	
    CGRect textRect = CGRectMake(0, yOffset, contextRect.size.width, fontHeight);
	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil];
    [s drawInRect:textRect withAttributes:attributes];
}

-(void)selectStationAt:(CGPoint*)currentPosition
{
    Station *s = [cityMap checkPoint:currentPosition Station:selectedStationName];
    if(s != nil) {
        selectedStationLine = s.line.index;
		stationSelected=true;
        //Line *l = [cityMap.mapLines objectAtIndex:selectedStationLine-1];
    } else {
        stationSelected=false;
    }
}

-(void)adjustMap
{
}

@end
