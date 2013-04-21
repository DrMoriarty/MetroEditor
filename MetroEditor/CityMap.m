//
//  CityMap.m
//  tube
//
//  Created by Alex 1 on 9/26/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "CityMap.h"
#include "ini/ini.h"
//#import "ManagedObjects.h"
//#import "tubeAppDelegate.h"
//#import "Utils.h"
#import "NSOutputStream+WriteNSString.h"

#define MAX_UNDO 1000

CGFloat sqr(CGFloat v) {
    return v*v;
}

NSMutableArray * Split(NSString* s)
{
    NSMutableArray *res = [[NSMutableArray alloc] init];
    NSRange range = NSMakeRange(0, [s length]);
    while (YES) {
        NSUInteger comma = [s rangeOfString:@"," options:0 range:range].location;
        NSUInteger bracket = [s rangeOfString:@"(" options:0 range:range].location;
        if(comma == NSNotFound) {
            if(bracket != NSNotFound) range.length --;
            [res addObject:[s substringWithRange:range]];
            break;
        } else {
            if(bracket == NSNotFound || bracket > comma) {
                comma -= range.location;
                [res addObject:[s substringWithRange:NSMakeRange(range.location, comma)]];
                range.location += comma+1;
                range.length -= comma+1;
            } else {
                NSUInteger bracket2 = [s rangeOfString:@")" options:0 range:range].location;
                bracket2 -= range.location;
                [res addObject:[s substringWithRange:NSMakeRange(range.location, bracket2)]];
                range.location += bracket2+2;
                range.length -= bracket2+2;
            }
        }
    }
    return res;
}

CGFloat Sql(CGPoint p1, CGPoint p2)
{
    CGFloat dx = p1.x-p2.x;
    CGFloat dy = p1.y-p2.y;
    return dx*dx + dy*dy;
}

int StringToWay(NSString* str)
{
    int way = NOWAY;
    for(int i=0; i<[str length]; i++) {
        char ch = [str characterAtIndex:i];
        switch (ch) {
            case 'S':
            case 's':
                way |= WAY_BEGIN;
                break;
            case 'M':
            case 'm':
                way |= WAY_MIDDLE;
                break;
            case 'E':
            case 'e':
                way |= WAY_END;
                break;
        }
    }
    return way;
}

NSString * WayToString(int way)
{
    if(way == NOWAY) {
        return @"";
    }
    NSMutableString *str = [NSMutableString string];
    if(way & WAY_BEGIN) {
        [str appendString:@"S"];
    }
    if(way & WAY_MIDDLE) {
        [str appendString:@"M"];
    }
    if(way & WAY_END) {
        [str appendString:@"E"];
    }
    return str;
}

// CG Helpres
void drawLine(CGContextRef context, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, int lineWidth) {
	CGContextSetLineCap(context, kCGLineCapRound);
	CGContextSetLineWidth(context, lineWidth);
	CGContextMoveToPoint(context, x1, y1);
	CGContextAddLineToPoint(context, x2, y2);
	CGContextStrokePath(context);
}

void drawFilledCircle(CGContextRef context, CGFloat x, CGFloat y, CGFloat r) {
	// Draw a circle (filled)
	CGContextFillEllipseInRect(context, CGRectMake(x-r, y-r, 2*r, 2*r));
}

void MyDrawPattern (void * info, CGContextRef context)
{
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 4, 4));
    CGContextSetRGBFillColor(context, 0, 0, 0, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 2, 2));
    //CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextFillRect(context, CGRectMake(2, 2, 2, 2));
}

CGColorSpaceRef _selectionColorSpace = NULL;
CGPatternRef _selectionPattern = NULL;
CGPatternCallbacks _selectionPatternCallbacks = {0, &MyDrawPattern, NULL};

void drawSelectionRect(CGContextRef context, CGRect rect)
{
    CGContextSaveGState(context);
    if(!_selectionPattern) {
        _selectionColorSpace = CGColorSpaceCreatePattern(NULL);
        _selectionPattern = CGPatternCreate(NULL, CGRectMake(0, 0, 4, 4), CGAffineTransformIdentity, 4, 4, kCGPatternTilingConstantSpacingMinimalDistortion, true, &_selectionPatternCallbacks);
        CGColorSpaceRelease(_selectionColorSpace);
    }
    CGContextSetStrokeColorSpace(context, _selectionColorSpace);
    CGContextSetLineWidth(context, 2);
    CGFloat alpha = 1;
    CGContextSetStrokePattern(context, _selectionPattern, &alpha);
    CGContextStrokeRect(context, rect);
    CGContextRestoreGState(context);
}


@implementation ComplexText

@synthesize string;
@synthesize boundingBox;
@synthesize source;

+(NSString*) makePlainString:(NSString*)_str
{
    NSString *str = _str;
    BOOL finish = NO;
    while (!finish) {
        switch([str characterAtIndex:0]) {
            case '/':
            case '\\':
            case '^':
            case '_':
            case '-':
            case '<':
            case '>':
            case '|':
                str = [str substringFromIndex:1];
                break;
            default:
                finish = YES;
                break;
        }
    }
    NSUInteger alternative = [str rangeOfString:@"&"].location;
    if(alternative != NSNotFound) str = [str substringToIndex:alternative];
    str = [[str stringByReplacingOccurrencesOfString:@";" withString:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return str;
}

-(id) initWithString:(NSString *)_string font:(NSFont *)_font andRect:(CGRect)_rect
{
    if((self = [super init])) {
        angle = 0;
        align = 0;
        string = _string;
        source = [_string copy];
        font = _font;
        rect = _rect;
        while (true) {
            unichar ch = [string characterAtIndex:0];
            BOOL finish = NO;
            switch (ch) {
                case '/':
                    angle = -M_PI_4;
                    break;
                case '\\':
                    angle = M_PI_4;
                    break;
                case '^':
                    align |= 0x1;
                    break;
                case '_':
                    align |= 0x2;
                    break;
                case '-':
                    align &= 0xc;
                    break;
                case '<':
                    align |= 0x4;
                    break;
                case '>':
                    align |= 0x8;
                    break;
                case '|':
                    align &= 0x3;
                    break;
                default:
                    finish = YES;
                    break;
            }
            if(finish) break;
            else string = [string substringFromIndex:1];
        }
        NSUInteger alternative = [string rangeOfString:@"&"].location;
        if(alternative != NSNotFound) {
            string = [string substringToIndex:alternative];
        }
        words = [string componentsSeparatedByString:@";"];
        string = [[string stringByReplacingOccurrencesOfString:@";" withString:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if(angle == 0) {
            CGFloat d = rect.size.height * 0.5f;
            boundingBox = rect;
            //boundingBox.origin.x -= d;
            //boundingBox.origin.y -= d;
            //boundingBox.size.width += 2*d;
            //boundingBox.size.height += 2*d;
        } else {
            CGPoint rbase = rect.origin;
            switch (align & 0x3) {
                case 0x0:
                    rbase.y = rect.origin.y + rect.size.height/2; break;
                case 0x1:
                    rbase.y = rect.origin.y; break;
                case 0x2:
                    rbase.y = rect.origin.y + rect.size.height; break;
            }
            switch (align & 0xc) {
                case 0x0:
                    rbase.x = rect.origin.x + rect.size.width/2; break;
                case 0x4:
                    rbase.x = rect.origin.x; break;
                case 0x8:
                    rbase.x = rect.origin.x + rect.size.width; break;
            }
            CGAffineTransform tr = CGAffineTransformMakeTranslation(rbase.x, rbase.y);
            tr = CGAffineTransformRotate(tr, angle);
            tr = CGAffineTransformTranslate(tr, -rbase.x, -rbase.y);
            CGRect r1, r2, r3, r4;
            r1.origin = CGPointApplyAffineTransform(rect.origin, tr);
            r2.origin = CGPointApplyAffineTransform(CGPointMake(rect.origin.x + rect.size.width, rect.origin.y), tr);
            r3.origin = CGPointApplyAffineTransform(CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height), tr);
            r4.origin = CGPointApplyAffineTransform(CGPointMake(rect.origin.x, rect.origin.y + rect.size.height), tr);
            r1.size = r2.size = r3.size = r4.size = CGSizeMake(0.01f, 0.01f);
            boundingBox = CGRectUnion(CGRectUnion(r1, r2), CGRectUnion(r3, r4));
        }
    }
    return self;
}

-(id) initWithAlternativeString:(NSString *)_string font:(NSFont *)_font andRect:(CGRect)_rect
{
    if((self = [super init])) {
        angle = 0;
        align = 0;
        string = _string;
        source = [_string copy];
        font = _font;
        rect = _rect;
        while (true) {
            unichar ch = [string characterAtIndex:0];
            BOOL finish = NO;
            switch (ch) {
                case '/':
                    angle = -M_PI_4;
                    break;
                case '\\':
                    angle = M_PI_4;
                    break;
                case '^':
                    align |= 0x1;
                    break;
                case '_':
                    align |= 0x2;
                    break;
                case '-':
                    align &= 0xc;
                    break;
                case '<':
                    align |= 0x4;
                    break;
                case '>':
                    align |= 0x8;
                    break;
                case '|':
                    align &= 0x3;
                    break;
                default:
                    finish = YES;
                    break;
            }
            if(finish) break;
            else string = [string substringFromIndex:1];
        }
        NSUInteger alternative = [string rangeOfString:@"&"].location;
        if(alternative != NSNotFound) {
            string = [string substringFromIndex:alternative+1];
        }
        words = [string componentsSeparatedByString:@";"];
        string = [[string stringByReplacingOccurrencesOfString:@";" withString:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if(angle == 0) {
            CGFloat d = rect.size.height * 0.5f;
            boundingBox = rect;
            //boundingBox.origin.x -= d;
            //boundingBox.origin.y -= d;
            //boundingBox.size.width += 2*d;
            //boundingBox.size.height += 2*d;
        } else {
            CGPoint rbase = rect.origin;
            switch (align & 0x3) {
                case 0x0:
                    rbase.y = rect.origin.y + rect.size.height/2; break;
                case 0x1:
                    rbase.y = rect.origin.y; break;
                case 0x2:
                    rbase.y = rect.origin.y + rect.size.height; break;
            }
            switch (align & 0xc) {
                case 0x0:
                    rbase.x = rect.origin.x + rect.size.width/2; break;
                case 0x4:
                    rbase.x = rect.origin.x; break;
                case 0x8:
                    rbase.x = rect.origin.x + rect.size.width; break;
            }
            CGAffineTransform tr = CGAffineTransformMakeTranslation(rbase.x, rbase.y);
            tr = CGAffineTransformRotate(tr, angle);
            tr = CGAffineTransformTranslate(tr, -rbase.x, -rbase.y);
            CGRect r1, r2, r3, r4;
            r1.origin = CGPointApplyAffineTransform(rect.origin, tr);
            r2.origin = CGPointApplyAffineTransform(CGPointMake(rect.origin.x + rect.size.width, rect.origin.y), tr);
            r3.origin = CGPointApplyAffineTransform(CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height), tr);
            r4.origin = CGPointApplyAffineTransform(CGPointMake(rect.origin.x, rect.origin.y + rect.size.height), tr);
            r1.size = r2.size = r3.size = r4.size = CGSizeMake(0.01f, 0.01f);
            boundingBox = CGRectUnion(CGRectUnion(r1, r2), CGRectUnion(r3, r4));
        }
    }
    return self;
}

-(id) initWithBothString:(NSString *)_string font:(NSFont *)_font andRect:(CGRect)_rect
{
    if((self = [super init])) {
        angle = 0;
        align = 0;
        string = _string;
        source = [_string copy];
        font = _font;
        rect = _rect;
        while (true) {
            unichar ch = [string characterAtIndex:0];
            BOOL finish = NO;
            switch (ch) {
                case '/':
                    angle = -M_PI_4;
                    break;
                case '\\':
                    angle = M_PI_4;
                    break;
                case '^':
                    align |= 0x1;
                    break;
                case '_':
                    align |= 0x2;
                    break;
                case '-':
                    align &= 0xc;
                    break;
                case '<':
                    align |= 0x4;
                    break;
                case '>':
                    align |= 0x8;
                    break;
                case '|':
                    align &= 0x3;
                    break;
                default:
                    finish = YES;
                    break;
            }
            if(finish) break;
            else string = [string substringFromIndex:1];
        }
        words = [string componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@";&"]];
        string = [[string stringByReplacingOccurrencesOfString:@";" withString:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if(angle == 0) {
            CGFloat d = rect.size.height * 0.5f;
            boundingBox = rect;
            //boundingBox.origin.x -= d;
            //boundingBox.origin.y -= d;
            //boundingBox.size.width += 2*d;
            //boundingBox.size.height += 2*d;
        } else {
            CGPoint rbase = rect.origin;
            switch (align & 0x3) {
                case 0x0:
                    rbase.y = rect.origin.y + rect.size.height/2; break;
                case 0x1:
                    rbase.y = rect.origin.y; break;
                case 0x2:
                    rbase.y = rect.origin.y + rect.size.height; break;
            }
            switch (align & 0xc) {
                case 0x0:
                    rbase.x = rect.origin.x + rect.size.width/2; break;
                case 0x4:
                    rbase.x = rect.origin.x; break;
                case 0x8:
                    rbase.x = rect.origin.x + rect.size.width; break;
            }
            CGAffineTransform tr = CGAffineTransformMakeTranslation(rbase.x, rbase.y);
            tr = CGAffineTransformRotate(tr, angle);
            tr = CGAffineTransformTranslate(tr, -rbase.x, -rbase.y);
            CGRect r1, r2, r3, r4;
            r1.origin = CGPointApplyAffineTransform(rect.origin, tr);
            r2.origin = CGPointApplyAffineTransform(CGPointMake(rect.origin.x + rect.size.width, rect.origin.y), tr);
            r3.origin = CGPointApplyAffineTransform(CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height), tr);
            r4.origin = CGPointApplyAffineTransform(CGPointMake(rect.origin.x, rect.origin.y + rect.size.height), tr);
            r1.size = r2.size = r3.size = r4.size = CGSizeMake(0.01f, 0.01f);
            boundingBox = CGRectUnion(CGRectUnion(r1, r2), CGRectUnion(r3, r4));
        }
    }
    return self;
}

-(void)predraw:(CGContextRef)context scale:(CGFloat)scale
{
    if(predrawedText != nil) CGLayerRelease(predrawedText);
    NSMutableDictionary *heights = [[NSMutableDictionary alloc] initWithCapacity:[words count]];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, [NSColor blackColor], NSForegroundColorAttributeName, [NSColor whiteColor], NSBackgroundColorAttributeName, nil];
    CGSize size = CGSizeZero;
    for (NSString *w in words) {
        CGRect s = [w boundingRectWithSize:rect.size options:0 attributes:attributes];
        size.height += s.size.height;
        if(s.size.width > size.width) size.width = s.size.width;
        [heights setValue:[NSNumber numberWithInt:s.size.height] forKey:w];
    }
    predrawedText = CGLayerCreateWithContext(context, CGSizeMake(size.width*scale, size.height*scale), NULL);
    CGContextRef ctx = CGLayerGetContext(predrawedText);
    CGContextSaveGState(ctx);
    CGContextScaleCTM(ctx, scale, scale);
    int alignment = kCTTextAlignmentCenter;
    if(align & 0x4) alignment = kCTTextAlignmentLeft;
    else if(align & 0x8) alignment = kCTTextAlignmentRight;
    CGRect r = CGRectZero;
    r.size = size;
    for (NSString *w in words) {
        [w drawWithRect:r options:0 attributes:attributes];
        int height = [[heights valueForKey:w] intValue];
        r.origin.y += height;
        r.size.height -= height;
    }
    CGContextRestoreGState(ctx);
    switch (align & 0x3) {
        case 0x0:
            base.y = rect.origin.y + rect.size.height/2;
            offset.y = -size.height/2;
            break;
        case 0x1:
            base.y = rect.origin.y;
            offset.y = 0;
            break;
        case 0x2:
            base.y = rect.origin.y + rect.size.height;
            offset.y = -size.height;
            break;
    }
    switch (align & 0xc) {
        case 0x0:
            base.x = rect.origin.x + rect.size.width/2;
            offset.x = -size.width/2;
            break;
        case 0x4:
            base.x = rect.origin.x;
            offset.x = 0;
            break;
        case 0x8:
            base.x = rect.origin.x + rect.size.width;
            offset.x = -size.width;
            break;
    }
    rect.size = size;
    rect.origin = offset;
}

-(void)draw:(CGContextRef)context
{
    if(predrawedText) {
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, base.x, base.y);
        CGContextRotateCTM(context, angle);
        //CGContextTranslateCTM(context, offset.x, offset.y);
        CGContextDrawLayerInRect(context, rect, predrawedText);
        CGContextRestoreGState(context);
    } else {
        NSMutableDictionary *heights = [[NSMutableDictionary alloc] initWithCapacity:[words count]];
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, [NSColor blackColor], NSForegroundColorAttributeName, [NSColor clearColor], NSBackgroundColorAttributeName, nil];
        CGSize size = CGSizeZero;
        for (NSString *w in words) {
            CGRect s = [w boundingRectWithSize:rect.size options:0 attributes:attributes];
            size.height += s.size.height;
            if(s.size.width > size.width) size.width = s.size.width;
            [heights setValue:[NSNumber numberWithInt:s.size.height] forKey:w];
        }
        CGContextSaveGState(context);
        //CGContextScaleCTM(context, scale, scale);
        int alignment = kCTTextAlignmentCenter;
        if(align & 0x4) alignment = kCTTextAlignmentLeft;
        else if(align & 0x8) alignment = kCTTextAlignmentRight;
        CGRect r = CGRectZero;
        r.size = size;
        for (NSString *w in words) {
            //[w drawWithRect:r options:0 attributes:attributes];
            int height = [[heights valueForKey:w] intValue];
            r.origin.y += height;
            r.size.height -= height;
        }
        switch (align & 0x3) {
            case 0x0:
                base.y = rect.origin.y + rect.size.height/2;
                offset.y = -size.height/2;
                break;
            case 0x1:
                base.y = rect.origin.y;
                offset.y = 0;
                break;
            case 0x2:
                base.y = rect.origin.y + rect.size.height;
                offset.y = -size.height;
                break;
        }
        switch (align & 0xc) {
            case 0x0:
                base.x = rect.origin.x + rect.size.width/2;
                offset.x = -size.width/2;
                break;
            case 0x4:
                base.x = rect.origin.x;
                offset.x = 0;
                break;
            case 0x8:
                base.x = rect.origin.x + rect.size.width;
                offset.x = -size.width;
                break;
        }
        r.size = size;
        r.origin = offset;
        CGContextTranslateCTM(context, base.x, base.y);
        CGContextRotateCTM(context, angle);
        for (NSString *w in words) {
            int height = [[heights valueForKey:w] intValue];
            r.origin.y += height;
            r.size.height -= height;
            [w drawWithRect:r options:0 attributes:attributes];
        }
        CGContextRestoreGState(context);
    }
}

-(void)moveBy:(CGPoint)delta
{
    rect.origin.x += delta.x;
    rect.origin.y += delta.y;
    boundingBox.origin.x += delta.x;
    boundingBox.origin.y += delta.y;
    base.x += delta.x;
    base.y += delta.y;
}

-(void)dealloc
{
    CGLayerRelease(predrawedText);
}

-(id)copyWithZone:(NSZone*)zone
{
    ComplexText *t = [[[self class] allocWithZone:zone] init];
    if(t) {
        t->string = [string copyWithZone:zone];
        t->source = [source copyWithZone:zone];
        t->angle = angle;
        t->align = align;
        t->font = [font copyWithZone:zone];
        t->rect = rect;
        t->predrawedText = predrawedText;
        t->base = base;
        t->offset = offset;
        t->words = [words copyWithZone:zone];
        t->boundingBox = boundingBox;
    }
    return t;
}

@end

@implementation Transfer

@synthesize stations;
@synthesize time;
@synthesize boundingBox;
@synthesize active;

-(id)initWithMap:(CityMap*)cityMap
{
    if((self = [super init])) {
        map = cityMap;
        stations = [[NSMutableSet alloc] init];
        boundingBox = CGRectNull;
        time = 0;
        transferLayer = nil;
        active = YES;
    }
    return self;
}

-(void)dealloc
{
    CGLayerRelease(transferLayer);
}

-(void)addStation:(Station *)station
{
    if(station.transfer == self) return;
    NSAssert(station.transfer == nil, @"Station already in transfer");
    if([stations count] > 0) station.drawName = NO;
    station.transfer = self;
    [stations addObject:station];
    CGRect st = CGRectMake(station.pos.x - map->StationDiameter, station.pos.y - map->StationDiameter, map->StationDiameter*2.f, map->StationDiameter*2.f);
    if(CGRectIsNull(boundingBox)) boundingBox = st;
    else boundingBox = CGRectUnion(boundingBox, st);
}

-(void)removeStation:(Station *)station
{
    [stations removeObject:station];
    station.transfer = nil;
    if(station.drawName) {
        [(Station*)[stations anyObject] setDrawName:YES];
    } else {
        station.drawName = YES;
    }
    boundingBox = CGRectZero;
    for(Station *s in stations) {
        CGRect st = CGRectMake(station.pos.x - map->StationDiameter, station.pos.y - map->StationDiameter, map->StationDiameter*2.f, map->StationDiameter*2.f);
        if(CGRectIsNull(boundingBox)) boundingBox = st;
        else boundingBox = CGRectUnion(boundingBox, st);
    }
}

-(void) drawTransferLikeLondon:(CGContextRef) context stations:(NSArray*)sts
{
    NSMutableArray *coords = [NSMutableArray array];
    for (Station *st in sts) {
        [coords addObject:[NSValue valueWithPoint:st.pos]];
    }
    NSMutableArray *claster = nil;
    CGPoint clasterCenter = CGPointZero;
    const CGFloat D2 = map->StationDiameter*map->StationDiameter*1.5f;
    for (NSValue *v in coords) {
        NSMutableArray *cl = [NSMutableArray array];
        [cl addObject:v];
        CGPoint center = [v pointValue];
        CGPoint sum = center;
        for (NSValue *v2 in coords) {
            if(v != v2) {
                CGPoint p2 = [v2 pointValue];
                CGFloat d = sqr(p2.x-center.x) + sqr(p2.y-center.y);
                if(d < D2) {
                    [cl addObject:v2];
                    sum.x += p2.x;
                    sum.y += p2.y;
                    NSUInteger count = [cl count];
                    center.x = sum.x / count;
                    center.y = sum.y / count;
                }
            }
        }
        if(claster == nil || [claster count] < [cl count]) {
            claster = cl;
            clasterCenter = center;
            cl = nil;
        }
    }
    [coords removeObjectsInArray:claster];
    [coords addObject:[NSValue valueWithPoint:clasterCenter]];
    
    CGFloat blackW = map->StationDiameter / 5.f;
    CGContextSetRGBFillColor(context, 0.0, 0.0, 0.0, 1.0);
    CGContextSetRGBStrokeColor(context, 0.0, 0.0, 0.0, 1.0);				
    for(int i = 0; i<[coords count]; i++) {
        CGPoint p1 = [[coords objectAtIndex:i] pointValue];
        drawFilledCircle(context, p1.x, p1.y, map->StationDiameter);
        CGPoint nearest = CGPointZero;
        CGFloat dist = 0;
        for(int j = i+1; j<[coords count]; j++) {
            CGPoint p2 = [[coords objectAtIndex:j] pointValue];
            CGFloat d = sqr(p2.x-p1.x) + sqr(p2.y-p1.y);
            if(dist == 0 || dist > d) {
                nearest = p2;
                dist = d;
            }
        }
        if(dist != 0) 
            drawLine(context, p1.x, p1.y, nearest.x, nearest.y, map->StationDiameter*0.5f);
    }
    CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
    CGContextSetRGBStrokeColor(context, 1.0, 1.0, 1.0, 1.0);
    for(int i = 0; i<[coords count]; i++) {
        CGPoint p1 = [[coords objectAtIndex:i] pointValue];
        drawFilledCircle(context, p1.x, p1.y, map->StationDiameter - blackW);
        CGPoint nearest = CGPointZero;
        CGFloat dist = 0;
        for(int j = i+1; j<[coords count]; j++) {
            CGPoint p2 = [[coords objectAtIndex:j] pointValue];
            CGFloat d = sqr(p2.x-p1.x) + sqr(p2.y-p1.y);
            if(dist == 0 || dist > d) {
                nearest = p2;
                dist = d;
            }
        }
        if(dist != 0) 
            drawLine(context, p1.x, p1.y, nearest.x, nearest.y, map->StationDiameter*0.5f - blackW);
    }
}

-(void) drawTransferLikeParis:(CGContextRef)context stations:(NSArray*)sts drawTerminals:(BOOL)terminals
{
    CGFloat blackW = map->LineWidth / 3.f;
    CGContextSetRGBFillColor(context, 0.0, 0.0, 0.0, 1.0);
    CGContextSetRGBStrokeColor(context, 0.0, 0.0, 0.0, 1.0);				
    for(int i = 0; i<[sts count]; i++) {
        Station *st = [sts objectAtIndex:i];
        CGPoint p1 = st.pos;
        drawFilledCircle(context, p1.x, p1.y, map->LineWidth);
        for(int j = i+1; j<[sts count]; j++) {
            Station *st2 = [sts objectAtIndex:j];
            CGPoint p2 = st2.pos;
            CGFloat dx = (p1.x-p2.x);
            CGFloat dy = (p1.y-p2.y);
            CGFloat d2 = dx*dx + dy*dy;
            if(d2 > map->StationDiameter*map->StationDiameter*6) {
                drawFilledCircle(context, p2.x, p2.y, map->LineWidth);
                drawLine(context, p1.x, p1.y, p2.x, p2.y, map->LineWidth);
            } else
                drawLine(context, p1.x, p1.y, p2.x, p2.y, map->LineWidth*2);
        }
    }
    CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
    CGContextSetRGBStrokeColor(context, 1.0, 1.0, 1.0, 1.0);
    for(int i = 0; i<[sts count]; i++) {
        Station *st = [sts objectAtIndex:i];
        CGPoint p1 = st.pos;
        drawFilledCircle(context, p1.x, p1.y, map->LineWidth-blackW/2);
        for(int j = i+1; j<[sts count]; j++) {
            Station *st2 = [sts objectAtIndex:j];
            CGPoint p2 = st2.pos;
            CGFloat dx = (p1.x-p2.x);
            CGFloat dy = (p1.y-p2.y);
            CGFloat d2 = dx*dx + dy*dy;
            if(d2 > map->StationDiameter*map->StationDiameter*6) {
                drawFilledCircle(context, p2.x, p2.y, map->LineWidth-blackW/2);
                drawLine(context, p1.x, p1.y, p2.x, p2.y, map->LineWidth-blackW);
            } else 
                drawLine(context, p1.x, p1.y, p2.x, p2.y, map->LineWidth*2-blackW);
        }
    }
    if(terminals) for (Station *st in sts) {
        if(st.terminal) {
            CGPoint p1 = st.pos;
            CGFloat components[4];
            [st.line.color getComponents:components];
            CGContextSetRGBFillColor(context, *components, *(components+1), *(components+2), *(components+3));
            drawFilledCircle(context, p1.x, p1.y, map->LineWidth/2);
        }
    }
}

-(void) drawTransferLikeMoscow:(CGContextRef)context stations:(NSArray*)sts
{
    CGFloat blackW = map->LineWidth * 0.5f;
    CGContextSetRGBFillColor(context, 0.0, 0.0, 0.0, 0.6);
    CGContextSetRGBStrokeColor(context, 0.0, 0.0, 0.0, 0.6);				
    for(int i = 0; i<[sts count]; i++) {
        Station *st = [sts objectAtIndex:i];
        CGPoint p1 = st.pos;
        for(int j = i+1; j<[sts count]; j++) {
            Station *st2 = [sts objectAtIndex:j];
            CGPoint p2 = st2.pos;
            drawLine(context, p1.x, p1.y, p2.x, p2.y, map->LineWidth*2);
        }
    }
    CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
    CGContextSetRGBStrokeColor(context, 1.0, 1.0, 1.0, 1.0);
    for(int i = 0; i<[sts count]; i++) {
        Station *st = [sts objectAtIndex:i];
        CGPoint p1 = st.pos;
        for(int j = i+1; j<[sts count]; j++) {
            Station *st2 = [sts objectAtIndex:j];
            CGPoint p2 = st2.pos;
            drawLine(context, p1.x, p1.y, p2.x, p2.y, map->LineWidth*2-blackW);
        }
    }
    for (Station *st in stations) {
        CGPoint p1 = st.pos;
        CGFloat components[4];
        [st.line.color getComponents:components];
        CGContextSetRGBFillColor(context, *components, *(components+1), *(components+2), *(components+3));
        drawFilledCircle(context, p1.x, p1.y, map->LineWidth/2);
    }
}

-(void) drawTransferLikeHamburg:(CGContextRef)context stations:(NSArray*)sts
{
    CGRect r = CGRectZero;
    for (Station *s in sts) {
        CGRect r2 = CGRectMake(s.pos.x, s.pos.y, 0.0001, 0.0001);
        if(r.size.width == 0 && r.size.height == 0) r = r2;
        else r = CGRectUnion(r, r2);
    }
    CGFloat dd = map->StationDiameter - r.size.width;
    if(dd > 0) {
        r.size.width = map->StationDiameter;
        r.origin.x -= dd*0.5f;
    }
    dd = map->StationDiameter - r.size.height;
    if(dd > 0) {
        r.size.height = map->StationDiameter;
        r.origin.y -= dd * 0.5f;
    }
    CGContextSetRGBFillColor(context, 0.0f, 0.0f, 0.0f, 1.0f);
    CGContextFillRect(context, r);
    CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 1.0f);
    dd = 0.25f * map->LineWidth;
    r.origin.x += dd;
    r.origin.y += dd;
    r.size.width -= dd*2.f;
    r.size.height -= dd*2.f;
    CGContextFillRect(context, r);
}

