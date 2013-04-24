//
//  CityMap.h
//  tube
//
//  Created by Alex 1 on 9/26/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Graph.h"

NSMutableArray * Split(NSString* s);
//CG Helpers	
void drawFilledCircle(CGContextRef context, CGFloat x, CGFloat y, CGFloat r);
void drawLine(CGContextRef context, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, int lineWidth);
void drawSelectionRect(CGContextRef context, CGRect rect);

// visual type of stations & transfers
typedef enum {DONT_DRAW=0, LIKE_PARIS=1, LIKE_LONDON=2, LIKE_MOSCOW=3, LIKE_HAMBURG=4, LIKE_VENICE=5, KINDS_NUM} StationKind;

typedef enum {NOWAY=0, WAY_BEGIN=1, WAY_MIDDLE=2, WAY_END=4, WAY_ALL=7} WayPos;

typedef enum {NAME_NORMAL=0, NAME_ALTERNATIVE=1, NAME_BOTH=2} DrawNameType;

@class Station;
@class Line;
@class CityMap;

@protocol SuperCopyable <NSObject>

-(id)superCopy;
-(void)dropCopy;

@end

@interface ComplexText : NSObject {
@private
    NSString *string, *source;
    float angle;
    int align;
    NSFont *font;
    CGRect rect;
    CGLayerRef predrawedText;
    CGPoint base, offset;
    NSArray *words;
    CGRect boundingBox;
}
@property (nonatomic, readonly) NSString* string;
@property (nonatomic, readonly) CGRect boundingBox;
@property (nonatomic, readonly) NSString* source;

+(NSString*) makePlainString:(NSString*)_str;
-(id) initWithString:(NSString*)string font:(NSFont*)font andRect:(CGRect)rect;
-(id) initWithAlternativeString:(NSString*)string font:(NSFont*)font andRect:(CGRect)rect;
-(id) initWithBothString:(NSString*)string font:(NSFont*)font andRect:(CGRect)rect;
-(void) predraw:(CGContextRef)context scale:(CGFloat)scale;
-(void) draw:(CGContextRef)context;
-(void) moveBy:(CGPoint)delta;
@end

@interface Transfer : NSObject <SuperCopyable> {
@private
    NSMutableSet* stations;
    CGFloat time;
    CGRect boundingBox;
    CGLayerRef transferLayer;
    BOOL active;
    CityMap* map;
    Transfer *_deepCopy;
}
@property (nonatomic, readonly) NSMutableSet* stations;
@property (nonatomic, assign) CGFloat time;
@property (nonatomic, readonly) CGRect boundingBox;
@property (nonatomic, assign) BOOL active;

-(id) initWithMap:(CityMap*)cityMap;
-(void) addStation:(Station*)station;
-(void) removeStation:(Station *)station;
-(void) draw:(CGContextRef)context;
-(void) predraw:(CGContextRef)context;
-(void) tuneStations;
-(void) fixTextCoordinates;
@end

@interface Station : NSObject <SuperCopyable, NSCopying> {
@private
    CGPoint pos;
    CGRect boundingBox;
    CGRect textRect;
    CGRect tapArea;
    CGRect tapTextArea;
    int index;
    int driving;
    NSString *name;
    // сегменты пути (вперёд)
    NSMutableArray *segment;
    // сегменты пути (назад)
    NSMutableArray *backSegment;
    // соседние станции
    NSMutableArray *sibling;
    // имена соседних станций
    NSMutableArray *relation;
    NSMutableArray *relationDriving;
    __weak Transfer *transfer;
    __weak Line *line;
    BOOL drawName;
    BOOL active;
    BOOL acceptBackLink;
    int links;
    // векторы вдоль линии и поперёк
    CGPoint tangent, normal;
    CityMap *map;
    ComplexText *text;
    ComplexText *altText;
    ComplexText *bothText;
    int way1, way2;
    NSMutableDictionary *transferDriving;
    CGFloat defaultTransferDriving;
    NSMutableDictionary *reverseTransferWay;
    int defaultTransferWay;
    CGPoint gpsCoords;
    NSMutableArray *forwardWay;
    NSMutableArray *backwardWay;
    NSMutableArray *firstStations;
    NSMutableArray *lastStations;
    Station *_deepCopy;
@public
    NSMutableDictionary *transferWay;
}

