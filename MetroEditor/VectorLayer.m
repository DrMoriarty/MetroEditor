//
//  VectorLayer.m
//  tube
//
//  Created by Vasiliy Makarov on 01.02.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "VectorLayer.h"
#import "CityMap.h"

@implementation VectorLine

@synthesize boundingBox;
@synthesize enabled;

-(id) initWithPoints:(NSArray *)points color:(CGColorRef)color andDisabledColor:(CGColorRef)dcol
{
    if((self = [super init])) {
        col = CGColorRetain(color);
        disabledCol = CGColorRetain(dcol);
        width = [[points lastObject] intValue];
        path = CGPathCreateMutable();
        enabled = YES;
        angle = 0;
        center = CGPointZero;
        NSRange range;
        range.location = 0;
        range.length = [points count] - 1;
        BOOL first = YES;
        for (NSString* s in [points objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range]]) {
            NSArray *c = [s componentsSeparatedByString:@","];
            if([c count] < 2) continue;
            if(first) {
                CGPathMoveToPoint(path, nil, [[c objectAtIndex:0] intValue], [[c objectAtIndex:1] intValue]);
                first = NO;
            } else
                CGPathAddLineToPoint(path, nil, [[c objectAtIndex:0] intValue], [[c objectAtIndex:1] intValue]);
        }
        boundingBox = CGPathGetPathBoundingBox(path);
    }
    return self;
}

-(void) dealloc
{
    CGColorRelease(col);
    CGColorRelease(disabledCol);
    CGPathRelease(path);
}

-(void) draw:(CGContextRef)context
{
    if(angle != 0) {
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, center.x, center.y);
        CGContextRotateCTM(context, angle);
        CGContextTranslateCTM(context, -center.x, -center.y);
    }
    if(enabled) CGContextSetStrokeColorWithColor(context, col);
    else CGContextSetStrokeColorWithColor(context, disabledCol);
    CGContextSetLineWidth(context, width);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextAddPath(context, path);
    CGContextStrokePath(context);
    if(angle != 0) CGContextRestoreGState(context);
}

-(void) rotateAt:(CGFloat)ang center:(CGPoint)c
{
    angle = ang;
    center = c;
}

@end

@implementation VectorPolygon

@synthesize boundingBox;
@synthesize enabled;

-(id) initWithPoints:(NSArray *)points color:(CGColorRef)color andDisabledColor:(CGColorRef)dcol
{
    if((self = [super init])) {
        col = CGColorRetain(color);
        disabledCol = CGColorRetain(dcol);
        path = CGPathCreateMutable();
        enabled = YES;
        angle = 0;
        center = CGPointZero;
        BOOL first = YES;
        for (NSString *s in points) {
            NSArray *c = [s componentsSeparatedByString:@","];
            if([c count] < 2) continue;
            if(first) {
                CGPathMoveToPoint(path, nil, [[c objectAtIndex:0] intValue], [[c objectAtIndex:1] intValue]);
                first = NO;
            } else 
                CGPathAddLineToPoint(path, nil, [[c objectAtIndex:0] intValue], [[c objectAtIndex:1] intValue]);

        }
        CGPathCloseSubpath(path);
        boundingBox = CGPathGetPathBoundingBox(path);
    }
    return self;
}

-(void)dealloc
{
    CGColorRelease(col);
    CGColorRelease(disabledCol);
    CGPathRelease(path);
}

-(void)draw:(CGContextRef)context
{
    if(angle != 0) {
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, center.x, center.y);
        CGContextRotateCTM(context, angle);
        CGContextTranslateCTM(context, -center.x, -center.y);
    }
    if(enabled) CGContextSetFillColorWithColor(context, col);
    else CGContextSetFillColorWithColor(context, disabledCol);
    CGContextAddPath(context, path);
    CGContextFillPath(context);
    if(angle != 0) CGContextRestoreGState(context);
}

-(void) rotateAt:(CGFloat)ang center:(CGPoint)c
{
    angle = ang;
    center = c;
}

@end

@implementation VectorText

@synthesize enabled;
@synthesize boundingBox;

-(id)initWithFontName:(NSString *)_fontName fontSize:(int)_fontSize point:(CGPoint)_point text:(NSString *)_text andColor:(CGColorRef)color
{
    if((self = [super init])) {
        fontName = _fontName;
        fontSize = _fontSize;
        point = _point;
        text = _text;
        enabled = YES;
        angle = 0;
        center = CGPointZero;
        boundingBox.origin = point;
        boundingBox.size = CGSizeMake(fontSize, fontSize);
        col = CGColorRetain(color);
    }
    return self;
}