-(void) drawTransferLikeVenice:(CGContextRef)context stations:(NSArray*)sts
{
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineWidth(context, 1.1f * map->LineWidth);
    for (Station *s in sts) {
        CGContextSaveGState(context);
        CGContextAddArc(context, s.pos.x, s.pos.y, map->StationDiameter, 0, M_2_PI, 1);
        CGContextClip(context);
        CGContextSetStrokeColorWithColor(context, CGColorCreateGenericRGB(1.f, 1.f, 1.f, 1.f));
        //CGContextSetFillColorWithColor(context, [s.line.color CGColor]);
        for (Segment *seg in s.segment) {
            [seg draw:context];
        }
        for (Segment *seg in s.backSegment) {
            [seg draw:context];
        }
        CGContextRestoreGState(context);
    }
}

-(void)draw:(CGContextRef)context
{
    if(transferLayer != nil) {
        CGContextDrawLayerInRect(context, boundingBox, transferLayer);
    } else {
        switch (map->TrKind) {
            case LIKE_LONDON:
                [self drawTransferLikeLondon:context stations:[stations allObjects]];
                break;
            case LIKE_PARIS:
                [self drawTransferLikeParis:context stations:[stations allObjects] drawTerminals:YES];
                break;
            case LIKE_MOSCOW:
                [self drawTransferLikeMoscow:context stations:[stations allObjects]];
                break;
            case LIKE_HAMBURG:
                [self drawTransferLikeHamburg:context stations:[stations allObjects]];
                break;
            case LIKE_VENICE:
                [self drawTransferLikeVenice:context stations:[stations allObjects]];
                break;
            case DONT_DRAW:
                break;
            case KINDS_NUM:
                NSAssert(NO, @"something went wrong...");
        }
    }
    for (Station *s in stations) {
        if(s.active) [s drawSelection:context];
    }
}

-(void)predraw:(CGContextRef)context
{
    if (transferLayer != nil) CGLayerRelease(transferLayer);
    CGSize size = CGSizeMake(boundingBox.size.width*map->PredrawScale, boundingBox.size.height*map->PredrawScale);
    transferLayer = CGLayerCreateWithContext(context, size, NULL);
    CGContextRef ctx = CGLayerGetContext(transferLayer);
    CGContextScaleCTM(ctx, map->PredrawScale, map->PredrawScale);
    CGContextTranslateCTM(ctx, -boundingBox.origin.x, -boundingBox.origin.y);
    switch (map->TrKind) {
        case LIKE_PARIS:
            [self drawTransferLikeParis:ctx stations:[stations allObjects] drawTerminals:YES];
            break;
        case LIKE_LONDON:
            [self drawTransferLikeLondon:ctx stations:[stations allObjects]];
            break;
        case LIKE_MOSCOW:
            [self drawTransferLikeMoscow:ctx stations:[stations allObjects]];
            break;
        case LIKE_HAMBURG:
            [self drawTransferLikeHamburg:ctx stations:[stations allObjects]];
            break;
        case LIKE_VENICE:
            [self drawTransferLikeVenice:ctx stations:[stations allObjects]];
            break;
        case DONT_DRAW:
            break;
        case KINDS_NUM:
            NSAssert(NO, @"something went wrong...");
    }
}

-(void) tuneStations
{
    if([stations count] == 2) {
        Station* s[2];
        int i=0;
        for (Station *st in stations) {
            s[i] = st;
            i++;
        }
        CGPoint A1 = s[0].pos, dA = s[0].tangent;
        CGPoint B1 = s[1].pos, dB = s[1].tangent;
        CGPoint dp = CGPointMake(A1.x - B1.x, A1.y - B1.y);
        CGFloat SD2 = map->StationDiameter*map->StationDiameter*4;
        if(SD2 >= (dp.x * dp.x + dp.y * dp.y)) {
            CGFloat d = dA.x * dB.y - dA.y * dB.x;
            if(d == 0.f) {
                //NSLog(@"lines are paraleled, %@", s[0].name);
                return; // parallel
            }
            //CGFloat d1 = (dp.x * dB.y - dp.y * dB.x) / d;
            CGFloat d2 = (dA.x * dp.y - dA.y * dp.x) / d;
            //CGPoint C1 = CGPointMake(A1.x + dA.x * d1, A1.y + dA.y * d1);
            CGPoint C2 = CGPointMake(B1.x + dB.x * d2, B1.y + dB.y * d2);
            dA = CGPointMake(C2.x - A1.x, C2.y - A1.y);
            if(SD2 < (dA.x * dA.x + dA.y * dA.y)) {
                return; // too far 
            }
            dB = CGPointMake(C2.x - B1.x, C2.y - B1.y);
            if(SD2 < (dB.x * dB.x + dB.y * dB.y)) {
                return; // too far
            }
            s[0].pos = C2;
            s[1].pos = C2;
            
            boundingBox = CGRectMake(C2.x - map->StationDiameter, C2.y - map->StationDiameter, map->StationDiameter*2.f, map->StationDiameter*2.f);
        }
    } else {
        //NSLog(@"more than two stations in transfer, %@", [[stations anyObject] name]);
    }
}

-(id)copyWithZone:(NSZone*)zone
{
    Transfer *t = [[[self class] allocWithZone:zone] init];
    if(t) {
        t->stations = stations;
        t->time = time;
        t->boundingBox = boundingBox;
        t->transferLayer = transferLayer;
        t->active = active;
        t->map = map;
        t->_deepCopy = nil;
    }
    return t;
}