@property (nonatomic, readonly) NSMutableArray* relation;
@property (nonatomic, readonly) NSMutableArray* relationDriving;
@property (nonatomic, readonly) NSMutableArray* segment;
@property (nonatomic, readonly) NSMutableArray* backSegment;
@property (nonatomic, readonly) NSMutableArray* sibling;
@property (nonatomic, assign) CGPoint pos;
@property (nonatomic, readonly) CGRect boundingBox;
@property (nonatomic, readonly) CGRect textRect;
@property (nonatomic, readonly) CGRect tapArea;
@property (nonatomic, readonly) CGRect tapTextArea;
@property (nonatomic, readonly) int index;
@property (nonatomic, readonly) NSString* name;
@property (nonatomic, assign) int driving;
@property (nonatomic, weak) Transfer* transfer;
@property (nonatomic, weak) Line* line;
@property (nonatomic, assign) BOOL drawName;
@property (nonatomic, assign) BOOL active;
@property (nonatomic, readonly) BOOL acceptBackLink;
// number of links with other stations
@property (nonatomic, assign) int links;
// is a station the last one (or the first one) in the line
@property (nonatomic, readonly) BOOL terminal;
@property (nonatomic, readonly) CGPoint tangent;
@property (nonatomic, assign) int way1;
@property (nonatomic, assign) int way2;
@property (nonatomic, assign) CGPoint gpsCoords;
@property (nonatomic, readonly) NSMutableArray* forwardWay;
@property (nonatomic, readonly) NSMutableArray* backwardWay;
@property (nonatomic, readonly) NSMutableArray* firstStations;
@property (nonatomic, readonly) NSMutableArray* lastStations;
@property (nonatomic, readonly) ComplexText* altText;
@property (nonatomic, weak) NSString* nameSource;

-(id) initWithMap:(CityMap*)cityMap name:(NSString*)sname pos:(CGPoint)p index:(int)i rect:(CGRect)r andDriving:(NSString*)dr;
-(BOOL) addSibling:(Station*)st;
-(void) drawName:(CGContextRef)context;
-(void) drawStation:(CGContextRef)context;
-(void) drawSegments:(CGContextRef)context inRect:(CGRect)rect;
-(void) drawSelection:(CGContextRef)context;
-(void) makeSegments;
-(void) makeTangent;
-(void) predraw:(CGContextRef)context;
-(void) setTransferDriving:(CGFloat)driving to:(Station*)target;
-(CGFloat) transferDrivingTo:(Station*)target;
-(void) setTransferWay:(int)way to:(Station*)target;
-(void) setTransferWay:(int)way from:(Station*)target;
// set array with four elements
-(void) setTransferWays:(NSArray*)ways to:(Station*)target;
-(int) transferWayTo:(Station*)target;
-(int) transferWayFrom:(Station *)target;
-(BOOL) checkForwardWay:(Station *)st;
-(int) megaTransferWayFrom:(Station *)prevStation to:(Station*) transferStation;
-(int) megaTransferWayFrom:(Station *)prevStation to:(Station*) transferStation andNextStation:(Station *) nextStation;
-(void) moveBy:(CGPoint)delta;
-(void) moveTextBy:(CGPoint)delta;
-(void) moveTextTo:(CGRect)rect;
@end

@interface TangentPoint : NSObject {
@private
    CGPoint base;
    CGPoint backTang;
    CGPoint frontTang;
}
@property (nonatomic, readonly) CGPoint base;
@property (nonatomic, readonly) CGPoint backTang;
@property (nonatomic, readonly) CGPoint frontTang;