-(void)draw:(CGContextRef)context
{
    if(angle != 0) {
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, center.x, center.y);
        CGContextRotateCTM(context, angle);
        CGContextTranslateCTM(context, -center.x, -center.y);
    }
    CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1.0, -1.0));
    //if(enabled) {
        CGContextSetFillColorWithColor(context, col );
    /*} else {
        CGContextSetFillColorWithColor(context, [[UIColor lightGrayColor] CGColor] );
    }*/
    CGContextSetTextDrawingMode (context, kCGTextFill);
    CGContextSelectFont(context, "Arial-BoldMT", fontSize, kCGEncodingMacRoman);
    CGContextShowTextAtPoint(context, point.x, point.y+0.9f*fontSize, [text cStringUsingEncoding:[NSString defaultCStringEncoding]], [text length]);
    if(angle != 0) CGContextRestoreGState(context);
}

-(void)dealloc
{
    CGColorRelease(col);
}

-(void) rotateAt:(CGFloat)ang center:(CGPoint)c
{
    angle = ang;
    center = c;
}

@end

@implementation VectorSpline

@synthesize boundingBox;
@synthesize enabled;

-(id) initWithPoints:(NSArray *)points color:(CGColorRef)color strokeColor:(CGColorRef)strokeColor andDisabledColor:(CGColorRef)dcol
{
    if((self = [super init])) {
        col = CGColorRetain(color);
        disabledCol = CGColorRetain(dcol);
        strokeCol = CGColorRetain(strokeColor);
        enabled = YES;
        angle = 0;
        center = CGPointZero;
        lineWidth = 0.f;
        NSMutableArray *pts = [NSMutableArray array];
        for (NSString *s in points) {
            NSArray *c = [s componentsSeparatedByString:@","];
            if([c count] < 2) {
                lineWidth = [[c objectAtIndex:0] intValue];
            } else {
                [pts addObject:[NSValue valueWithPoint:CGPointMake([[c objectAtIndex:0] intValue], [[c objectAtIndex:1] intValue])]];
            }
        }
        [pts addObject:[pts objectAtIndex:1]];
        NSMutableArray *pts2 = [NSMutableArray array];
        for(int i=1; i<[pts count]-1; i++) {
            TangentPoint *p = [[TangentPoint alloc] initWithPoint:[[pts objectAtIndex:i] pointValue]];
            [p calcTangentFrom:[[pts objectAtIndex:i-1] pointValue] to:[[pts objectAtIndex:i+1] pointValue]];
            [pts2 addObject:p];
        }
        

        path = CGPathCreateMutable();
        TangentPoint *tp1 = [pts2 objectAtIndex:0], *tp2 = nil;
        CGPathMoveToPoint(path, nil, tp1.base.x, tp1.base.y);
        for(int i=0; i<[pts2 count]-1; i++) {
            tp1 = [pts2 objectAtIndex:i];
            tp2 = [pts2 objectAtIndex:i+1];
            CGPathAddCurveToPoint(path, nil, tp1.frontTang.x, tp1.frontTang.y, tp2.backTang.x, tp2.backTang.y, tp2.base.x, tp2.base.y);
        }
        tp1 = [pts2 lastObject];
        tp2 = [pts2 objectAtIndex:0];
        CGPathAddCurveToPoint(path, nil, tp1.frontTang.x, tp1.frontTang.y, tp2.backTang.x, tp2.backTang.y, tp2.base.x, tp2.base.y);
        
        CGPathCloseSubpath(path);
        boundingBox = CGPathGetPathBoundingBox(path);
    }
    return self;
}

-(void)dealloc
{
    CGColorRelease(col);
    CGColorRelease(disabledCol);
    CGColorRelease(strokeCol);
    CGPathRelease(path);
}

-(void)draw:(CGContextRef)context
{
    if(angle != 0) {
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, center.x, center.y);
        CGContextRotateCTM(context, angle);
        CGContextTranslateCTM(context, -center.x, -center.y);
    }
    if(enabled) CGContextSetFillColorWithColor(context, col);
    else CGContextSetFillColorWithColor(context, disabledCol);
    CGContextSetStrokeColorWithColor(context, strokeCol);
    CGContextAddPath(context, path);
    if(lineWidth > 0.f) {
        CGContextSetLineWidth(context, lineWidth);
        CGContextStrokePath(context);
    } else {
        CGContextFillPath(context);
    }
    if(angle != 0) CGContextRestoreGState(context);
}