-(id)superCopy
{
    if(_deepCopy == nil) {
        _deepCopy = [self copy];
        _deepCopy->stations = [NSMutableSet set];
        for(Station *s in stations) {
            [_deepCopy->stations addObject:[s superCopy]];
        }
    }
    return _deepCopy;
}

-(void)dropCopy
{
    _deepCopy = nil;
    for(Station *s in stations) {
        [s dropCopy];
    }
}

@end

@implementation Station

@synthesize relation;
@synthesize relationDriving;
@synthesize segment;
@synthesize backSegment;
@synthesize sibling;
@synthesize pos;
@synthesize boundingBox;
@synthesize textRect;
@synthesize tapArea;
@synthesize tapTextArea;
@synthesize index;
@synthesize name;
@synthesize driving;
@synthesize transfer;
@synthesize line;
@synthesize drawName;
@synthesize active;
@synthesize acceptBackLink;
@synthesize links;
@synthesize tangent;
@synthesize way1;
@synthesize way2;
@synthesize gpsCoords;
@synthesize forwardWay;
@synthesize backwardWay;
@synthesize firstStations;
@synthesize lastStations;
@synthesize altText;


- (NSString*)description
{
    return [NSString stringWithFormat:@"Station '%@' at line '%@'", name, line.name];
}

-(NSString*)nameSource
{
    return text.source;
}

-(void)setNameSource:(NSString *)nameSource
{
    //NSUInteger br = [nameSource rangeOfString:@"("].location;
    NSUInteger alternative = [nameSource rangeOfString:@"&"].location;
    if(alternative != NSNotFound) {
        altText = [[ComplexText alloc] initWithAlternativeString:nameSource font:[NSFont fontWithName:map->TEXT_FONT size:map->FontSize] andRect:textRect];
        bothText = [[ComplexText alloc] initWithBothString:nameSource font:[NSFont fontWithName:map->TEXT_FONT size:map->FontSize] andRect:textRect];
    }
    //if(br == NSNotFound) {
        text = [[ComplexText alloc] initWithString:nameSource font:[NSFont fontWithName:map->TEXT_FONT size:map->FontSize] andRect:textRect];
        name = text.string;
        tapTextArea = text.boundingBox;
    //}
}

-(BOOL) terminal { return links == 1; }

-(void) setPos:(CGPoint)_pos
{
    pos = _pos;
    boundingBox = CGRectMake(pos.x-map->StationDiameter/2, pos.y-map->StationDiameter/2, map->StationDiameter, map->StationDiameter);
}

-(id)initWithMap:(CityMap*)cityMap name:(NSString*)sname pos:(CGPoint)p index:(int)i rect:(CGRect)r andDriving:(NSString*)dr
{
    if((self = [super init])) {
        pos = p;
        map = cityMap;
        int SD = map->StationDiameter;
        boundingBox = CGRectMake(pos.x-SD/2, pos.y-SD/2, SD, SD);
        tapArea = CGRectMake(pos.x-SD, pos.y-SD, SD*2, SD*2);
        index = i;
        textRect = r;
        gpsCoords = CGPointZero;
        segment = [[NSMutableArray alloc] init];
        backSegment = [[NSMutableArray alloc] init];
        relation = [[NSMutableArray alloc] init];
        relationDriving = [[NSMutableArray alloc] init];
        sibling = [[NSMutableArray alloc] init];
        drawName = YES;
        active = YES;
        acceptBackLink = YES;
        transferDriving = [[NSMutableDictionary alloc] init];
        defaultTransferDriving = 0;
        transferWay = [[NSMutableDictionary alloc] init];
        reverseTransferWay = [[NSMutableDictionary alloc] init];
        defaultTransferWay = NOWAY;
        forwardWay = [[NSMutableArray alloc] init];
        backwardWay = [[NSMutableArray alloc] init];
        firstStations = [[NSMutableArray alloc] init];
        lastStations = [[NSMutableArray alloc] init];
        
        NSUInteger br = [sname rangeOfString:@"("].location;
        NSUInteger alternative = [sname rangeOfString:@"&"].location;
        if(alternative != NSNotFound) {
            altText = [[ComplexText alloc] initWithAlternativeString:sname font:[NSFont fontWithName:map->TEXT_FONT size:map->FontSize] andRect:textRect];
            bothText = [[ComplexText alloc] initWithBothString:sname font:[NSFont fontWithName:map->TEXT_FONT size:map->FontSize] andRect:textRect];
        }
        if(br == NSNotFound) {
            text = [[ComplexText alloc] initWithString:sname font:[NSFont fontWithName:map->TEXT_FONT size:map->FontSize] andRect:textRect];
            name = text.string;
            tapTextArea = text.boundingBox;
        } else {
            text = [[ComplexText alloc] initWithString:[sname substringToIndex:br] font:[NSFont fontWithName:map->TEXT_FONT size:map->FontSize] andRect:textRect];
            name = text.string;
            tapTextArea = text.boundingBox;
            NSArray *components = [[sname substringFromIndex:br+1] componentsSeparatedByString:@","];
            if([components count] > 1) acceptBackLink = NO;
            for (NSString* s in components) {
                if([s length] == 0) continue;
                if([s characterAtIndex:0] == '-')
                    [relation addObject:[s substringFromIndex:1]];
                else
                    [relation addObject:s];
            }
        }
        if(dr == nil) driving = 0;
        else {
            br = [dr rangeOfString:@"("].location;
            if(br == NSNotFound) {
                driving = [dr intValue];
            } else {
                driving = [[dr substringToIndex:br] intValue];
                for (NSString *s in [[dr substringFromIndex:br+1] componentsSeparatedByString:@","]) {
                    if([s length] == 0) continue;
                    int drv = [s intValue];
                    NSAssert(drv > 0, @"zero driving!");
                    [relationDriving addObject:[NSNumber numberWithInt:drv]];
                }
            }
        }
    }
    return self;
}

-(BOOL)addSibling:(Station *)st
{
    for (Station *s in sibling) {
        if(s == st) return NO;
    }
    [sibling addObject:st];
    return YES;
}

-(void) drawSegments:(CGContextRef)context inRect:(CGRect)rect
{
    for (Segment *s in segment) {
        if(CGRectIntersectsRect(rect, s.boundingBox))
            [s draw:context];
    }
}

-(void)drawName:(CGContextRef)context
{
    switch (map->DrawName) {
        default:
        case NAME_NORMAL:
            [text draw:context];
            break;
        case NAME_ALTERNATIVE:
            [altText draw:context];
            break;
        case NAME_BOTH:
            [bothText draw:context];
            break;
    }
    if(active) drawSelectionRect(context, tapTextArea);
}

-(void)drawStation:(CGContextRef)context
{
    if(map->StKind == LIKE_LONDON) {
        CGContextSetLineCap(context, kCGLineCapSquare);
        CGFloat lw = map->LineWidth * 0.5f;
        CGContextSetLineWidth(context, map->LineWidth);
        CGPoint p = CGPointMake(pos.x + lw*normal.x, pos.y + lw*normal.y);
        CGContextMoveToPoint(context, p.x, p.y);
        CGContextAddLineToPoint(context, p.x + normal.x, p.y + normal.y);
        CGContextStrokePath(context);
    } else if(map->StKind == LIKE_HAMBURG) {
        CGContextSaveGState(context);
        CGContextSetStrokeColorWithColor(context, CGColorCreateGenericRGB(1.f, 1.f, 1.f, 1.f));
        CGContextSetLineCap(context, kCGLineCapSquare);
        CGFloat lw = map->LineWidth * 0.5f;
        CGContextSetLineWidth(context, lw);
        CGPoint p = CGPointMake(pos.x + lw*normal.x, pos.y + lw*normal.y);
        CGContextMoveToPoint(context, pos.x, pos.y);
        CGContextAddLineToPoint(context, p.x, p.y);
        CGContextStrokePath(context);
        CGContextRestoreGState(context);
    }
    if(active) [self drawSelection:context];
}

-(void)drawSelection:(CGContextRef)context
{
    drawSelectionRect(context, tapArea);
}

-(void)predraw:(CGContextRef) context
{
    [text predraw:context scale:map->PredrawScale];
    [altText predraw:context scale:map->PredrawScale];
    [bothText predraw:context scale:map->PredrawScale];
}

-(void) makeSegments
{
    int drv = -1;
    if([relationDriving count] > 0) drv = 0;
    for(int i=0; i<[sibling count]; i++) {
        Station *st = [sibling objectAtIndex:i];
        int curDrv = driving;
        if(drv >= 0) curDrv = [[relationDriving objectAtIndex:drv] intValue];
        [segment addObject:[[Segment alloc] initFromStation:self toStation:st withDriving:curDrv]];
        if(drv < [relationDriving count]-1) drv ++;
    }
    if(!driving && [relationDriving count]) driving = [[relationDriving objectAtIndex:0] intValue];
    relationDriving = nil;
    relation = nil;
    sibling = nil;
}

-(void) makeTangent
{
    CGPoint fp = CGPointZero, bp = CGPointZero;
    BOOL preferFrontPoint = NO, preferBackPoint = NO;
    if([segment count] > 0) {
        for (Segment *seg in segment) {
            if([seg.linePoints count] == 0) {
                fp = seg.end.pos;
                preferFrontPoint = YES;
                break;
            }
        }
        if(!preferFrontPoint) {
            Segment *s = [segment objectAtIndex:0];
            fp = [[s.linePoints objectAtIndex:0] pointValue];
        }
    } 
    if([backSegment count] > 0) {
        for (Segment *seg in backSegment) {
            if([seg.linePoints count] == 0) {
                bp = seg.start.pos;
                preferBackPoint = YES;
                break;
            }
        }
        if(!preferBackPoint) {
            Segment *s = [backSegment objectAtIndex:0];
            bp = [[s.linePoints lastObject] pointValue];
        }
    } 
    if(preferFrontPoint || CGPointEqualToPoint(bp, CGPointZero)) 
        tangent = CGPointMake(fp.x - pos.x, fp.y - pos.y);
    else
        tangent = CGPointMake(pos.x - bp.x, pos.y - bp.y);
    normal = CGPointMake(tangent.y, -tangent.x);
    CGPoint td = CGPointMake(textRect.origin.x - pos.x, textRect.origin.y - pos.y);
    CGFloat ntd = normal.x * td.x + normal.y * td.y;
    if(ntd < 0.f) {
        normal = CGPointMake(-normal.x, -normal.y);
    }
    ntd = normal.x * normal.x + normal.y * normal.y;
    ntd = sqrtf(ntd);
    normal.x /= ntd;
    normal.y /= ntd;
}

-(void)setTransferDriving:(CGFloat)_driving to:(Station *)target
{
    if(defaultTransferDriving == 0) defaultTransferDriving = _driving;
    [transferDriving setObject:[NSNumber numberWithFloat:_driving] forKey:target];
}

-(void)setTransferWay:(int)way to:(Station *)target
{
    if(defaultTransferWay == NOWAY) defaultTransferWay = way;
    [transferWay setObject:[NSNumber numberWithInt:way] forKey:target];
}

-(void)setTransferWay:(int)way from:(Station *)target
{
    [reverseTransferWay setObject:[NSNumber numberWithInt:way] forKey:target];
}

-(void)setTransferWays:(NSArray *)ways to:(Station *)target
{
    [transferWay setObject:ways forKey:target];
}

-(CGFloat)transferDrivingTo:(Station *)target
{
    NSNumber *dr = [transferDriving objectForKey:target];
    if(dr != nil) return [dr floatValue];
    return defaultTransferDriving;
}

-(int)transferWayTo:(Station *)target
{
    id w = [transferWay objectForKey:target];
    if(w == nil) return defaultTransferWay;
    if([w isKindOfClass:[NSArray class]]) return [[w objectAtIndex:0] intValue];
    else if ([w isKindOfClass:[NSNumber class]]) return [w intValue];
    return defaultTransferWay;
}

-(int)transferWayFrom:(Station *)target
{
    NSNumber *w = [reverseTransferWay objectForKey:target];
    if(w != nil) return [w intValue];
    return NOWAY;
}

-(BOOL)checkForwardWay:(Station *)st
{
    if([forwardWay containsObject:st]) return true;
    if([backwardWay containsObject:st]) return false;
    // unknown way!
#ifdef DEBUG
    NSLog(@"Warning: unknown way from %@ to %@", name, st.name);
#endif
    return false;
}

-(int)megaTransferWayFrom:(Station *)prevStation to:(Station *)transferStation
{
    NSArray *ways = [transferWay objectForKey:transferStation];
    if(ways == nil) {
#ifdef DEBUG
        NSLog(@"no way from %@ to %@", name, transferStation.name);
#endif
        return NOWAY;
    }
    BOOL prevForwardWay = [prevStation checkForwardWay:self];
    if(prevForwardWay) {
        // we should choose one from first and second transfer ways
        return [[ways objectAtIndex:0] intValue];  // or 1
    } else {
        // choose from third and fourth ways
        return [[ways objectAtIndex:2] intValue]; // or 3
    }
}

-(int) megaTransferWayFrom:(Station *)prevStation to:(Station *)transferStation andNextStation:(Station *)nextStation
{
    NSArray *ways = [transferWay objectForKey:transferStation];
    if(ways == nil) {
#ifdef DEBUG
        NSLog(@"no way from %@ to %@", name, transferStation.name);
#endif
        return NOWAY;
    }
    BOOL prevForwardWay = [prevStation checkForwardWay:self];
    BOOL nextForwardWay = [transferStation checkForwardWay:nextStation];
    if(prevForwardWay && nextForwardWay) return [[ways objectAtIndex:0] intValue];
    else if(prevForwardWay && !nextForwardWay) return [[ways objectAtIndex:1] intValue];
    else if(!prevForwardWay && nextForwardWay) return [[ways objectAtIndex:2] intValue];
    else if(!prevForwardWay && !nextForwardWay) return [[ways objectAtIndex:3] intValue];
    return [[ways lastObject] intValue];
}

-(void) cleanup
{
    [forwardWay removeAllObjects];
    [backwardWay removeAllObjects];
    [transferWay removeAllObjects];
    [reverseTransferWay removeAllObjects];
    [transferDriving removeAllObjects];
    [firstStations removeAllObjects];
    [lastStations removeAllObjects];
}

-(void) moveBy:(CGPoint)delta
{
    pos.x += delta.x;
    pos.y += delta.y;
    boundingBox.origin.x += delta.x;
    boundingBox.origin.y += delta.y;
    textRect.origin.x += delta.x;
    textRect.origin.y += delta.y;
    tapArea.origin.x += delta.x;
    tapArea.origin.y += delta.y;
    tapTextArea.origin.x += delta.x;
    tapTextArea.origin.y += delta.y;
    [text moveBy:delta];
    [altText moveBy:delta];
    [bothText moveBy:delta];
    for (Segment *s in segment) {
        [s prepare];
    }
    for (Segment *s in backSegment) {
        [s prepare];
    }
}

-(void) moveTextBy:(CGPoint)delta
{
    textRect.origin.x += delta.x;
    textRect.origin.y += delta.y;
    tapTextArea.origin.x += delta.x;
    tapTextArea.origin.y += delta.y;
    [text moveBy:delta];
    [altText moveBy:delta];
    [bothText moveBy:delta];
}

-(id)copyWithZone:(NSZone*)zone
{
    return self;
}

-(id)simpleCopy
{
    Station *s = [[[self class] alloc] init];
    if(s) {
        s->pos = pos;
        s->boundingBox = boundingBox;
        s->textRect = textRect;
        s->tapArea = tapArea;
        s->tapTextArea = tapTextArea;
        s->index = index;
        s->driving = driving;
        s->name = name;
        s->segment = segment;
        s->backSegment = backSegment;
        s->sibling = sibling;
        s->relation = relation;
        s->relationDriving = relationDriving;
        s->transfer = transfer;
        s->line = line;
        s->drawName = drawName;
        s->active = active;
        s->acceptBackLink = acceptBackLink;
        s->links = links;
        s->tangent = tangent;
        s->normal = normal;
        s->map = map;
        s->text = text;
        s->altText = altText;
        s->bothText = bothText;
        s->way1 = way1;
        s->way2 = way2;
        s->transferDriving = transferDriving;
        s->defaultTransferDriving = defaultTransferDriving;
        s->transferWay = transferWay;
        s->reverseTransferWay = reverseTransferWay;
        s->defaultTransferWay = defaultTransferWay;
        s->gpsCoords = gpsCoords;
        s->forwardWay = forwardWay;
        s->backwardWay = backwardWay;
        s->firstStations = firstStations;
        s->lastStations = lastStations;
        s->_deepCopy = nil;
    }
    return s;
}