-(id)initWithPoint:(CGPoint)p;
-(void)calcTangentFrom:(CGPoint)p1 to:(CGPoint)p2;
@end

@interface Segment : NSObject <SuperCopyable> {
@private
    Station *start;
    Station *end;
    int driving;
    NSMutableArray* linePoints, *splinePoints;
    CGRect boundingBox;
    BOOL active, isSpline;
    CGMutablePathRef path;
    Segment *_deepCopy;
}
@property (nonatomic, readonly) Station* start;
@property (nonatomic, readonly) Station* end;
@property (nonatomic, readonly) int driving;
@property (nonatomic, readonly) CGRect boundingBox;
@property (nonatomic, assign) BOOL active;
@property (nonatomic, readonly) NSArray *linePoints;
@property (nonatomic, readonly) NSArray *splinePoints;
@property (nonatomic, assign) BOOL isSpline;

-(id)initFromStation:(Station*)from toStation:(Station*)to withDriving:(int)dr;
-(void)appendPoint:(CGPoint)p;
-(void)removePoint:(int)index;
-(void)prepare;
-(void)draw:(CGContextRef)context;
-(void)predraw;
-(void)predrawSpline;
-(void)predrawMultiline;
-(void)movePoint:(int)index by:(CGPoint)delta;
@end

@interface Line : NSObject <SuperCopyable> {
@private
    NSString *name;
    NSString *shortName;
    NSMutableArray* stations;
    NSColor* _color;
    NSColor* _disabledColor;
    int index, scc, _pinColor;
    CGLayerRef stationLayer, disabledStationLayer;
    CGRect boundingBox;
    BOOL twoStepsDraw;
    CityMap *map;
    BOOL hasAltNames;
    Line *_deepCopy;
}
@property (nonatomic, retain) NSColor* color;
@property (nonatomic, assign) int pinColor;
@property (nonatomic, retain) NSString* name;
@property (nonatomic, readonly) NSString* shortName;
@property (nonatomic, readonly) NSMutableArray* stations;
@property (nonatomic, assign) int index;
@property (nonatomic, readonly) CGRect boundingBox;
@property (nonatomic, readonly) CGLayerRef stationLayer;
@property (nonatomic, readonly) CGLayerRef disabledStationLayer;
@property (nonatomic, readonly) BOOL hasAltNames;
@property (nonatomic, readonly) int shortColorCode;

-(id)initWithMap:(CityMap*)cityMap andName:(NSString*)n;
-(id)initWithMap:(CityMap*)cityMap name:(NSString*)n stations:(NSString*)stations driving:(NSString*)driving coordinates:(NSString*)coordinates rects:(NSString*)rects;
-(void)draw:(CGContextRef)context inRect:(CGRect)rect;
-(void)drawActive:(CGContextRef)context inRect:(CGRect)rect;
-(void)drawNames:(CGContextRef)context inRect:(CGRect)rect;
-(void)additionalPointsBetween:(NSString*)station1 and:(NSString*)station2 points:(NSArray*)points;
-(Station*)getStation:(NSString*)stName;
-(id)activateSegmentFrom:(NSString*)station1 to:(NSString*)station2;
-(Segment*)activatePathFrom:(NSString*)station1 to:(NSString*)station2;
-(void)setEnabled:(BOOL)en;
-(void)predraw:(CGContextRef)context;
-(void)updateBoundingBox;
@end

@interface CityMap : NSObject {

	Graph *graph;
	NSInteger _w;
	NSInteger _h;
    NSMutableArray *mapLines;
    NSMutableArray* transfers;
    CGFloat maxScale;
    CGRect activeExtent;
    NSMutableArray *activePath;
    NSString *thisMapName;
    NSMutableArray *pathStationsList;
    NSMutableArray *pathTimesList;
    NSMutableArray *pathDocksList;
    CGFloat currentScale;
    NSString *backgroundImageFile;
    NSString *foregroundImageFile;
    CGFloat gpsCircleScale;
    NSColor *backgroundColor;
    BOOL hasAltNames;
    NSMutableArray *undo;
    NSString *mapFile;
    NSString *trpFile;
@public
    CGFloat PredrawScale;
    CGFloat LineWidth;
    CGFloat StationDiameter;
    CGFloat FontSize;
    StationKind StKind;
    StationKind TrKind;
    DrawNameType DrawName;
    NSString *TEXT_FONT;
}