-(void) rotateAt:(CGFloat)ang center:(CGPoint)c
{
    angle = ang;
    center = c;
}

@end

@implementation VectorLayer

-(id)initWithFile:(NSString *)fileName andDir:(NSString *)dir
{
    if((self = [super init])) {
        enabled = YES;
        scale = 1.0f;
        colorSpace = CGColorSpaceCreateDeviceRGB();
        elements = [[NSMutableArray alloc] init];
        [self loadFrom:fileName directory:dir];
    }
    return self;
}

-(void)dealloc
{
    CGColorRelease(brushColor);
    CGColorRelease(penColor);
    CGColorSpaceRelease(colorSpace);
}

-(BOOL) enabled {
    return enabled;
}

-(void) setEnabled:(BOOL)_enabled {
    enabled = _enabled;
    for (id element in elements) {
        [element setEnabled:enabled];
    }
}

- (CGColorRef) colorForHex:(NSString *)hexColor {
	hexColor = [[hexColor stringByTrimmingCharactersInSet:
				 [NSCharacterSet whitespaceAndNewlineCharacterSet]
				 ] uppercaseString];  
	
    // String should be 6 or 7 characters if it includes '#'  
    if ([hexColor length] < 6) 
		return nil;
	
    // strip # if it appears  
    if ([hexColor hasPrefix:@"#"]) 
		hexColor = [hexColor substringFromIndex:1];  
	
    // if the value isn't 6 characters at this point return 
    // the color black	
    if ([hexColor length] != 6) 
		return nil;
	
    // Separate into r, g, b substrings  
    NSRange range;  
    range.location = 0;  
    range.length = 2; 
	
    NSString *rString = [hexColor substringWithRange:range];  
	
    range.location = 2;  
    NSString *gString = [hexColor substringWithRange:range];  
	
    range.location = 4;  
    NSString *bString = [hexColor substringWithRange:range];  
	
    // Scan values  
    unsigned int r, g, b;  
    [[NSScanner scannerWithString:rString] scanHexInt:&r];  
    [[NSScanner scannerWithString:gString] scanHexInt:&g];  
    [[NSScanner scannerWithString:bString] scanHexInt:&b];  
    
    float components[4];
    components[0] = (float) r / 255.0f;
    components[1] = (float) g / 255.0f;
    components[2] = (float) b / 255.0f;
    components[3] = 1.f;
	
    return CGColorCreate(colorSpace, components);
}

-(CGColorRef) disabledColor:(CGColorRef)normalColor {
    const CGFloat *rgba = CGColorGetComponents(normalColor);
    CGFloat r, g, b, M, m, sd;
    r = rgba[0];
    g = rgba[1];
    b = rgba[2];
    
    // set brightness to 90%
    M = MAX(r, MAX(g, b));
    sd = 0.9f / M;
    r *= sd;
    g *= sd;
    b *= sd;
    M = 0.9f;
    
    // set saturation to 10%
    m = MIN(r, MIN(g, b));
    sd = (0.1f * M) / (M-m);
    r = M - (M-r)*sd;
    g = M - (M-g)*sd;
    b = M - (M-b)*sd;
    
    float components[4];
    components[0] = r;
    components[1] = g;
    components[2] = b;
    components[3] = 1.f;
    return CGColorCreate(colorSpace, components);
}