-(id)superCopy
{
    if(_deepCopy == nil) {
        _deepCopy = [self simpleCopy];
        _deepCopy->name = [name copy];
        _deepCopy->segment = [NSMutableArray array];
        for(Segment *s in segment) {
            [_deepCopy->segment addObject:[s superCopy]];
        }
        _deepCopy->backSegment = [NSMutableArray array];
        for(Segment *s in backSegment) {
            [_deepCopy->backSegment addObject:[s superCopy]];
        }
//        if(sibling != nil) {
//            _deepCopy->sibling = [NSMutableArray array];
//            for (Station *st in sibling) {
//                [_deepCopy->sibling addObject:st];
//            }
//        }
        // relation
        // relationDriving
        _deepCopy->transfer = [transfer superCopy];
        _deepCopy->line = [line superCopy];
        _deepCopy->text = [text copy];
        _deepCopy->altText = [altText copy];
        _deepCopy->bothText = [bothText copy];
        _deepCopy->transferDriving = [NSMutableDictionary dictionary];
        for(Station *s in [transferDriving allKeys]) {
            [_deepCopy->transferDriving setObject:[transferDriving objectForKey:s] forKey:[s superCopy]];
        }
        _deepCopy->transferWay = [NSMutableDictionary dictionary];
        for(Station *s in [transferWay allKeys]) {
            [_deepCopy->transferWay setObject:[transferWay objectForKey:s] forKey:[s superCopy]];
        }
        _deepCopy->reverseTransferWay = [NSMutableDictionary dictionary];
        for(Station *s in [reverseTransferWay allKeys]) {
            [_deepCopy->reverseTransferWay setObject:[reverseTransferWay objectForKey:s] forKey:[s superCopy]];
        }
        _deepCopy->forwardWay = [NSMutableArray array];
        for (Station *s in forwardWay) {
            [_deepCopy->forwardWay addObject:[s superCopy]];
        }
        _deepCopy->backwardWay = [NSMutableArray array];
        for (Station *s in backwardWay) {
            [_deepCopy->backwardWay addObject:[s superCopy]];
        }
        _deepCopy->firstStations = [NSMutableArray array];
        for (Station *s in firstStations) {
            [_deepCopy->firstStations addObject:[s superCopy]];
        }
        _deepCopy->lastStations = [NSMutableArray array];
        for (Station *s in lastStations) {
            [_deepCopy->lastStations addObject:[s superCopy]];
        }
    }
    return _deepCopy;
}

-(void)dropCopy
{
    if(_deepCopy == nil) return;
    _deepCopy = nil;
    for (Segment *s in segment) {
        [s dropCopy];
    }
    for (Segment *s in backSegment) {
        [s dropCopy];
    }
    for (Station *s in forwardWay) {
        [s dropCopy];
    }
    for (Station *s in backwardWay) {
        [s dropCopy];
    }
    for (Station *s in firstStations) {
        [s dropCopy];
    }
    for (Station *s in lastStations) {
        [s dropCopy];
    }
}

@end

@implementation TangentPoint

@synthesize base;
@synthesize backTang;
@synthesize frontTang;

-(id)initWithPoint:(CGPoint)p
{
    if((self = [super init])) {
        base = p;
    }
    return self;
}

-(void)calcTangentFrom:(CGPoint)p1 to:(CGPoint)p2
{
    CGFloat x = (1 + (Sql(base, p1) - Sql(base, p2)) / Sql(p1, p2)) / 2;
    CGPoint d = CGPointMake(p1.x + (p2.x-p1.x) * x, p1.y + (p2.y-p1.y) * x);
    
    frontTang = CGPointMake(base.x + (p2.x-d.x)/3, base.y + (p2.y-d.y)/3);
    backTang = CGPointMake(base.x + (p1.x-d.x)/3, base.y + (p1.y-d.y)/3);
}
@end

@implementation Segment

@synthesize start;
@synthesize end;
@synthesize driving;
@synthesize boundingBox;
@synthesize active;
@synthesize isSpline;
@synthesize splinePoints, linePoints;

- (NSString*)description
{
    return [NSString stringWithFormat:@"Segment from '%@' to '%@' at line '%@'", start.name, end.name, start.line.name];
}

-(id)initFromStation:(Station *)from toStation:(Station *)to withDriving:(int)dr
{
    if((self = [super init])) {
        active = YES;
        isSpline = NO;
        start = from;
        end = to;
        [end.backSegment addObject:self];
        driving = dr;
        //NSAssert(driving > 0, @"illegal driving");
#ifdef DEBUG
        if(driving <= 0) NSLog(@"zero driving from %@ to %@", from.name, to.name);
#endif
        start.links ++;
        end.links ++;
    }
    return self;
}

-(void)dealloc
{
    CGPathRelease(path);
}

-(void)setIsSpline:(BOOL)isSp
{
    if(isSp != isSpline) {
        isSpline = isSp;
        [self prepare];
    }
}

-(void)appendPoint:(CGPoint)p
{
    if(linePoints == nil) linePoints = [[NSMutableArray alloc] initWithObjects:[NSValue valueWithPoint:p], nil];
    else [linePoints addObject:[NSValue valueWithPoint:p]];
}

-(void)removePoint:(int)index
{
    [linePoints removeObjectAtIndex:index];
}

-(void)prepare
{
    CGRect s1 = CGRectMake(start.pos.x - 5, start.pos.y - 5, 10, 10);
    CGRect s2 = CGRectMake(end.pos.x - 5, end.pos.y - 5, 10, 10);
    boundingBox = CGRectUnion(s1, s2);
    for (NSValue *v in linePoints) {
        CGPoint p = [v pointValue];
        CGRect r = CGRectMake(p.x - 5, p.y - 5, 10, 10);
        boundingBox = CGRectUnion(boundingBox, r);
    }
    if(linePoints == nil || [linePoints count] == 0) {
        if(path != nil) CGPathRelease(path);
        [splinePoints removeAllObjects];
        path = nil;
        linePoints = nil;
        splinePoints = nil;
        return;
    }
    if(!isSpline) {
        [self predrawMultiline];
        return;
    }
    NSMutableArray *linePoints2 = [linePoints mutableCopy];
    [linePoints2 addObject:[NSValue valueWithPoint:CGPointMake(end.pos.x, end.pos.y)]];
    [linePoints2 insertObject:[NSValue valueWithPoint:CGPointMake(start.pos.x, start.pos.y)] atIndex:0];
    if(splinePoints == nil)
        splinePoints = [[NSMutableArray alloc] init];
    else
        [splinePoints removeAllObjects];
    for(int i=1; i<[linePoints2 count]-1; i++) {
        TangentPoint *p = [[TangentPoint alloc] initWithPoint:[[linePoints2 objectAtIndex:i] pointValue]];
        [p calcTangentFrom:[[linePoints2 objectAtIndex:i-1] pointValue] to:[[linePoints2 objectAtIndex:i+1] pointValue]];
        [splinePoints addObject:p];
    }
    [self predrawSpline];
}

-(void)draw:(CGContextRef)context fromPoint:(CGPoint)p toTangentPoint:(TangentPoint*)tp
{
    CGContextMoveToPoint(context, tp.base.x, tp.base.y);
    CGContextAddQuadCurveToPoint(context, tp.backTang.x, tp.backTang.y, p.x, p.y);
    CGContextStrokePath(context);
}

-(void)draw:(CGContextRef)context fromTangentPoint:(TangentPoint*)tp toPoint:(CGPoint)p
{
    CGContextMoveToPoint(context, tp.base.x, tp.base.y);
    CGContextAddQuadCurveToPoint(context, tp.frontTang.x, tp.frontTang.y, p.x, p.y);
    CGContextStrokePath(context);
}

-(void)draw:(CGContextRef)context fromTangentPoint:(TangentPoint*)tp1 toTangentPoint:(TangentPoint*)tp2
{
    CGContextMoveToPoint(context, tp1.base.x, tp1.base.y);
    CGContextAddCurveToPoint(context, tp1.frontTang.x, tp1.frontTang.y, tp2.backTang.x, tp2.backTang.y, tp2.base.x, tp2.base.y);
    CGContextStrokePath(context);
}

-(void)draw:(CGContextRef)context
{
    if(linePoints) {
        CGContextMoveToPoint(context, 0, 0);
        CGContextAddPath(context, path);
        CGContextStrokePath(context);
        for (NSValue *v in linePoints) {
            CGPoint p = [v pointValue];
            CGRect r = CGRectMake(p.x-7, p.y-7, 14, 14);
            drawSelectionRect(context, r);
        }
    } else {
        CGContextMoveToPoint(context, start.pos.x, start.pos.y);
        CGContextAddLineToPoint(context, end.pos.x, end.pos.y);
        CGContextStrokePath(context);
    }
}

-(void)predraw
{
    if(isSpline) [self predrawSpline];
    else [self predrawMultiline];
}

-(void)predrawMultiline
{
    if(linePoints) {
        if(path != nil) CGPathRelease(path);
        path = CGPathCreateMutable();
        CGPathMoveToPoint(path, nil, start.pos.x, start.pos.y);
        for (int i=0; i < [linePoints count]; i++) {
            CGPoint p = [[linePoints objectAtIndex:i] pointValue];
            CGPathAddLineToPoint(path, nil, p.x, p.y);
        }
        CGPathAddLineToPoint(path, nil, end.pos.x, end.pos.y);
    }
}

-(void)predrawSpline
{
    if(splinePoints) {
        if(path != nil) CGPathRelease(path);
        path = CGPathCreateMutable();
        TangentPoint *tp1 = [splinePoints objectAtIndex:0], *tp2 = nil;
        CGPathMoveToPoint(path, nil, tp1.base.x, tp1.base.y);
        CGPathAddQuadCurveToPoint(path, nil, tp1.backTang.x, tp1.backTang.y, start.pos.x, start.pos.y);
        CGPathMoveToPoint(path, nil, tp1.base.x, tp1.base.y);
        for(int i=0; i<[splinePoints count]-1; i++) {
            tp1 = [splinePoints objectAtIndex:i];
            tp2 = [splinePoints objectAtIndex:i+1];
            CGPathAddCurveToPoint(path, nil, tp1.frontTang.x, tp1.frontTang.y, tp2.backTang.x, tp2.backTang.y, tp2.base.x, tp2.base.y);
        }
        tp2 = [splinePoints lastObject];
        CGPathAddQuadCurveToPoint(path, nil, tp2.frontTang.x, tp2.frontTang.y, end.pos.x, end.pos.y);
    }
}

-(void)movePoint:(int)index by:(CGPoint)delta
{
    NSValue *v = [linePoints objectAtIndex:index];
    NSPoint p = [v pointValue];
    p.x += delta.x;
    p.y += delta.y;
    [linePoints removeObjectAtIndex:index];
    [linePoints insertObject:[NSValue valueWithPoint:p] atIndex:index];
    [self prepare];
}

-(id)copyWithZone:(NSZone*)zone
{
    Segment *s = [[[self class] allocWithZone:zone] init];
    if(s) {
        s->start = start;
        s->end = end;
        s->driving = driving;
        s->linePoints = linePoints;
        s->splinePoints = splinePoints;
        s->boundingBox = boundingBox;
        s->active = active;
        s->isSpline = isSpline;
        s->path = nil;
        s->_deepCopy = nil;
    }
    return s;
}

-(id)superCopy
{
    if(_deepCopy == nil) {
        _deepCopy = [self copy];
        _deepCopy->start = [start superCopy];
        _deepCopy->end = [end superCopy];
        _deepCopy->linePoints = [linePoints mutableCopy];
        _deepCopy->splinePoints = [splinePoints mutableCopy];
        [_deepCopy prepare];
    }
    return _deepCopy;
}

-(void)dropCopy
{
    _deepCopy = nil;
    [start dropCopy];
    [end dropCopy];
}

@end

@implementation Line

@synthesize name;
@synthesize stations;
@synthesize index;
@synthesize boundingBox;
@synthesize shortName;
@synthesize stationLayer;
@synthesize disabledStationLayer;
@synthesize hasAltNames;
@synthesize shortColorCode = scc;
@synthesize pinColor = _pinColor;

-(NSColor*) color {
    return _color;
}

-(void) setColor:(NSColor *)color
{
    _color = color;
    CGFloat r, g, b, M, m, sd;
    CGFloat rgba[4];
    [color getComponents:rgba];
    r = rgba[0];
    g = rgba[1];
    b = rgba[2];
    
    //short color code
    if(r > 0.66f) {
        if(b > 0.66f) {
            scc = 4;
        } else {
            if(g > 0.66f) {
                scc = 8;
            } else {
                scc = 5;
            }
        }
    } else {
        if(b > 0.66f) {
            if(g > 0.66f) {
                scc = 1;
            } else if(g > 0.33f) {
                scc = 3;
            } else {
                scc = 6;
            }
        } else {
            if(g > 0.66f) {
                scc = 7;
            } else {
                scc = 2;
            }
        }
    }

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
    
    _disabledColor = [NSColor colorWithCIColor:[CIColor colorWithRed:r green:g blue:b]];
    
}

-(void)setName:(NSString *)n
{
    name = n;
    shortName = [[n componentsSeparatedByString:@" "] lastObject];
}

-(void)postInit
{
    for(Station *st in stations) {
        [st makeSegments];
        boundingBox = CGRectUnion(boundingBox, st.boundingBox);
        boundingBox = CGRectUnion(boundingBox, st.textRect);
        for (Segment *seg in st.segment) {
            boundingBox = CGRectUnion(boundingBox, seg.boundingBox);
        }
    }
}

-(void)updateBoundingBox
{
    boundingBox = CGRectZero;
    for(Station *st in stations) {
        boundingBox = CGRectUnion(boundingBox, st.boundingBox);
        boundingBox = CGRectUnion(boundingBox, st.textRect);
        for (Segment *seg in st.segment) {
            boundingBox = CGRectUnion(boundingBox, seg.boundingBox);
        }
    }
}

-(id)initWithMap:(CityMap*)cityMap andName:(NSString*)n
{
    if((self = [super init])) {
        map = cityMap;
        name = n;
        shortName = [[n componentsSeparatedByString:@" "] lastObject];
        stations = [[NSMutableArray alloc] init];
        stationLayer = nil;
        boundingBox = CGRectNull;
        twoStepsDraw = NO;
    }
    return self;
}

-(id)initWithMap:(CityMap*)cityMap name:(NSString*)n stations:(NSString *)station driving:(NSString *)driving coordinates:(NSString *)coordinates rects:(NSString *)rects
{
    if((self = [super init])) {
        map = cityMap;
        name = n;
        shortName = [[n componentsSeparatedByString:@" "] lastObject];
        stations = [[NSMutableArray alloc] init];
        stationLayer = nil;
        boundingBox = CGRectNull;
        twoStepsDraw = NO;
        NSArray *sts = Split(station);
        NSArray *drs = Split(driving);
        NSArray *crds = [coordinates componentsSeparatedByString:@", "];
        NSArray *rcts = [rects componentsSeparatedByString:@", "];
        NSInteger count = MIN( MIN([sts count], [crds count]), [rcts count]);
        for(int i=0; i<count; i++) {
            NSArray *coord_x_y = [[crds objectAtIndex:i] componentsSeparatedByString:@","];
            int x = [[coord_x_y objectAtIndex:0] intValue];
            int y = [[coord_x_y objectAtIndex:1] intValue];
            NSArray *coord_text = [[rcts objectAtIndex:i] componentsSeparatedByString:@","];
            int tx = [[coord_text objectAtIndex:0] intValue];
            int ty = [[coord_text objectAtIndex:1] intValue];
            int tw = [[coord_text objectAtIndex:2] intValue];
            int th = [[coord_text objectAtIndex:3] intValue];
            
            NSString* drv = nil;
            if(i < [drs count]) drv = [drs objectAtIndex:i];
            Station *st = [[Station alloc] initWithMap:map name:[sts objectAtIndex:i] pos:CGPointMake(x, y) index:i rect:CGRectMake(tx, ty, tw, th) andDriving:drv];
            if(st.altText != nil) hasAltNames = YES;
            st.line = self;
            Station *last = [stations lastObject];
            if([st.relation count] < [st.relationDriving count]) {
                if(last.driving == 0) last.driving = [[st.relationDriving lastObject] intValue];
                [st.relationDriving removeLastObject];
            }
            if(st.acceptBackLink && [stations count]) {
                // создаём простые связи
                [last addSibling:st];
            }
            [stations addObject:st];
#ifdef DEBUG
            NSLog(@"read station: %@", st.name);
#endif

//            MStation *station = [NSEntityDescription insertNewObjectForEntityForName:@"Station" inManagedObjectContext:[MHelper sharedHelper].managedObjectContext];
//            station.name=st.name;
//            station.isFavorite=[NSNumber numberWithInt:0];
//            station.lines=[[MHelper sharedHelper] lineByName:name ];
//            station.index = [NSNumber numberWithInt:i];
        }
        // создаём отложенные связи
        for (Station *st in stations) {
            for(NSString *rel in st.relation) {
                for(Station *st2 in stations) {
                    if([st2.name isEqualToString:rel]) {
                        BOOL alreadyLinked = NO;
                        for (Station *st3 in st2.sibling) {
                            if(st3 == st) {
                                alreadyLinked = YES;
                                break;
                            }
                        }
                        if(!alreadyLinked) [st addSibling:st2];
                        break;
                    }
                }
            }
            [st.relation removeAllObjects];
        }
        [self postInit];
    }
    return self;
}

-(void)dealloc
{
    for (Station* s in stations) {
        [s cleanup];
    }
    CGLayerRelease(stationLayer);
    CGLayerRelease(disabledStationLayer);
}

-(void)draw:(CGContextRef)context inRect:(CGRect)rect
{
    CGContextSetLineCap(context, kCGLineCapRound);

    // all line is active
    CGFloat components[4];
    [_color getComponents:components];
    CGContextSetRGBStrokeColor(context, *components, *(components+1), *(components+2), *(components+3));
    //CGContextSetFillColorWithColor(context, [_color CGColor]);
    CGContextSetLineWidth(context, map->LineWidth);
    for (Station *s in stations) {
        [s drawSegments:context inRect:rect];
    }
    for (Station *s in stations) {
        if(s.transfer == nil && CGRectIntersectsRect(rect, s.tapArea)) {
            if(map->StKind == LIKE_LONDON || map->StKind == LIKE_HAMBURG)
                [s drawStation:context];
            else {
                //CGContextDrawLayerInRect(context, s.boundingBox, stationLayer);
                CGContextSaveGState(context);
                [self drawNormalStationMark:context rect:s.boundingBox];
                if(s.active) [s drawSelection:context];
                CGContextRestoreGState(context);
            }
        }
    }
}

