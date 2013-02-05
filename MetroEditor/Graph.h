//
//  Graph.h
//  danmaku
//
//  Created by aaron qian on 4/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GraphEdge.h"
#import "GraphNode.h"

@interface Graph : NSObject {
    NSMutableSet *nodes_;
}

@property (nonatomic, readonly, retain) NSSet *nodes;

- (NSDictionary*)getPaths:(GraphNode*)source to:(GraphNode*)target;
- (NSArray*)getWays:(GraphNode *)source to:(GraphNode *)target withoutStations:(NSSet*)clNodes;
- (NSArray*)shortestPath:(GraphNode*)source to:(GraphNode*)target;
// compare node's names and lines
- (NSArray*)shortestPath:(GraphNode*)source to:(GraphNode*)target weight:(CGFloat*)weight closedNodes:(NSSet*)clNodes;
// compare only node's names
- (NSArray*)shortestWay:(GraphNode*)source to:(GraphNode*)target weight:(CGFloat*)weight closedNodes:(NSSet*)clNodes;
- (GraphNode*)addNode:(GraphNode*)node;
- (GraphEdge*)addEdgeFromNode:(GraphNode*)fromNode toNode:(GraphNode*)toNode;
- (GraphEdge*)addEdgeFromNode:(GraphNode*)fromNode toNode:(GraphNode*)toNode withWeight:(float)weight;
- (void)removeNode:(GraphNode*)node;
- (void)removeEdge:(GraphEdge*)edge;
- (BOOL)hasNode:(GraphNode*)node;
+ (Graph*)graph;

@end
