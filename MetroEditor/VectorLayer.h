//
//  VectorLayer.h
//  tube
//
//  Created by Vasiliy Makarov on 01.02.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

/***** Vector Line *****/

@interface VectorLine : NSObject {
@private
    CGRect boundingBox;
    CGColorRef col;
    CGColorRef disabledCol;
    CGMutablePathRef path;
    int width;
    BOOL enabled;
    CGFloat angle;
    CGPoint center;
}
@property (nonatomic, readonly) CGRect boundingBox;
@property (nonatomic, assign) BOOL enabled;

-(id) initWithPoints:(NSArray*)points color:(CGColorRef) color andDisabledColor:(CGColorRef) dcol;
-(void) draw:(CGContextRef) context;
-(void) rotateAt:(CGFloat)ang center:(CGPoint)c;

@end

/***** Vector Polygon *****/

@interface VectorPolygon : NSObject {
@private
    CGRect boundingBox;
    CGColorRef col;
    CGColorRef disabledCol;
    CGMutablePathRef path;
    BOOL enabled;
    CGFloat angle;
    CGPoint center;
}
@property (nonatomic, readonly) CGRect boundingBox;
@property (nonatomic, assign) BOOL enabled;

-(id) initWithPoints:(NSArray*) points color:(CGColorRef)color andDisabledColor:(CGColorRef)dcol;
-(void) draw:(CGContextRef) context;
-(void) rotateAt:(CGFloat)ang center:(CGPoint)c;

@end

/***** Vector Text *****/

@interface VectorText : NSObject {
@private
    NSString *fontName, *text;
    int fontSize;
    BOOL enabled;
    CGPoint point;
    CGRect boundingBox;
    CGColorRef col;
    CGFloat angle;
    CGPoint center;
}
@property (nonatomic, readonly) CGRect boundingBox;
@property (nonatomic, assign) BOOL enabled;

-(id) initWithFontName:(NSString*)fontName fontSize:(int)fontSize point:(CGPoint)point text:(NSString*)text andColor:(CGColorRef)color;
-(void) draw:(CGContextRef) context;
-(void) rotateAt:(CGFloat)ang center:(CGPoint)c;

@end

/***** Vector Spline *****/

@interface VectorSpline : NSObject {
@private
    CGRect boundingBox;
    CGColorRef col;
    CGColorRef disabledCol;
    CGColorRef strokeCol;
    CGMutablePathRef path;
    BOOL enabled;
    CGFloat angle, lineWidth;
    CGPoint center;
}
@property (nonatomic, readonly) CGRect boundingBox;
@property (nonatomic, assign) BOOL enabled;

-(id) initWithPoints:(NSArray*) points color:(CGColorRef)color strokeColor:(CGColorRef)strokeColor andDisabledColor:(CGColorRef)dcol;
-(void) draw:(CGContextRef) context;
-(void) rotateAt:(CGFloat)ang center:(CGPoint)c;

@end

/***** Vector Layer *****/

@interface VectorLayer : NSObject {
@private
    CGSize size;
    CGColorSpaceRef colorSpace;
    CGColorRef brushColor, penColor;
    NSMutableArray *elements;
    BOOL enabled;
    CGFloat currentAngle;
    CGFloat scale;
}
@property (nonatomic, assign) BOOL enabled;

-(id) initWithFile:(NSString*)fileName andDir:(NSString*)dir;
-(void) loadFrom:(NSString*)fileName directory:(NSString*)dir;
-(void) draw:(CGContextRef) context inRect:(CGRect)rect;

@end