-(void)drawActive:(CGContextRef)context inRect:(CGRect)rect
{
    CGFloat components[4];
    [_color getComponents:components];
    CGContextSetRGBStrokeColor(context, *components, *(components+1), *(components+2), *(components+3));
    CGContextSetLineWidth(context, map->LineWidth);
    for (Station *s in stations) {
        for (Segment *seg in s.segment) {
            if(seg.active && CGRectIntersectsRect(rect, seg.boundingBox))
                [seg draw:context];
        }
    }
    CGContextSetStrokeColorWithColor(context, CGColorCreateGenericRGB(0.2f, 0.2f, 0.2f, 1.f));
    CGContextSetLineWidth(context, map->LineWidth*0.25f);
    for (Station *s in stations) {
        for (Segment *seg in s.segment) {
            if(seg.active && CGRectIntersectsRect(rect, seg.boundingBox))
                [seg draw:context];
        }
    }
    for (Station *s in stations) {
        if(s.active && s.transfer == nil && CGRectIntersectsRect(rect, s.boundingBox)) {
            if(map->StKind == LIKE_LONDON || map->StKind == LIKE_HAMBURG)
                [s drawStation:context];
            else {
                //CGContextDrawLayerInRect(context, s.boundingBox, stationLayer);
                CGContextSaveGState(context);
                [self drawNormalStationMark:context rect:s.boundingBox];
                CGContextRestoreGState(context);
            }
        }
    }
}

-(void)drawNames:(CGContextRef)context inRect:(CGRect)rect
{
    for (Station *s in stations) {
        if(s.drawName && CGRectIntersectsRect(s.tapTextArea, rect))
            [s drawName:context];
    }
}

-(id)activateSegmentFrom:(NSString *)station1 to:(NSString *)station2
{
    for (Station *s in stations) {
        if([s.name isEqualToString:station1] || [s.name isEqualToString:station2]) {
            if(s.transfer != nil) {
                // is there a short way?
                NSString *anotherStation = nil;
                if([s.name isEqualToString:station1]) anotherStation = station2;
                else anotherStation = station1;
                for (Station *s2 in s.transfer.stations) {
                    if([s2.name isEqualToString:anotherStation] && s2.line == s.line) {
                        s.transfer.active = YES;
                        return s.transfer;
                    }
                }
            }
            s.active = YES;
            if(s.transfer && map->TrKind != LIKE_VENICE) s.transfer.active = YES;
            for (Segment *seg in s.segment) {
                if([seg.end.name isEqualToString:station1] || [seg.end.name isEqualToString:station2]) {
                    seg.end.active = YES;
                    seg.active = YES;
                    if(seg.end.transfer && map->TrKind != LIKE_VENICE) seg.end.transfer.active = YES;
                    return seg;
                }
            }
        }
    }
#ifdef DEBUG
    NSLog(@"Error: no segment between %@ and %@ on line %@", station1, station2, name);
#endif
    return nil;
}

-(BOOL)findPathFrom:(Station*)st to:(NSString*)station2 withArray:(NSMutableArray*)res
{
    if([st.name isEqualToString:station2]) {
        return YES;
    }
    for (Segment *s in st.segment) {
        if([self findPathFrom:s.end to:station2 withArray:res]) {
            [res addObject:s];
            return YES;
        }
    }
    return NO;
}

-(Segment*)activatePathFrom:(NSString *)station1 to:(NSString *)station2
{
    NSMutableArray *res = [NSMutableArray array];
    for (Station *s in stations) {
        NSString *another = nil;
        if([s.name isEqualToString:station1]) another = station2;
        if([s.name isEqualToString:station2]) another = station1;
        if(another != nil) {
            if([self findPathFrom:s to:another withArray:res]) break;
        }
    }
#ifdef DEBUG
    if([res count] == 0) NSLog(@"can't activate path from %@ to %@", station1, station2);
#endif
    for (Segment *s in res) {
        s.start.active = YES;
        s.end.active = YES;
        s.active = YES;
    }
    if([res count] > 0) return [res objectAtIndex:0];
    return nil;
    //return [[res reverseObjectEnumerator] allObjects];
}

-(Segment*)getSegmentFrom:(NSString *)station1 to:(NSString *)station2
{
    for (Station *s in stations) {
        if([s.name isEqualToString:station1] || [s.name isEqualToString:station2]) {
            for (Segment *seg in s.segment) {
                if([seg.end.name isEqualToString:station1] || [seg.end.name isEqualToString:station2]) {
                    return seg;
                }
            }
        }
    }
    return nil;
}

-(NSArray*)getPathFrom:(NSString *)station1 to:(NSString *)station2
{
    NSMutableArray *res = [NSMutableArray array];
    for (Station *s in stations) {
        NSString *another = nil;
        if([s.name isEqualToString:station1]) another = station2;
        if([s.name isEqualToString:station2]) another = station1;
        if(another != nil) {
            if([self findPathFrom:s to:another withArray:res]) break;
        }
    }
    return [[res reverseObjectEnumerator] allObjects];
}


-(void)setEnabled:(BOOL)en
{
    twoStepsDraw = !en;
    for (Station *s in stations) {
        s.active = en;
        for(Segment *seg in s.segment) {
            seg.active = en;
        }
    }
}

-(void)additionalPointsBetween:(NSString *)station1 and:(NSString *)station2 points:(NSArray *)points
{
    NSString *st1 = [[ComplexText makePlainString:station1] lowercaseString];
    NSString *st2 = [[ComplexText makePlainString:station2] lowercaseString];
    for (Station *s in stations) {
        BOOL search = NO;
        BOOL rev = NO;
        if([[s.name lowercaseString] isEqualToString:st1]) {
            search = YES;
        }
        else if([[s.name lowercaseString] isEqualToString:st2]) {
            search = rev = YES;
        }
        if(search) {
            NSMutableArray *allseg = [NSMutableArray arrayWithArray:s.segment];
            [allseg addObjectsFromArray:s.backSegment];
            for (Segment *seg in allseg) {
                if(([[seg.end.name lowercaseString] isEqualToString:st1] && rev)
                   || ([[seg.end.name lowercaseString] isEqualToString:st2] && !rev)) {
                    NSEnumerator *enumer;
                    if(rev) enumer = [points reverseObjectEnumerator];
                    else enumer = [points objectEnumerator];
                    for (NSString *p in enumer) {
                        if([p isEqualToString:@"spline"]) {
                            seg.isSpline = YES;
                            continue;
                        }
                        NSArray *coord = [p componentsSeparatedByString:@","];
                        [seg appendPoint:CGPointMake([[coord objectAtIndex:0] intValue], [[coord objectAtIndex:1] intValue])];
                    }
                    //[seg calcSpline];
                    //return;
                }
            }
        }
    }
}

-(Station*)getStation:(NSString *)stName
{
    for (Station *s in stations) {
        if([s.name isEqualToString:stName]) return s;
    }
    return nil;
}

-(void)drawNormalStationMark:(CGContextRef)ctx rect:(CGRect)rect
{
    switch(map->StKind) {
        case LIKE_MOSCOW: {
            CGContextSetRGBFillColor(ctx, 0, 0, 0, 1.0);
            CGContextFillEllipseInRect(ctx, rect);
            CGFloat components[4];
            [_color getComponents:components];
            CGContextSetRGBFillColor(ctx, *components, *(components+1), *(components+2), *(components+3));
            drawFilledCircle(ctx, rect.origin.x+rect.size.width/2, rect.origin.y+rect.size.height/2, rect.size.width/2-map->PredrawScale/2);
        }
            break;
        case LIKE_PARIS: {
            CGFloat components[4];
            [_color getComponents:components];
            CGContextSetRGBFillColor(ctx, *components, *(components+1), *(components+2), *(components+3));
            drawFilledCircle(ctx, rect.origin.x+rect.size.width/2, rect.origin.y+rect.size.height/2, rect.size.width/2);
        }
            break;
        case LIKE_LONDON:
        case LIKE_HAMBURG:
        case LIKE_VENICE:
            break;
        case DONT_DRAW:
        case KINDS_NUM:
            break;
    }
}

-(void)drawDisabledStationMark:(CGContextRef)ctx
{
    CGFloat ssize = map->StationDiameter*map->PredrawScale;
    CGFloat hsize = ssize/2;
    switch(map->StKind) {
        case LIKE_MOSCOW: {
            CGContextSetRGBFillColor(ctx, 0, 0, 0, 1.0);
            CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, ssize, ssize));
            CGFloat components[4];
            [_disabledColor getComponents:components];
            CGContextSetRGBFillColor(ctx, *components, *(components+1), *(components+2), *(components+3));
            drawFilledCircle(ctx, hsize, hsize, hsize-map->PredrawScale/2);
        }
            break;
        case LIKE_PARIS: {
            CGFloat components[4];
            [_disabledColor getComponents:components];
            CGContextSetRGBFillColor(ctx, *components, *(components+1), *(components+2), *(components+3));
            drawFilledCircle(ctx, hsize, hsize, hsize);
        }
            break;
        case LIKE_LONDON:
        case LIKE_HAMBURG:
        case LIKE_VENICE:
            break;
        case DONT_DRAW:
        case KINDS_NUM:
            break;
    }
}

-(void)predraw:(CGContextRef)context
{
    CGFloat ssize = map->StationDiameter*map->PredrawScale;
    CGFloat hsize = ssize/2;
    for (Station *s in stations) {
        [s predraw:context];
    }
    if(map->StKind == LIKE_LONDON || map->StKind == LIKE_HAMBURG || map->StKind == LIKE_VENICE) return;
    if(stationLayer != nil) CGLayerRelease(stationLayer);
    // make predrawed staion point
    stationLayer = CGLayerCreateWithContext(context, CGSizeMake(ssize, ssize), NULL);
    CGContextRef ctx = CGLayerGetContext(stationLayer);
    [self drawNormalStationMark:ctx rect:CGRectMake(0, 0, ssize, ssize)];

    if(disabledStationLayer != nil) CGLayerRelease(disabledStationLayer);
    // make predrawed staion point
    disabledStationLayer = CGLayerCreateWithContext(context, CGSizeMake(ssize, ssize), NULL);
    ctx = CGLayerGetContext(disabledStationLayer);
    [self drawDisabledStationMark:ctx];
}

-(void)calcStations
{
    for (Station *st in stations) {
        [st makeTangent];
    }
}

-(id)copyWithZone:(NSZone*)zone
{
    Line *l = [[[self class] allocWithZone:zone] init];
    if(l) {
        l->name = name;
        l->shortName = shortName;
        l->stations = stations;
        l->_color = _color;
        l->_disabledColor = _disabledColor;
        l->index = index;
        l->scc = scc;
        l->_pinColor = _pinColor;
        l->stationLayer = stationLayer;
        l->disabledStationLayer = disabledStationLayer;
        l->boundingBox = boundingBox;
        l->twoStepsDraw = twoStepsDraw;
        l->map = map;
        l->hasAltNames = hasAltNames;
        l->_deepCopy = nil;
    }
    return l;
}

-(id)superCopy
{
    if(_deepCopy == nil) {
        _deepCopy = [self copy];
        _deepCopy->name = [name copy];
        _deepCopy->shortName = [shortName copy];
        _deepCopy->_color = [_color copy];
        _deepCopy->_disabledColor = [_disabledColor copy];
        _deepCopy->stations = [NSMutableArray array];
        for (Station *s in stations) {
            [_deepCopy->stations addObject:[s superCopy]];
        }
    }
    return _deepCopy;
}

-(void)dropCopy
{
    _deepCopy = nil;
    for (Station *s in stations) {
        [s dropCopy];
    }
}

@end

@implementation CityMap

@synthesize graph;
@synthesize activeExtent;
@synthesize activePath;
@synthesize maxScale;
@synthesize thisMapName;
@synthesize pathToMap;
@synthesize pathStationsList;
@synthesize pathTimesList;
@synthesize pathDocksList;
@synthesize mapLines, transfers;
@synthesize currentScale;
@synthesize backgroundImageFile;
@synthesize foregroundImageFile;
@synthesize gpsCircleScale;
@synthesize backgroundColor;
@synthesize languages;

-(StationKind) stationKind { return StKind; }
-(void) setStationKind:(StationKind)stationKind { StKind = stationKind; }
-(StationKind) transferKind { return TrKind; }
-(void) setTransferKind:(StationKind)transferKind { TrKind = transferKind; }
-(DrawNameType) drawName { return DrawName; }
-(void) setDrawName:(DrawNameType)drawName { 
    if(hasAltNames) DrawName = drawName; 
    else DrawName = NAME_NORMAL;
}

-(id) init {
    self = [super init];
	[self initVars];
    return self;
}

-(void) initVars {

    PredrawScale = 2.f;
    LineWidth = 4.f;
    StationDiameter = 8.f;
    FontSize = 7.f;
    gpsCircleScale = 5.f;
    StKind = LIKE_PARIS;
    TrKind = LIKE_PARIS;
    TEXT_FONT = @"Arial-BoldMT";
   
    transfers = [[NSMutableArray alloc] init];
	graph = [Graph graph];
    mapLines = [[NSMutableArray alloc] init];
    activeExtent = CGRectNull;
    activePath = [[NSMutableArray alloc] init];
    pathStationsList = [[NSMutableArray alloc] init];
    pathTimesList = [[NSMutableArray alloc] init];
    pathDocksList = [[NSMutableArray alloc] init];
    maxScale = 4;
    undo = [[NSMutableArray alloc] init];
}

-(CGSize) size { return CGSizeMake(_w, _h); }
-(NSInteger) w { return _w; }
-(NSInteger) h { return _h; }

-(CGFloat) predrawScale { return PredrawScale; }
-(void) setPredrawScale:(CGFloat)predrawScale {
    PredrawScale = predrawScale;
    [self predraw];
}

-(void) loadMap:(NSString *)mapName {

    self.thisMapName=mapName;
    
    NSFileManager *manager = [NSFileManager defaultManager];
    //NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    //NSString *mapDirPath = [cacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@",[mapName lowercaseString]]];
    
    mapFile = @"";
    trpFile = @"";
    NSString *trpNewFile =  @"";
    BOOL useTrpNew=NO;
    
    if ([[manager contentsOfDirectoryAtPath:mapName error:nil] count]>0) {
        NSDirectoryEnumerator *dirEnum = [manager enumeratorAtPath:mapName];
        NSString *file;
        
        while (file = [dirEnum nextObject]) {
            if ([[file pathExtension] isEqualToString: @"map"]) {
                mapFile=[mapName stringByAppendingPathComponent:file];
            } else if ([[file pathExtension] isEqualToString: @"trp"]) {
                trpFile=[mapName stringByAppendingPathComponent:file];
            } else if ([[file pathExtension] isEqualToString: @"trpnew"]) {
                trpNewFile=[mapName stringByAppendingPathComponent:file];
                useTrpNew=YES;
            }
        }
    } 
    
    if (useTrpNew) {
        trpFile=trpNewFile;
    }
    
    NSArray *files;
    
    // если не получается взять файлы из директории cache - то пытаемся найти их в бандле
    if ([mapFile isEqual:@""] || [trpFile isEqual:@""]) {
        
        files = [[NSBundle mainBundle] pathsForResourcesOfType:@"map" inDirectory:[NSString stringWithFormat:@"%@", mapName]];
        if([files count] <= 0) {
#ifdef DEBUG
            NSLog(@"map file not found: %@", mapName);
#endif
            return;
        }
        mapFile = [files objectAtIndex:0];
        
        files = [[NSBundle mainBundle] pathsForResourcesOfType:@"trpnew" inDirectory:[NSString stringWithFormat:@"%@", mapName]];
        if([files count] <= 0) {
            files = [[NSBundle mainBundle] pathsForResourcesOfType:@"trp" inDirectory:[NSString stringWithFormat:@"%@", mapName]];
            if([files count] <= 0) {
#ifdef DEBUG
                NSLog(@"trp file not found: %@", mapName);
#endif
                return;
            } else {
                trpFile = [files objectAtIndex:0];
                [self loadOldMap:mapFile trp:trpFile];
            }
        } else {
            trpFile = [files objectAtIndex:0];
            [self loadNewMap:mapFile trp:trpFile];
        }

    } else {
        if (useTrpNew) {
            [self loadNewMap:mapFile trp:trpFile];
        } else {
            [self loadOldMap:mapFile trp:trpFile];
        }
    }   
    
    [self loadPlacesForMap:mapFile];
    
    self.pathToMap = [mapFile stringByDeletingLastPathComponent];
    
//    [[MHelper sharedHelper] readHistoryFile:mapName];
//    [[MHelper sharedHelper] readBookmarkFile:mapName];
//    [[MHelper sharedHelper] readLanguageIndex:mapName];
//    NSString *routePath = [NSString stringWithFormat:@"%@/route", self.pathToMap];
//    if((schedule = [[Schedule alloc] initFastSchedule:@"routes" path:[NSString stringWithFormat:@"%@/newroute", self.pathToMap]]) ||
//       (schedule = [[Schedule alloc] initSchedule:@"routes" path:routePath])) {
//        for (Line *l in mapLines) {
//            if([schedule setIndex:l.index forLine:l.name]) {
//                for (Station *s in l.stations) {
//                    [schedule checkStation:s.name line:l.name];
//                }
//            }
//        }
//        [schedule removeUncheckedStations];
//    }
    
    // check different stations with equal names
    for (Line *l in mapLines) {
        for (Station* st in l.stations) {
            if(st.transfer == nil && st.drawName) {
                for (Line* l2 in mapLines) {
                    for (Station *st2 in l2.stations) {
                        if(st2 != st && st2.transfer == nil && [st2.name isEqualToString:st.name])
                            st2.drawName = false;
                    }
                }
            }
        }
    }
    [self resetMap:NO];
}