-(void)loadFrom:(NSString *)fileName directory:(NSString*)dir
{
    currentAngle = 0;
    [elements removeAllObjects];
    NSString *fn = nil;

    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *mapDirPath = [cacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@",dir]];
    if ([[manager contentsOfDirectoryAtPath:mapDirPath error:nil] count]>0) {
        NSDirectoryEnumerator *dirEnum = [manager enumeratorAtPath:mapDirPath];
        NSString *file;
        while (file = [dirEnum nextObject]) {
            if ([file isEqualToString: fileName]) {
                fn = [NSString stringWithFormat:@"%@/%@", mapDirPath, file];
                break;
            }
        }
    } 
    if (fn == nil) {
        fn = [[NSBundle mainBundle] pathForResource:fileName ofType:nil inDirectory:[NSString stringWithFormat:@"%@",dir]];
    }
    NSString *contents = [NSString stringWithContentsOfFile:fn encoding:NSUTF8StringEncoding error:nil];
    [contents enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        NSArray *words = [line componentsSeparatedByString:@" "];
        NSString *w = [[words objectAtIndex:0] lowercaseString];
        if([w isEqualToString:@"size"]) {
            NSArray *a = [[words objectAtIndex:1] componentsSeparatedByString:@"x"];
            size.width = [[a objectAtIndex:0] intValue];
            size.height = [[a objectAtIndex:1] intValue];
            
        } else if([w isEqualToString:@"brushcolor"]) {
            if(brushColor != nil) CGColorRelease(brushColor);
            brushColor = [self colorForHex:[words objectAtIndex:1]];
            
        } else if([w isEqualToString:@"pencolor"]) {
            if(penColor != nil) CGColorRelease(penColor);
            penColor = [self colorForHex:[words objectAtIndex:1]];
            
        } else if([w isEqualToString:@"line"]) {
            NSRange range;
            range.location = 1;
            range.length = [words count] - 1;
            [elements addObject:[[VectorLine alloc] initWithPoints:[words objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range]] color:penColor andDisabledColor:[self disabledColor:penColor]]];
            [[elements lastObject] rotateAt:-currentAngle center:CGPointMake(size.width/2, size.height/2)];
            
        } else if([w isEqualToString:@"polygon"]) {
            NSRange range;
            range.location = 1;
            range.length = [words count] - 1;
            [elements addObject:[[VectorPolygon alloc] initWithPoints:[words objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range]] color:brushColor andDisabledColor:[self disabledColor:brushColor]]];
            [[elements lastObject] rotateAt:-currentAngle center:CGPointMake(size.width/2, size.height/2)];
            
        } else if([w isEqualToString:@"textout"]) {
            NSArray *ww = [line componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", "]];
            NSArray *www = [ww filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF <> \"\""]];
            [elements addObject:[[VectorText alloc] initWithFontName:[www objectAtIndex:1] fontSize:[[www objectAtIndex:2] intValue] point:CGPointMake([[www objectAtIndex:3] intValue], [[www objectAtIndex:4] intValue]) text:[www objectAtIndex:5] andColor:penColor ]];
            [[elements lastObject] rotateAt:-currentAngle center:CGPointMake(size.width/2, size.height/2)];
            
        } else if([w isEqualToString:@"angletextout"]) {
            NSArray *ww = [line componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", "]];
            NSArray *www = [ww filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF <> \"\""]];
            CGPoint pos = CGPointMake([[www objectAtIndex:3] intValue], [[www objectAtIndex:4] intValue]);
            [elements addObject:[[VectorText alloc] initWithFontName:@"Arial" fontSize:[[www objectAtIndex:2] intValue] point:pos text:[www objectAtIndex:5] andColor:penColor ]];
            CGFloat ang = [[www objectAtIndex:1] floatValue];
            ang /= 180.f / M_PI;
            [[elements lastObject] rotateAt:-currentAngle-ang center:pos];
            
        } else if([w isEqualToString:@"angle"]) {
            CGFloat ang = [[words objectAtIndex:1] floatValue];
            ang /= 180.f / M_PI;
            currentAngle += ang;
        } else if([w isEqualToString:@"spline"]) {
            NSRange range;
            range.location = 1;
            range.length = [words count] - 1;
            [elements addObject:[[VectorSpline alloc] initWithPoints:[words objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range]] color:brushColor strokeColor:penColor andDisabledColor:[self disabledColor:brushColor]]];
            [[elements lastObject] rotateAt:-currentAngle center:CGPointMake(size.width/2, size.height/2)];
            
        } else if([w isEqualToString:@"scale"]) {
            scale = [[words objectAtIndex:1] floatValue];
            
        }
    }];
}

-(void)draw:(CGContextRef)context inRect:(CGRect)rect
{
    CGContextSaveGState(context);
    CGContextScaleCTM(context, scale, scale);
    rect.origin.x /= scale;
    rect.origin.y /= scale;
    rect.size.width /= scale;
    rect.size.height /= scale;
    for (id element in elements) {
        if(CGRectIntersectsRect(rect, [element boundingBox])) {
            [element draw:context];
        }
    }
    CGContextRestoreGState(context);
}

@end