// размер карты 
@property (readonly) NSInteger w;
@property (readonly) NSInteger h;
@property (readonly) CGSize size;
@property (nonatomic, retain) Graph *graph;
@property (nonatomic, readonly) CGRect activeExtent;
@property (nonatomic, assign) CGFloat predrawScale;
@property (nonatomic, readonly) NSArray* activePath;
@property (nonatomic, assign) StationKind stationKind;
@property (nonatomic, assign) StationKind transferKind;
@property (nonatomic, readonly) CGFloat maxScale;
@property (nonatomic, retain) NSString *thisMapName;
@property (nonatomic, retain) NSString *pathToMap;
@property (nonatomic, readonly) NSMutableArray *pathStationsList;
@property (nonatomic, readonly) NSMutableArray *pathTimesList;
@property (nonatomic, readonly) NSMutableArray *pathDocksList;
@property (nonatomic, readonly) NSMutableArray *mapLines;
@property (nonatomic, readonly) NSMutableArray *transfers;
@property (nonatomic, assign) CGFloat currentScale;
@property (nonatomic, readonly) NSString* backgroundImageFile;
@property (nonatomic, readonly) NSString* foregroundImageFile;
@property (nonatomic, readonly) CGFloat gpsCircleScale;
@property (nonatomic, readonly) NSColor *backgroundColor;
@property (nonatomic, assign) DrawNameType drawName;
@property (nonatomic, retain) NSMutableArray *languages;

- (NSColor *) colorForHex:(NSString *)hexColor;
//
-(void) loadMap:(NSString *)mapName;
-(void) loadOldMap:(NSString *)mapFile trp:(NSString*)trpFile;
-(void) loadNewMap:(NSString *)mapFile trp:(NSString*)trpFile;
-(void) saveMap;
-(void) initVars ;
// предварительная отрисовка трансферов и названий станций
-(void) predraw;

//make graph stuff 
-(void) calcGraph;
-(void) processTransfersForGraph;

//graph func
-(NSDictionary*) calcPath :(NSString*) firstStation :(NSString*) secondStation :(NSInteger) firstStationLineNum :(NSInteger)secondStationLineNum ;

-(Station*) checkPoint:(CGPoint*)point Station:(NSMutableString*)stationName selectText:(BOOL*)text;
-(Segment*) checkPoint:(CGPoint*)point segmentPoint:(int*)pIndex;
-(NSArray*) checkRect:(CGRect)rect;
	
// load stuff 
-(void) processTransfers:(NSString*)transferInfo;
-(void) processTransfers2:(NSString*)transferInfo;
-(void) processAddNodes:(NSString*)addNodeInfo;

// drawing
-(void) drawMap:(CGContextRef) context inRect:(CGRect)rect;
-(void) drawStations:(CGContextRef) context inRect:(CGRect)rect;
-(void) drawTransfers:(CGContextRef) context inRect:(CGRect)rect;

-(void) drawActive:(CGContextRef) context inRect:(CGRect)rect;

-(void) activatePath:(NSArray*)pathMap;
-(void) resetMap:(BOOL)enable;
-(Station*) findNearestStationTo:(CGPoint)gpsCoord;
-(CGRect)getGeoCoordsForRect:(CGRect)rect coordinates:(NSMutableArray*)date;

-(NSMutableArray*) describePath:(NSArray*)pathMap;
-(void)updateBoundingBox;

-(void)saveState;
-(BOOL)restoreState;
-(NSUInteger)undoNumber;
@end