-(void) loadOldMap:(NSString *)_mapFile trp:(NSString *)_trpFile {

	int err;
	INIParser* parserTrp, *parserMap;

	parserTrp = [[INIParser alloc] init];
	parserMap = [[INIParser alloc] init];
	err = [parserTrp parse:[_trpFile UTF8String]];
    err = [parserMap parse:[_mapFile UTF8String]];

    NSString *bgfile = [parserMap get:@"ImageFileName" section:@"Options"];
    if([bgfile length] > 0) backgroundImageFile = bgfile;
    else backgroundImageFile = nil;
    bgfile = [parserMap get:@"UpperImageFileName" section:@"Options"];
    if([bgfile length] > 0) foregroundImageFile = bgfile;
    else foregroundImageFile = nil;
    int val = [[parserMap get:@"LinesWidth" section:@"Options"] intValue];
    if(val != 0) LineWidth = val;
    val = [[parserMap get:@"StationDiameter" section:@"Options"] intValue];
    if(val != 0) StationDiameter = val;
    FontSize = StationDiameter;
    val = [[parserMap get:@"DisplayTransfers" section:@"Options"] intValue];
    if(val >= 0 && val < KINDS_NUM) TrKind = val;
    val = [[parserMap get:@"DisplayStations" section:@"Options"] intValue];
    if(val >= 0 && val < KINDS_NUM) StKind = val;
    val = [[parserMap get:@"FontSize" section:@"Options"] intValue];
    if(val > 0) FontSize = val;
    float sc = 1.f;
    sc = [[parserMap get:@"MaxScale" section:@"Options"] floatValue];
    if(sc != 0.f) maxScale = sc;
    PredrawScale = maxScale;
    sc = [[parserMap get:@"GpsMarkScale" section:@"Options"] floatValue];
    if(sc != 0.f) {
        gpsCircleScale = sc;
    }
    BOOL tuneEnabled = [[parserMap get:@"TuneTransfers" section:@"Options"] boolValue];
    NSString *bgColor = [parserMap get:@"BackgroundColor" section:@"Options"];
    if(bgColor != nil && [bgColor length] > 0) {
        backgroundColor = [self colorForHex:bgColor];
    } else backgroundColor = [NSColor whiteColor];
	
	_w = 0;
	_h = 0;
    CGRect boundingBox = CGRectNull;
    int index = 1;
	for (int i = 1; true; i++) {
		NSString *sectionName = [NSString stringWithFormat:@"Line%d", i ];
        if([parserTrp getSection:sectionName] == nil) break;
		NSString *lineName = [parserTrp get:@"Name" section:sectionName];
        if(lineName == nil) continue;
#ifdef DEBUG
        NSLog(@"read line: %@", lineName);
#endif

		NSString *colors = [parserMap get:@"Color" section:lineName];
        int pinColor = [[parserMap get:@"PinColor" section:lineName] intValue];
		NSString *coords = [parserMap get:@"Coordinates" section:lineName];
		NSString *coordsText = [parserMap get:@"Rects" section:lineName];
		NSString *stations = [parserTrp get:@"Stations" section:sectionName];
		NSString *coordsTime = [parserTrp get:@"Driving" section:sectionName];
        if([coords length] == 0 || [coordsText length] == 0 || [stations length] == 0 || [coordsTime length] == 0) continue;
		
//        MLine *newLine = [NSEntityDescription insertNewObjectForEntityForName:@"Line" inManagedObjectContext:[MHelper sharedHelper].managedObjectContext];
//        newLine.name=lineName;
//        newLine.index = [[NSNumber alloc] initWithInt:index];
//        newLine.color = [self colorForHex:colors];

        // [self processLinesStations:stations	:i];
        
        Line *l = [[Line alloc] initWithMap:self name:lineName stations:stations driving:coordsTime coordinates:coords rects:coordsText];
        if(l.hasAltNames) 
            hasAltNames = YES;
        l.index = index;
        l.color = [self colorForHex:colors];
        l.pinColor = pinColor-1;
        [mapLines addObject:l];
        boundingBox = CGRectUnion(boundingBox, l.boundingBox);
        index ++;
	}
//    [[MHelper sharedHelper] saveContext];
    if(boundingBox.origin.x > 0) {
        _w = boundingBox.origin.x * 2 + boundingBox.size.width;
    } else {
        _w = boundingBox.size.width;
    }
    if(boundingBox.origin.y > 0) {
        _h = boundingBox.origin.y * 2 + boundingBox.size.height;
    } else {
        _h = boundingBox.size.height;
    }
		
	INISection *section = [parserMap getSection:@"AdditionalNodes"];
	for (NSString* key in section.allKeys) {
		NSString *value = [section retrieve:key];
		[self processAddNodes:value];
	}
	INISection *section2 = [parserTrp getSection:@"Transfers"];
	for (NSString* key in section2.allKeys) {
		NSString *value = [section2 retrieve:key];
		[self processTransfers:value];
	}
	
    if(TrKind == LIKE_VENICE) {
        for (Line *l in mapLines) {
            for (Station* st in l.stations) {
                if(st.transfer == nil) {
                    Transfer *tr = [[Transfer alloc] initWithMap:self];
                    tr.time = 0.f;
                    [tr addStation:st];
                    [transfers addObject:tr];
                }
            }
        }
    }
    
    for (Line *l in mapLines) {
        [l calcStations];
    }
    
    if(tuneEnabled) {
        for (Transfer* tr in transfers) {
            [tr tuneStations];
        }
    }
    
    for (Line *l in mapLines) {
        for (Station *st in l.stations) {
            for (Segment *seg in st.segment) {
                [seg prepare];
            }
        }
    }

    [self calcGraph];
    [self predraw];
}

-(void) saveMap
{
    NSOutputStream *map = [NSOutputStream outputStreamToFileAtPath:mapFile append:NO];
    NSOutputStream *trp = [NSOutputStream outputStreamToFileAtPath:trpFile append:NO];
    [map open];

    [map write:@"[Options]\n"];
    [map write:[NSString stringWithFormat:@"StationDiameter=%d\n", (int)StationDiameter]];
    if(backgroundImageFile) [map write:[NSString stringWithFormat:@"ImageFileName=%@\n", backgroundImageFile]];
    if(foregroundImageFile) [map write:[NSString stringWithFormat:@"UpperImageFileName=%@\n", foregroundImageFile]];
    [map write:[NSString stringWithFormat:@"LinesWidth=%d\n", (int)LineWidth]];
    [map write:[NSString stringWithFormat:@"DisplayTransfers=%d\n", (int)TrKind]];
    [map write:[NSString stringWithFormat:@"DisplayStations=%d\n", (int)StKind]];
    [map write:[NSString stringWithFormat:@"FontSize=%d\n", (int)FontSize]];
    [map write:[NSString stringWithFormat:@"MaxScale=%f\n", maxScale]];
    [map write:[NSString stringWithFormat:@"GpsMarkScale=%d\n", (int)gpsCircleScale]];
    [map write:[NSString stringWithFormat:@"BackgroundColor=%@\n", [self hexForColor:backgroundColor]]];
    [map write:@"\n"];

    for (Line *l in mapLines) {
        [map write:[NSString stringWithFormat:@"[%@]\n", l.name]];
        NSString *c = [self hexForColor:l.color];
        [map write:[NSString stringWithFormat:@"Color=%@\n", c]];
        [map write:[NSString stringWithFormat:@"LabelsColor=%@\n", c]];
        [map write:@"Coordinates="];
        BOOL first = YES;
        for (Station *s in l.stations) {
            if(!first) [map write:@", "];
            [map write:[NSString stringWithFormat:@"%d,%d", (int)s.pos.x, (int)s.pos.y]];
            first = NO;
        }
        first = YES;
        [map write:@"\nRects="];
        for (Station *s in l.stations) {
            if(!first) [map write:@", "];
            [map write:[NSString stringWithFormat:@"%d,%d,%d,%d", (int)s.textRect.origin.x, (int)s.textRect.origin.y, (int)s.textRect.size.width, (int)s.textRect.size.height]];
            first = NO;
        }
        [map write:@"\nRect=\n\n"];
    }
    
    [map write:@"[AdditionalNodes]\n"];
    int an = 1;
    NSMutableDictionary *addnodes = [NSMutableDictionary dictionary];
    for (Line *l in mapLines) {
        for (Station *st in l.stations) {
            for (Segment *s in st.segment) {
                if([s.linePoints count] > 0) {
                    NSString *key = [NSString stringWithFormat:@"%@,%@,%@", l.name, st.name, s.end.name];
                    if([addnodes valueForKey:key] != nil) continue;
                    [map write:[NSString stringWithFormat:@"%d=%@", an, key]];
                    [addnodes setValue:@"node" forKey:key];
                    for (NSValue *v in s.linePoints) {
                        CGPoint p = [v pointValue];
                        [map write:[NSString stringWithFormat:@", %d,%d", (int)p.x, (int)p.y]];
                    }
                    if(s.isSpline) {
                        [map write:@", spline"];
                    }
                    [map write:@"\n"];
                    an++;
                }
            }
        }
        [map write:@"\n"];
    }
    [map close];

    [trp open];
    int ln = 1;
    int brnum = 1;
    for (Line *l in mapLines) {
        NSMutableSet *starts = [NSMutableSet set];
        //NSMutableSet *ends = [NSMutableSet set];
        [trp write:[NSString stringWithFormat:@"[Line%d]\n", ln]];
        [trp write:[NSString stringWithFormat:@"Name=%@\n", l.name]];
        for (Station *s in l.stations) {
            [trp write:[NSString stringWithFormat:@"%d\t%@ %f,%f\t,\t%@\t%@\n", s.index, s.nameSource, s.gpsCoords.x, s.gpsCoords.y, WayToString(s.way1), WayToString(s.way2)]];
            [starts addObjectsFromArray:s.firstStations];
            //[ends addObjectsFromArray:s.lastStations];
        }
        [trp write:@"\n"];
        NSMutableArray *branches = [NSMutableArray array];
        NSMutableArray *drivings = [NSMutableArray array];
        for (Station *s in starts) {
            [self detectBranch:branches andDriving:drivings fromStation:s branch:nil andDriving:nil withEndStations:nil withBackStations:nil];
        }
        int num = brnum;
        for(NSMutableString *s in branches) {
            [trp write:[NSString stringWithFormat:@"branch%d = %@\n", num, s]];
            num ++;
        }
        num = brnum;
        for(NSMutableString *s in drivings) {
            [trp write:[NSString stringWithFormat:@"driving%d = %@\n", num, s]];
            num ++;
        }
        brnum += MAX([branches count], [drivings count]);
        ln ++;
        [trp write:@"\n"];
    }
    
    [trp write:@"[Transfers]\n"];
    
    int num = 1;
    for (Transfer *t in transfers) {
        for (Station *s1 in t.stations) {
            for(Station *s2 in t.stations) {
                if(s1 != s2) {
                    NSArray* transferWays = [s1->transferWay objectForKey:s2];
                    [trp write:[NSString stringWithFormat:@"%03d=%@,%@,%@,%@,%d, %@, %@, %@, %@\n", num, s1.line.name, s1.name, s2.line.name, s2.name, (int)t.time, WayToString([[transferWays objectAtIndex:0] intValue]), WayToString([[transferWays objectAtIndex:1] intValue]), WayToString([[transferWays objectAtIndex:2] intValue]), WayToString([[transferWays objectAtIndex:3] intValue])]];
                    num ++;
                }
            }
        }
    }
    
    [trp close];
}

-(void) detectBranch:(NSMutableArray*)branches andDriving:(NSMutableArray*)drivings fromStation:(Station*)s branch:(NSMutableString*)branch andDriving:(NSMutableString*)driving withEndStations:(NSArray*)ends withBackStations:(NSMutableSet*)backs
{
    if(branch == nil) branch = [NSMutableString string];
    if(driving == nil) driving = [NSMutableString string];
    do {
        if([branch length] > 0) [branch appendFormat:@", %d", s.index];
        else [branch appendFormat:@"<>%d", s.index];
        if([driving length] > 0) [driving appendFormat:@", %d", s.driving];
        else [driving appendFormat:@"%d", s.driving];
        
        if([backs containsObject:s]) {
            [branches addObject:[branch copy]];
            [drivings addObject:[driving copy]];
            return;
        }
        if(backs == nil) backs = [NSMutableSet setWithObject:s];
        else [backs addObject:s];
        
        switch([s.segment count]) {
            case 0:
                [branches addObject:[branch copy]];
                [drivings addObject:[driving copy]];
                return;
            case 1:
                if([ends containsObject:s]) {
                    [branches addObject:[branch copy]];
                    [drivings addObject:[driving copy]];
                }
                s = [[s.segment lastObject] end];
                break;
            default:
                if([ends containsObject:s]) {
                    [branches addObject:[branch copy]];
                    [drivings addObject:[driving copy]];
                }
                for(Station* s1 in s.forwardWay) {
                    [self detectBranch:branches andDriving:drivings fromStation:s1 branch:[branch mutableCopy] andDriving:[driving mutableCopy] withEndStations:s.lastStations withBackStations:[backs mutableCopy]];
                }
                return;
        }
    } while (YES);
}

- (void) loadPlacesForMap:(NSString*)mapName {
//    NSString *path = [NSString stringWithFormat:@"%@/places.json",[mapName stringByDeletingLastPathComponent]];
//    tubeAppDelegate *appDelegate = 	(tubeAppDelegate *)[[UIApplication sharedApplication] delegate];
//    appDelegate.mapDirectoryPath = [mapName stringByDeletingLastPathComponent];
//    NSDictionary *placesData = nil;
//    if (path) {
//        NSData *jsonData = [NSData dataWithContentsOfFile:path];
//        if (jsonData) {
//            NSError *error = nil;
//            placesData = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
//            if (error) {
//                NSLog(@"Error reading JSON: %@, %@", [error localizedFailureReason], [error localizedDescription]);
//            }
//        }
//    }
//    if (placesData) {
//        //Read categories
//        NSArray *categories = [placesData objectForKey:@"categories"];
//        for (NSDictionary *category in categories) {
//            MCategory *newCat = [NSEntityDescription insertNewObjectForEntityForName:@"Category" inManagedObjectContext:[MHelper sharedHelper].managedObjectContext];
//            newCat.name=[category objectForKey:@"name"];
//            newCat.index = [NSNumber numberWithInt:[[category objectForKey:@"index"] integerValue]];
//            newCat.color = [self colorForHex:[category objectForKey:@"color"]];
//            newCat.image_normal = [category objectForKey:@"image_normal"];
//            newCat.image_highlighted = [category objectForKey:@"image_highlighted"];
//        }
//        NSArray *places = [placesData objectForKey:@"places"];
//        for (NSDictionary *place in places) {
//            MPlace *newPlace = [NSEntityDescription insertNewObjectForEntityForName:@"Place" inManagedObjectContext:[MHelper sharedHelper].managedObjectContext];
//            newPlace.name = [place objectForKey:@"name"];
//            newPlace.index = [NSNumber numberWithInt:[[place objectForKey:@"index"] integerValue]];
//            newPlace.accessLevel = [NSNumber numberWithInt:[[place objectForKey:@"accessLevel"] integerValue]];
//            newPlace.text = [place objectForKey:@"text"];
//            newPlace.posX = [NSNumber numberWithFloat:[[place objectForKey:@"long"] floatValue]];
//            newPlace.posY = [NSNumber numberWithFloat:[[place objectForKey:@"lat"] floatValue]];
//            NSMutableSet *setCategories = [newPlace mutableSetValueForKey:@"categories"];
//            //Read categories for this place
//            for (NSNumber *catId in [place objectForKey:@"categories"]) {
//                MCategory *cat = [[MHelper sharedHelper] categoryByIndex:[catId intValue]];
//                if (cat) {
//                    [setCategories addObject:cat];
//                }
//                else {
//                    //OMG, it's not a category...
//                    continue;
//                }
//            }
//            //Read photos for this place
//            NSMutableSet *setPhotos = [newPlace mutableSetValueForKey:@"photos"];
//            NSInteger index = 0;
//            for (NSString *filename in [place objectForKey:@"photos"]) {
//                MPhoto *photo = [[MHelper sharedHelper] photoByFilename:filename];
//                if (!photo) {
//                    photo = [NSEntityDescription insertNewObjectForEntityForName:@"Photo" inManagedObjectContext:[MHelper sharedHelper].managedObjectContext];
//                    photo.filename = filename;
//                    photo.index = [NSNumber numberWithInteger:index];
//                }
//                [setPhotos addObject:photo];
//                index++;
//            }
//        }
//        
//        
//        [[MHelper sharedHelper] saveContext];
//    }
}

