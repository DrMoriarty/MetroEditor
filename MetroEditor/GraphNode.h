//
//  GraphNode.h
//  danmaku
//
//  Created by aaron qian on 4/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GraphEdge;

@interface GraphNode : NSObject<NSCopying> {
    NSString* _name;
    int _line;
    int _hash;
    NSMutableSet *edgesIn_;
    NSMutableSet *edgesOut_;
    @public
    // used for path calculating
    double dist;
    id customData;
}

@property (nonatomic, readonly, retain) NSSet *edgesIn;
@property (nonatomic, readonly, retain) NSSet *edgesOut;
@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) int line;

- (id)init;
- (id)initWithName:(NSString*)name andLine:(int)line;
- (BOOL)isEqualToGraphNode:(GraphNode*)otherNode;

- (NSUInteger)inDegree;
- (NSUInteger)outDegree;
- (BOOL)isSource;
- (BOOL)isSink;
- (NSMutableSet*)outNodes;
- (NSMutableSet*)inNodes;
- (GraphEdge*)edgeConnectedTo:(GraphNode*)toNode;
- (GraphEdge*)edgeConnectedFrom:(GraphNode*)fromNode;

+ (id)node;
+ (id)nodeWithName:(NSString*)name andLine:(int)line;
@end