-(void) loadNewMap:(NSString *)mapFile trp:(NSString *)trpFile {

	INIParser* parserTrp, *parserMap;
	
	int err;
	parserTrp = [[INIParser alloc] init];
	parserMap = [[INIParser alloc] init];
	err = [parserTrp parse:[trpFile UTF8String]];
    err = [parserMap parse:[mapFile UTF8String]];
    
    NSString *bgfile = [parserMap get:@"ImageFileName" section:@"Options"];
    if([bgfile length] > 0) backgroundImageFile = bgfile;
    else backgroundImageFile = nil;
    bgfile = [parserMap get:@"UpperImageFileName" section:@"Options"];
    if([bgfile length] > 0) foregroundImageFile = bgfile;
    else foregroundImageFile = nil;
    int val = [[parserMap get:@"LinesWidth" section:@"Options"] intValue];
    if(val != 0) LineWidth = val;
    val = [[parserMap get:@"StationDiameter" section:@"Options"] intValue];
    if(val != 0) StationDiameter = val;
    FontSize = StationDiameter;
    val = [[parserMap get:@"DisplayTransfers" section:@"Options"] intValue];
    if(val >= 0 && val < KINDS_NUM) TrKind = val;
    val = [[parserMap get:@"DisplayStations" section:@"Options"] intValue];
    if(val >= 0 && val < KINDS_NUM) StKind = val;
    val = [[parserMap get:@"FontSize" section:@"Options"] intValue];
    if(val > 0) FontSize = val;
    float sc = 1.f;
    sc = [[parserMap get:@"MaxScale" section:@"Options"] floatValue];
    if(sc != 0.f) maxScale = sc;
    PredrawScale = maxScale;
    BOOL tuneEnabled = [[parserMap get:@"TuneTransfers" section:@"Options"] boolValue];
    sc = [[parserMap get:@"GpsMarkScale" section:@"Options"] floatValue];
    if(sc != 0.f) {
        gpsCircleScale = sc;
    }
    NSString *bgColor = [parserMap get:@"BackgroundColor" section:@"Options"];
    if(bgColor != nil && [bgColor length] > 0) {
        backgroundColor = [self colorForHex:bgColor];
    } else backgroundColor = [NSColor whiteColor];
	
	_w = 0;
	_h = 0;
    CGRect boundingBox = CGRectNull;
    NSMutableDictionary *stations = [[NSMutableDictionary alloc] init];
    int index = 1;
	for (int i = 1; true; i++) {
		NSString *sectionName = [NSString stringWithFormat:@"Line%d", i ];
		NSString *lineName = [parserTrp get:@"Name" section:sectionName];
        if(lineName == nil) break;
#ifdef DEBUG
        NSLog(@"read line: %@", lineName);
#endif
        
		NSString *colors = [parserMap get:@"Color" section:lineName];
        int pinColor = [[parserMap get:@"PinColor" section:lineName] intValue];
        NSArray *coords = [[parserMap get:@"Coordinates" section:lineName] componentsSeparatedByString:@", "];
        NSArray *coordsText = [[parserMap get:@"Rects" section:lineName] componentsSeparatedByString:@", "];
        if([coords count] == 0 || [coordsText count] == 0) break;

        INISection *sect = [parserTrp getSection:sectionName];
        Line *l = [[Line alloc] initWithMap:self andName:lineName];
        l.index = index;
        l.color = [self colorForHex:colors];
        l.pinColor = pinColor-1;
        [mapLines addObject:l];
//        MLine *newLine = [NSEntityDescription insertNewObjectForEntityForName:@"Line" inManagedObjectContext:[MHelper sharedHelper].managedObjectContext];
//        newLine.name=lineName;
//        newLine.index = [NSNumber numberWithInt:index];
//        newLine.color = [self colorForHex:colors];
        
        int si = 0;
        //NSArray *keys = [[sect.assignments allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
        NSArray *keys = [sect allKeys];
        NSMutableArray *branches = [[NSMutableArray alloc] init];
        NSMutableArray *drivings = [[NSMutableArray alloc] init];
        for (NSString* key in keys) {
            NSString *value = [sect.assignments objectForKey:key];
            if([value length] <= 0) continue;
            if([key isEqualToString:@"NAME"]) {
                // skip
            } else if ([key rangeOfString:@"BRANCH"].location != NSNotFound) {
                // branch
                //NSLog(@"Branch %@", value);
                [branches addObject:value];
            } else if ([key rangeOfString:@"DRIVING"].location != NSNotFound) {
                // driving
                //NSLog(@"Driving %@", value);
                [drivings addObject:value];
            } else {
                // station
                if(si >= [coords count]) {
#ifdef DEBUG
                    NSLog(@"ERROR: Station %@ doesn't have coordinates!", value);
#endif
                    continue;
                }
                NSArray *stn = [value componentsSeparatedByString:@"\t"];
                NSString *sncr = [stn objectAtIndex:0];
                NSInteger sp = [sncr rangeOfString:@" " options:NSBackwardsSearch].location;
                NSString *stationName = [[sncr substringToIndex:sp] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet] ];
                NSArray *gpsCoords = [[sncr substringFromIndex:sp] componentsSeparatedByString:@","];
                Station *st = nil;
                /*for (Station *ss in l.stations) {
                    if([ss.name isEqualToString:stationName]) {
                        st = ss;
                        break;
                    }
                }*/
                if(st == nil) {
                    NSArray *coord_x_y = [[coords objectAtIndex:si] componentsSeparatedByString:@","];
                    int x = [[coord_x_y objectAtIndex:0] intValue];
                    int y = [[coord_x_y objectAtIndex:1] intValue];
                    NSArray *coord_text = [[coordsText objectAtIndex:si] componentsSeparatedByString:@","];
                    int tx = [[coord_text objectAtIndex:0] intValue];
                    int ty = [[coord_text objectAtIndex:1] intValue];
                    int tw = [[coord_text objectAtIndex:2] intValue];
                    int th = [[coord_text objectAtIndex:3] intValue];
                    st = [[Station alloc] initWithMap:self name:stationName pos:CGPointMake(x, y) index:si rect:CGRectMake(tx, ty, tw, th) andDriving:0];
                    if(st.altText) hasAltNames = YES;
                    st.line = l;
                    st.gpsCoords = CGPointMake([[gpsCoords objectAtIndex:0] floatValue], [[gpsCoords objectAtIndex:1] floatValue]);
                    [l.stations addObject:st];
//                    MStation *station = [NSEntityDescription insertNewObjectForEntityForName:@"Station" inManagedObjectContext:[MHelper sharedHelper].managedObjectContext];
//                    station.name= st.name;
//                    station.altname = [st.altText string];
//                    station.isFavorite=[NSNumber numberWithInt:0];
//                    station.lines=newLine;
//                    station.index = [NSNumber numberWithInt:si];
                    si ++;
#ifdef DEBUG
                    NSLog(@"read station %@", st.name);
#endif
                }
                [stations setValue:st forKey:key];
                if([stn count] >= 3) st.way1 = StringToWay([stn objectAtIndex:[stn count]-2]);
                if([stn count] >= 2) st.way2 = StringToWay([stn lastObject]);
            }
        }
        NSInteger brn = MIN([branches count], [drivings count]);
        for(int bi=0; bi<brn; bi++) {
            int direction = 0; // none
            NSString *br = [branches objectAtIndex:bi];
            NSArray *dr = [[drivings objectAtIndex:bi] componentsSeparatedByString:@","];
            NSString *brdir = [br substringToIndex:2];
            if([brdir isEqualToString:@"<>"] || [brdir isEqualToString:@"><"]) {
                direction = 3;
                br = [br substringFromIndex:2];
            } else {
                if([brdir characterAtIndex:0] == '<') {
                    // backward
                    direction = 1; 
                    br = [br substringFromIndex:1];
                } else if([brdir characterAtIndex:0] == '>') {
                    // forward
                    direction = 2; 
                    br = [br substringFromIndex:1];
                } else {
                    direction = 3; // both
                }
            }
            NSArray *br1 = [br componentsSeparatedByString:@","];
            int dri = 0;
            Station *st = nil, *firstStation = nil, *lastStation = nil;
            NSMutableArray *branch = [NSMutableArray array];
            for (NSString *br2 in br1) {
                NSArray *br3 = [br2 componentsSeparatedByString:@"."];
                int first = [[br3 objectAtIndex:0] intValue];
                int last = [[br3 lastObject] intValue];
                for(int sti = first; sti<=last; sti ++, dri++) {
                    Station *st2 = [stations objectForKey:[NSString stringWithFormat:@"%d", sti]];
                    if(firstStation == nil) firstStation = st2;
                    if(![st2.firstStations containsObject:firstStation])
                        [st2.firstStations addObject:firstStation];
                    [branch addObject:st2];
                    if(st != nil && st2 != nil) {
                        if([st addSibling:st2]) {
                            NSString *driving = nil;
                            if(dri <= [dr count]) driving = [dr objectAtIndex:dri-1];
                            else {
                                driving = @"0";
#ifdef DEBUG
                                NSLog(@"ERROR: No driving for station %@!", st.name);
#endif
                            }
                            [st.relationDriving addObject:driving];
                            if(direction & 0x2) {  // forward
                                [graph addEdgeFromNode:[GraphNode nodeWithName:st.name andLine:i] toNode:[GraphNode nodeWithName:st2.name andLine:i] withWeight:[driving floatValue]];
                                [st setTransferWay:st.way1 to:st2];
                                [st2 setTransferWay:st2.way1 from:st];
                            }
                            if(direction & 0x1) {  // backward
                                [graph addEdgeFromNode:[GraphNode nodeWithName:st2.name andLine:i] toNode:[GraphNode nodeWithName:st.name andLine:i] withWeight:[driving floatValue]];
                                [st setTransferWay:st.way2 from:st2];
                                [st2 setTransferWay:st2.way2 to:st];
                            }
                            [st.forwardWay addObject:st2];
                            [st2.backwardWay addObject:st];
                        }
                    }
                    st = st2;
                    lastStation = st2;
                }
            }
            for (Station* s in branch) {
                if(![s.lastStations containsObject:lastStation])
                    [s.lastStations addObject:lastStation];
            }
        }
        [l postInit];
		
        boundingBox = CGRectUnion(boundingBox, l.boundingBox);
        index ++;
	}
//    [[MHelper sharedHelper] saveContext];
    if(boundingBox.origin.x > 0) {
        _w = boundingBox.origin.x * 2 + boundingBox.size.width;
    } else {
        _w = boundingBox.size.width;
    }
    if(boundingBox.origin.y > 0) {
        _h = boundingBox.origin.y * 2 + boundingBox.size.height;
    } else {
        _h = boundingBox.size.height;
    }
    
	INISection *section = [parserMap getSection:@"AdditionalNodes"];
	for (NSString* key in section.allKeys) {
		NSString *value = [section retrieve:key];
		[self processAddNodes:value];
	}
	INISection *section2 = [parserTrp getSection:@"Transfers"];
	for (NSString* key in section2.allKeys) {
		NSString *value = [section2 retrieve:key];
		[self processTransfers2:value];
	}
    
    NSString *availableLanguages = [parserTrp get:@"Languages" section:@"Options"];
    NSArray *langCodes = [availableLanguages componentsSeparatedByString:@"&"];
    if (!langCodes) langCodes = [NSArray arrayWithObject:@"en"];
    NSMutableArray *languagesList = [NSMutableArray array];
    for (NSString *langID in langCodes) {
        NSString *langName = [[[NSLocale currentLocale] displayNameForKey:NSLocaleLanguageCode value:langID] capitalizedString];
        [languagesList addObject:langName];
    }
    self.languages=languagesList;
    
    if(TrKind == LIKE_VENICE) {
        for (Line *l in mapLines) {
            for (Station* st in l.stations) {
                if(st.transfer == nil) {
                    Transfer *tr = [[Transfer alloc] initWithMap:self];
                    tr.time = 0.f;
                    [tr addStation:st];
                    [transfers addObject:tr];
                }
            }
        }
    }
    
    for (Line *l in mapLines) {
        [l calcStations];
    }
    
    if(tuneEnabled) {
        for (Transfer* tr in transfers) {
            [tr tuneStations];
        }
    }
    
    for (Line *l in mapLines) {
        for (Station *st in l.stations) {
            for (Segment *seg in st.segment) {
                [seg prepare];
            }
        }
    }
    
    [self processTransfersForGraph2];
    [self predraw];
}

-(void)predraw
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    void *          bitmapData;
    int             bitmapByteCount;
    int             bitmapBytesPerRow;
    
    bitmapBytesPerRow   = (100 * 4);// 1
    bitmapByteCount     = (bitmapBytesPerRow * 100);
    
    colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);// 2
    bitmapData = calloc( bitmapByteCount, 1);// 3
    if (bitmapData == NULL) {
        fprintf (stderr, "Memory not allocated!");
        return;
    }
    context = CGBitmapContextCreate (bitmapData,// 4
                                     100,
                                     100,
                                     8,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGImageAlphaPremultipliedLast);
    if (context== NULL)
    {
        free (bitmapData);// 5
        fprintf (stderr, "Context not created!");
        return;
    }
    CGColorSpaceRelease( colorSpace );// 6
    

    // predraw transfers
    //for (Transfer *t in transfers) {
    //    [t predraw:context];
    //};
    // predraw lines & stations
    //for (Line *l in mapLines) {
    //    [l predraw:context];
    //}
    CGContextRelease(context);
}

-(NSDictionary*) calcPath :(NSString*) firstStation :(NSString*) secondStation :(NSInteger) firstStationLineNum :(NSInteger)secondStationLineNum {

//    if(schedule != nil) {
//        NSMutableSet *missingStations = [NSMutableSet set];
//        NSMutableDictionary *trpaths = [NSMutableDictionary dictionary];
//        int tries = 0;
//        do {
//            for (Line *l in mapLines) {
//                BOOL el = [schedule existLine:l.name];
//                if(!el) {
//                    for (Station *s in l.stations) {
//                        //if(![schedule existStation:s.name line:l.name]) {
//                        [missingStations addObject:[GraphNode nodeWithName:s.name andLine:s.line.index]];
//                        //}
//                    }
//                }
//            }
//            NSArray *paths = [graph getWays:[GraphNode nodeWithName:firstStation andLine:firstStationLineNum] to:[GraphNode nodeWithName:secondStation andLine:secondStationLineNum] withoutStations:missingStations];
//            int pathCount = 0;
//            for (NSArray *path in paths) {
//                NSArray *trpath;
//                trpath = [schedule translatePath:path];
//                if(trpath != nil) {
//                    CGFloat weight2 = [[trpath lastObject] weight];
//#ifdef DEBUG
//                    NSLog(@"weight is %f", weight2);
//                    NSLog(@"path is %@", path);
//                    NSLog(@"schedule path is %@", trpath);
//#endif
//                    if(weight2 < 60*60*12 && pathCount < 3) {  // время пути должно быть меньше 12 часов
//                        [trpaths setObject:trpath forKey:[NSNumber numberWithDouble:weight2]];
//                        pathCount ++;
//                    }
//                    //return [NSDictionary dictionaryWithObject:trpath forKey:[NSNumber numberWithDouble:[[trpath lastObject] weight]]];
//                }
//            }
//            tries ++;
//            if([trpaths count] > 0 || tries > 4 || ![schedule uploadFastSchedule])
//                return trpaths;
//            [missingStations removeAllObjects];
//        } while (YES);
    
        //NSArray *path = [schedule findPathFrom:firstStation to:secondStation];
#ifdef DEBUG
        //NSLog(@"schedule path is %@", path);
#endif
        //return [NSDictionary dictionaryWithObject:path forKey:[NSNumber numberWithDouble:[[path lastObject] weight]]];
//    }
	//NSArray *pp = [graph shortestPath:[GraphNode nodeWithName:firstStation andLine:firstStationLineNum] to:[GraphNode nodeWithName:secondStation andLine:secondStationLineNum]];
    NSDictionary *paths = [graph getPaths:[GraphNode nodeWithName:firstStation andLine:firstStationLineNum] to:[GraphNode nodeWithName:secondStation andLine:secondStationLineNum]];
    NSArray *keys = [[paths allKeys] sortedArrayUsingSelector:@selector(compare:)];
#ifdef DEBUG
    for (NSNumber *weight in keys) {
        NSLog(@"weight is %@", weight);
        NSLog(@"path is %@", [paths objectForKey:weight]);
    }
#endif
	 
	return paths;
}

-(void) processTransfers:(NSString*)transferInfo{
	
	NSArray *elements = [transferInfo componentsSeparatedByString:@","];

    NSString *lineStation1 = [elements objectAtIndex:0];
    NSString *station1 = [ComplexText makePlainString:[elements objectAtIndex:1]];
    NSString *lineStation2 = [elements objectAtIndex:2];
    NSString *station2 = [ComplexText makePlainString:[elements objectAtIndex:3]];

    Station *ss1 = [[self lineByName:lineStation1] getStation:station1];
    Station *ss2 = [[self lineByName:lineStation2] getStation:station2];
#ifdef DEBUG
    if(ss1 == nil) NSLog(@"Error: station %@ from line %@ not found", station1, lineStation1);
    if(ss2 == nil) NSLog(@"Error: station %@ from line %@ not found", station2, lineStation2);
#endif
    if(ss1.transfer != nil && ss2.transfer != nil) {
        
    } else if(ss1.transfer) {
        [ss1.transfer addStation:ss2];
    } else if(ss2.transfer) {
        [ss2.transfer addStation:ss1];
    } else {
        Transfer *tr = [[Transfer alloc] initWithMap:self];
        tr.time = [[elements objectAtIndex:4] floatValue];
        [tr addStation:ss1];
        [tr addStation:ss2];
        [transfers addObject:tr];
    }
}

-(void) processTransfers2:(NSString*)transferInfo{
	
	NSArray *elements = [transferInfo componentsSeparatedByString:@","];
    
    NSString *lineStation1 = [elements objectAtIndex:0];
    NSString *station1 = [ComplexText makePlainString:[elements objectAtIndex:1]];
    NSString *lineStation2 = [elements objectAtIndex:2];
    NSString *station2 = [ComplexText makePlainString:[elements objectAtIndex:3]];
    
    Station *ss1 = [[self lineByName:lineStation1] getStation:station1];
    Station *ss2 = [[self lineByName:lineStation2] getStation:station2];
    if(ss1 == nil || ss2 == nil) {
#ifdef DEBUG
        NSLog(@"Error: stations for transfer not found! %@ at %@ and %@ at %@", station1, lineStation1, station2, lineStation2);
#endif
        return;
    }
    if([elements count] >= 5) {
        int drv = [[elements objectAtIndex:4] floatValue];
        [ss1 setTransferDriving:drv to:ss2];
        [ss2 setTransferDriving:drv to:ss1];
    }
    NSMutableArray *ways = [NSMutableArray array];
    if([elements count] >= 6) {
        [ways addObject:[NSNumber numberWithInt:StringToWay([elements objectAtIndex:5])]];
    } else [ways addObject:[NSNumber numberWithInt:NOWAY]];
    if([elements count] >= 7) {
        [ways addObject:[NSNumber numberWithInt:StringToWay([elements objectAtIndex:6])]];
    } else [ways addObject:[NSNumber numberWithInt:NOWAY]];
    if([elements count] >= 8) {
        [ways addObject:[NSNumber numberWithInt:StringToWay([elements objectAtIndex:7])]];
    } else [ways addObject:[NSNumber numberWithInt:NOWAY]];
    if([elements count] >= 9) {
        [ways addObject:[NSNumber numberWithInt:StringToWay([elements objectAtIndex:8])]];
    } else [ways addObject:[NSNumber numberWithInt:NOWAY]];
    [ss1 setTransferWays:ways to:ss2];
    if(ss1.transfer != nil && ss2.transfer != nil) {
        if(ss1.transfer != ss2.transfer) {
            Transfer *t1 = ss1.transfer;
            Transfer *t2 = ss2.transfer;
            NSSet *sts = [t2.stations copy];
            while([t2.stations count] > 0) {
                [t2 removeStation:[t2.stations anyObject]];
            }
            for (Station *s in sts) {
                [t1 addStation:s];
            }
        }
    } else if(ss1.transfer) {
        [ss1.transfer addStation:ss2];
    } else if(ss2.transfer) {
        [ss2.transfer addStation:ss1];
    } else {
        Transfer *tr = [[Transfer alloc] initWithMap:self];
        tr.time = [[elements objectAtIndex:4] floatValue];
        [tr addStation:ss1];
        [tr addStation:ss2];
        [transfers addObject:tr];
    }
}


-(void) processAddNodes:(NSString*)addNodeInfo{
	
	NSArray *elements = [addNodeInfo componentsSeparatedByString:@", "];

	//expected 3+ elements
	//separate line sations info
	NSArray *stations = [[elements objectAtIndex:0] componentsSeparatedByString:@","];
	
	NSString *lineName = [stations objectAtIndex:0];
	
    for (Line* l in mapLines) {
        if([l.name isEqualToString:lineName]) {
            [l additionalPointsBetween:[stations objectAtIndex:1] and:[stations objectAtIndex:2] points:[elements objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [elements count]-1)]]];
            return;
        }
    }
#ifdef DEBUG
    NSLog(@"Error (additional point): line %@ and stations %@,%@ not found", lineName, [stations objectAtIndex:1], [stations objectAtIndex:2]);
#endif
}

- (NSColor *) colorForHex:(NSString *)hexColor {
	hexColor = [[hexColor stringByTrimmingCharactersInSet:
				 [NSCharacterSet whitespaceAndNewlineCharacterSet]
				 ] lowercaseString];  
	
    // String should be 6 or 7 characters if it includes '#'  
    if ([hexColor length] < 6) 
		return [NSColor blackColor];
	
    // strip # if it appears  
    if ([hexColor hasPrefix:@"#"]) 
		hexColor = [hexColor substringFromIndex:1];  
	
    // if the value isn't 6 characters at this point return 
    // the color black	
    if ([hexColor length] != 6) 
		return [NSColor blackColor];
	
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
	
    return [NSColor colorWithCIColor:[CIColor colorWithRed:((float) r / 255.0f)
                                                     green:((float) g / 255.0f)
                                                      blue:((float) b / 255.0f)
                                                     alpha:1.0f]];
	
}

-(NSString*)hexForColor:(NSColor*)color
{
    CGFloat components[4];
    [color getComponents:components];
    return [NSString stringWithFormat:@"%02x%02x%02x", (int)(components[0]*255), (int)(components[1]*255), (int)(components[2]*255)];
}

-(void) calcGraph {
	//for each line
    for (int i=0; i<[mapLines count]; i++) {
        Line *l = [mapLines objectAtIndex:i];
        for (Station *s in l.stations) {
            for (Segment *seg in s.segment) {
				[graph addEdgeFromNode:[GraphNode nodeWithName:s.name andLine:i+1] toNode:[GraphNode nodeWithName:seg.end.name andLine:i+1] withWeight:seg.driving];
				[graph addEdgeFromNode:[GraphNode nodeWithName:seg.end.name andLine:i+1] toNode:[GraphNode nodeWithName:s.name andLine:i+1] withWeight:seg.driving];
            }
        }
    }
	[self processTransfersForGraph];
}

-(void) processTransfersForGraph{
    for (Transfer *t in transfers) {
        for (Station *s1 in t.stations) {
            for (Station *s2 in t.stations) {
                if(s1 != s2) {
                    [graph addEdgeFromNode:[GraphNode nodeWithName:s1.name andLine:s1.line.index]
                                    toNode:[GraphNode nodeWithName:s2.name andLine:s2.line.index]
                                withWeight:t.time];
                }
            }
        }
    }
}

-(void) processTransfersForGraph2{
    for (Transfer *t in transfers) {
        for (Station *s1 in t.stations) {
            for (Station *s2 in t.stations) {
                if(s1 != s2) {
                    CGFloat dr = [s1 transferDrivingTo:s2];
                    [graph addEdgeFromNode:[GraphNode nodeWithName:s1.name andLine:s1.line.index]
                                    toNode:[GraphNode nodeWithName:s2.name andLine:s2.line.index]
                                withWeight:dr];
                }
            }
        }
    }
}

// drawing

-(void) drawMap:(CGContextRef) context inRect:(CGRect)rect
{
    CGContextSaveGState(context);
    for (Line* l in mapLines) {
        [l draw:context inRect:(CGRect)rect];
    }
    CGContextRestoreGState(context);
}

-(void) drawStations:(CGContextRef) context inRect:(CGRect)rect
{
    CGContextSaveGState(context);
    for (Line* l in mapLines) {
        [l drawNames:context inRect:rect];
    }
    CGContextRestoreGState(context);
}

// рисует часть карты
-(void) activatePath:(NSArray*)pathMap {
    for (Line *l in mapLines) {
        [l setEnabled:NO];
    }
    for (Transfer *t in transfers) {
        t.active = NO;
    }
    activeExtent = CGRectNull;
    [activePath removeAllObjects];
    [pathStationsList removeAllObjects];
    [pathTimesList removeAllObjects];
    [pathDocksList removeAllObjects];
	NSInteger count_ = [pathMap count];
    
    Station *prevStation = nil;
	for (int i=0; i< count_; i++) {
        GraphNode *n1 = [pathMap objectAtIndex:i];
        Line* l = [mapLines objectAtIndex:n1.line-1];
        Station *s = [l getStation:n1.name];
#ifdef DEBUG
        if(prevStation != nil) {
            NSLog(@"forward way is %d", [prevStation transferWayTo:s]);
            NSLog(@"backward way is %d", [s transferWayFrom:prevStation]);
        }
#endif
        activeExtent = CGRectUnion(activeExtent, s.textRect);
        activeExtent = CGRectUnion(activeExtent, s.boundingBox);
        
        if(i == count_ - 1) {
            // the last station
            activeExtent = CGRectUnion(activeExtent, s.textRect);
            activeExtent = CGRectUnion(activeExtent, s.boundingBox);
            if(DrawName == NAME_ALTERNATIVE) [pathStationsList addObject:s.altText.string];
            else [pathStationsList addObject:n1.name];
        } else {
            GraphNode *n2 = [pathMap objectAtIndex:i+1];
            
            if(n1.line == n2.line && [n1.name isEqualToString:n2.name]) {
                // the same station on the same line
                // strange, but sometimes it's possible
            } else
            if (n1.line==n2.line) {
                Segment *as = [l activateSegmentFrom:n1.name to:n2.name];
                if(as != nil) [activePath addObject:as];
                else {
                    [activePath addObject:[l activatePathFrom:n1.name to:n2.name]];
                }
                if(DrawName == NAME_ALTERNATIVE) [pathStationsList addObject:s.altText.string];
                else [pathStationsList addObject:n1.name];
                if([as isKindOfClass:[Transfer class]]) [pathStationsList addObject:@"---"]; //временно до обновления модели
            } else
            if(n1.line != n2.line) {
                [activePath addObject:s.transfer];
                if(DrawName == NAME_ALTERNATIVE) [pathStationsList addObject:s.altText.string];
                else [pathStationsList addObject:n1.name];
                [pathStationsList addObject:@"---"]; //временно до обновления модели
            }
        }
        prevStation = s;
	}
    if([[activePath lastObject] isKindOfClass:[Transfer class]]) {
        [activePath removeLastObject];
        [pathStationsList removeLastObject];
        [pathStationsList removeLastObject];
    }
    float offset = (25 - (int)[pathStationsList count]) * 0.005f;
    if(offset < 0.02f) offset = 0.02f;
    activeExtent.origin.x -= activeExtent.size.width * offset;
    activeExtent.origin.y -= activeExtent.size.height * offset;
    activeExtent.size.width *= (1.f + offset * 2.f);
    activeExtent.size.height *= (1.f + offset * 2.f);
#ifdef DEBUG
    NSLog(@"%@", activePath);
    NSLog(@"%@", pathTimesList);
    NSLog(@"%@", pathDocksList);
#endif
}

-(void) resetMap:(BOOL)enable
{
    for (Line *l in mapLines) {
        [l setEnabled:enable];
    }
    for (Transfer *t in transfers) {
        t.active = enable;
    }
    activeExtent = CGRectNull;
    [activePath removeAllObjects];
}

-(void) drawTransfers:(CGContextRef) context inRect:(CGRect)rect
{
    CGContextSaveGState(context);
    for (Transfer *tr in transfers) {
        if(CGRectIntersectsRect(rect, tr.boundingBox)) {
            /*if(!tr.active) {
                CGContextSaveGState(context);
                CGContextSetAlpha(context, 0.7f);
            }*/
            [tr draw:context];
            //if(!tr.active) CGContextRestoreGState(context);
        }
    }
    CGContextRestoreGState(context);
}

-(Station*) checkPoint:(CGPoint*)point Station:(NSMutableString *)stationName selectText:(BOOL *)text
{
    if(text) *text = NO;
    for (Line *l in mapLines) {
        for (Station *s in l.stations) {
            if(CGRectContainsPoint(s.tapArea, *point)) {
                [stationName setString:s.name];
                *point = CGPointMake(s.pos.x, s.pos.y);
                return s;
            }
        }
    }
    for (Line *l in mapLines) {
        for (Station *s in l.stations) {
            if(CGRectContainsPoint(s.tapTextArea, *point)) {
                [stationName setString:s.name];
                *point = CGPointMake(s.pos.x, s.pos.y);
                if(text) *text = YES;
                return s;
            }
        }
    }
    return nil;
}

-(Segment*) checkPoint:(CGPoint *)point segmentPoint:(int *)pIndex
{
    for (Line *l in mapLines) {
        if(CGRectContainsPoint(l.boundingBox, *point)) {
            for (Station *s in l.stations) {
                for (Segment *seg in s.segment) {
                    if(CGRectContainsPoint(seg.boundingBox, *point)) {
                        for(int i =0; i< [seg.linePoints count]; i++) {
                            CGPoint p = [[seg.linePoints objectAtIndex:i] pointValue];
                            CGRect r = CGRectMake(p.x - 5, p.y - 5, 10, 10);
                            if(CGRectContainsPoint(r, *point)) {
                                if(pIndex) *pIndex = i;
                                return seg;
                            }
                        }
                    }
                }
            }
        }
    }
    return nil;
}

-(NSArray*) checkRect:(CGRect)rect
{
    NSMutableArray *res = [NSMutableArray array];
    for (Line *l in mapLines) {
        for (Station *s in l.stations) {
            if(CGRectIntersectsRect(rect, s.tapArea)) {
                [res addObject:s];
            }
        }
    }
    for (Line *l in mapLines) {
        for (Station *s in l.stations) {
            if(CGRectIntersectsRect(s.tapTextArea, rect)) {
                [res addObject:s];
            }
        }
    }
    return res;
}

-(void) drawActive:(CGContextRef)context inRect:(CGRect)rect
{
    CGContextSaveGState(context);
    for (Line* l in mapLines) {
        [l drawActive:context inRect:(CGRect)rect];
    }
    for (Line* l in mapLines) {
        for (Station *s in l.stations) {
            if((s.active || (s.transfer && s.transfer.active)) && s.drawName && CGRectIntersectsRect(s.textRect, rect))
                [s drawName:context];
        }
    }
    for (Transfer *tr in transfers) {
        if(CGRectIntersectsRect(rect, tr.boundingBox)) {
            if(tr.active) 
                [tr draw:context];
        }
    }
    CGContextRestoreGState(context);
}

-(Station*)findNearestStationTo:(CGPoint)gpsCoord
{
    CGFloat sqDist = INFINITY;
    Station *nearest = nil;
    for(Line *l in mapLines) {
        for (Station *s in l.stations) {
            CGPoint dp = CGPointMake(s.gpsCoords.x - gpsCoord.x, s.gpsCoords.y - gpsCoord.y);
            CGFloat d = dp.x * dp.x + dp.y * dp.y;
            if(d < sqDist) {
                sqDist = d;
                nearest = s;
            }
        }
    }
    return nearest;
}

-(CGRect)getGeoCoordsForRect:(CGRect)rect coordinates:(NSMutableArray*)data
{
    BOOL path = [activePath count] > 0;
    [data removeAllObjects];
    CGRect geo = CGRectZero;
    for(Line *l in mapLines) {
        for (Station *s in l.stations) {
            if(CGRectIntersectsRect(s.boundingBox, rect)) {
                CGRect r = CGRectMake(s.gpsCoords.x, s.gpsCoords.y, 0, 0);
                if(geo.origin.x == 0 || geo.origin.y == 0) geo = r;
                else geo = CGRectUnion(geo, r);
                r.size.width = r.size.height = l.shortColorCode;
                if(s.active && path) {
                    NSMutableDictionary *piece = [NSMutableDictionary dictionary];
                    [piece setValue:[NSValue valueWithRect:r] forKey:@"coordinate"];
                    [piece setValue:s.name forKey:@"name"];
                    [piece setValue:[NSNumber numberWithInt:s.line.pinColor] forKey:@"pinColor"];
                    int activeSegments = 0;
                    for (Segment *seg in s.segment) {
                        if(seg.active) activeSegments ++;
                    }
                    for (Segment *seg in s.backSegment) {
                        if(seg.active) activeSegments ++;
                    }
                    if(s.transfer.active) activeSegments ++;
                    if(activeSegments < 2) {
                        [piece setValue:@"YES" forKey:@"ending"];
                    }
                    [data addObject:piece];
                }
            }
        }
    }
    return geo;
}


-(NSMutableArray*) describePath:(NSArray*)pathMap {
 
    NSMutableArray *path = [[NSMutableArray alloc] init];
    
    [path removeAllObjects];
	NSInteger count_ = [pathMap count];
    
    Station *prevStation = nil;
	for (int i=0; i< count_; i++) {
        GraphNode *n1 = [pathMap objectAtIndex:i];
        Line* l = [mapLines objectAtIndex:n1.line-1];
        Station *s = [l getStation:n1.name];
        
        if(i == count_ - 1) {
            
        } else {
            GraphNode *n2 = [pathMap objectAtIndex:i+1];
            if(n1.line == n2.line && [n1.name isEqualToString:n2.name]) {
                // одна и та же станция - пересадка внутри одной линии
                // чё делать пока не понятно
            } else if (n1.line==n2.line) {
                Segment *seg = [l getSegmentFrom:n1.name to:n2.name];
                if(seg != nil) [path addObject:seg];
                else [path addObjectsFromArray:[l getPathFrom:n1.name to:n2.name]];
            } 
            
            if(n1.line != n2.line) {
                [path addObject:s.transfer];
            }
        }
        
        prevStation = s;
        
    }
    
    return path;
}

-(Line*)lineByName:(NSString*)lineName
{
    for (Line *l in mapLines) {
        if([l.name isEqualToString:lineName]) return l;
    }
    return nil;
}

-(void)updateBoundingBox
{
    CGRect boundingBox = CGRectZero;
    for (Line *l in mapLines) {
        boundingBox = CGRectUnion(boundingBox, l.boundingBox);
    }
    if(boundingBox.origin.x > 0) {
        _w = boundingBox.origin.x * 2 + boundingBox.size.width;
    } else {
        _w = boundingBox.size.width;
    }
    if(boundingBox.origin.y > 0) {
        _h = boundingBox.origin.y * 2 + boundingBox.size.height;
    } else {
        _h = boundingBox.size.height;
    }
}

-(NSMutableArray*)copyOfMapLines
{
    NSMutableArray *a = [NSMutableArray array];
    for (Line *l in mapLines) {
        [a addObject:[l superCopy]];
    }
    return a;
}

-(NSMutableArray*) copyOfTransfers
{
    NSMutableArray *a = [NSMutableArray array];
    for (Transfer *t in transfers) {
        [a addObject:[t superCopy]];
    }
    return a;
}

-(void)dropCopy
{
    for (Line *l in mapLines) {
        [l dropCopy];
    }
}

-(void)saveState
{
    NSDictionary *state = @{@"mapLines": [self copyOfMapLines], @"transfers": [self copyOfTransfers]};
    [self dropCopy];
    [undo addObject:state];
    while([undo count] > MAX_UNDO) {
        [undo removeObjectAtIndex:0];
    }
    NSLog(@"save state: %ld", [undo count]);
}

-(BOOL)restoreState
{
    NSDictionary *state = [undo lastObject];
    if(state) {
        mapLines = [state valueForKey:@"mapLines"];
        transfers = [state valueForKey:@"transfers"];
        [self updateBoundingBox];
        [undo removeLastObject];
        NSLog(@"restore state: %ld", [undo count]);
        return YES;
    }
    NSLog(@"no saves!");
    return NO;
}

-(NSUInteger)undoNumber
{
    return [undo count];
}

@end
