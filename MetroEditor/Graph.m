//
//  Graph.m
//  danmaku
//
//  Created by aaron qian on 4/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Graph.h"

@interface GraphNode()
@property (nonatomic, readwrite, retain) NSSet *edgesIn;
@property (nonatomic, readwrite, retain) NSSet *edgesOut;
@property (nonatomic, readwrite, retain) id    value;
- (GraphEdge*)linkToNode:(GraphNode*)node;
- (GraphEdge*)linkToNode:(GraphNode*)node weight:(float)weight;
- (GraphEdge*)linkFromNode:(GraphNode*)node;
- (GraphEdge*)linkFromNode:(GraphNode*)node weight:(float)weight;
- (void)unlinkToNode:(GraphNode*)node;
- (void)unlinkFromNode:(GraphNode*)node;
@end

// private methods for Graph
@interface Graph()
@property (nonatomic, readwrite, retain) NSSet *nodes;
- (GraphNode*)smallest_distance:(NSMutableSet*)nodes;
@end


@implementation Graph

@synthesize nodes = nodes_;

- (id)init
{
    if ( (self = [super init]) ) {
        self.nodes = [NSMutableSet set];
    }
    
    return self;
}

-(NSArray*)shortestPath:(GraphNode *)source to:(GraphNode *)target weight:(CGFloat *)weight closedNodes:(NSSet *)clNodes
{
    if (![nodes_ containsObject:source] || ![nodes_ containsObject:target]) 
    {
        return [NSArray array];
    }
    if([source isEqualToGraphNode:target]) return [NSArray array];
    
    NSMutableSet* remaining = [nodes_ mutableCopy];
    
    GraphNode *minNode = nil;
    for(GraphNode* node in [remaining objectEnumerator]) {
        node->customData = nil;
        if([node isEqualToGraphNode:source]) {
            node->dist = 0.0f;
            minNode = node;
        } 
        else node->dist = INFINITY;
    }
    if(clNodes != nil) {
        [remaining minusSet:clNodes];
    }
    
    while ([remaining count] != 0) {
        if(minNode == nil) {
            // find the node in remaining with the smallest distance
            minNode = [self smallest_distance:remaining];
            
            if (minNode->dist == INFINITY)
                break;
            
            // we found it!
            if( [minNode isEqualToGraphNode:target] ) {
                if(weight != nil) *weight = minNode->dist;
                NSMutableArray* path = [NSMutableArray array];
                GraphNode* temp = minNode;
                while (temp != nil) {
                    [path addObject:temp];
                    temp = temp->customData;
                }
                return [ NSMutableArray arrayWithArray:
                        [ [path reverseObjectEnumerator ] allObjects]];
            }
        }
        
        // didn't find it yet, keep going
        
        [remaining removeObject:minNode];
        
        // find neighbors that have not been removed yet
        NSMutableSet* neighbors = [minNode outNodes];
        [neighbors intersectSet:remaining];
        
        // loop through each neighbor to find min dist
        for (GraphNode* neighbor in [neighbors objectEnumerator]) {
            //NSLog(@"Looping neighbor %@", (NSString*)[neighbor value]);
            BOOL setPrevPath = YES;
            float alt = minNode->dist;
            alt += [[minNode edgeConnectedTo: neighbor] weight];
            
            if( alt < neighbor->dist ) {
                neighbor->dist = alt;
                if(setPrevPath) neighbor->customData = minNode;
                else neighbor->customData = nil;
            }
        }
        minNode = nil;
    }
    
    return [NSArray array];
}

-(NSArray*)shortestWay:(GraphNode *)source to:(GraphNode *)target weight:(CGFloat *)weight closedNodes:(NSSet *)clNodes
{
    if (![nodes_ containsObject:source] || ![nodes_ containsObject:target]) 
    {
        return [NSArray array];
    }
    if([source isEqualToGraphNode:target]) return [NSArray array];
    
    NSMutableSet* remaining = [nodes_ mutableCopy];
    
    GraphNode *minNode = nil;
    for(GraphNode* node in [remaining objectEnumerator]) {
        node->customData = nil;
        if([node isEqualToGraphNode:source]) {
            node->dist = 0.0f;
            minNode = node;
        } 
        else node->dist = INFINITY;
    }
    if(clNodes != nil) {
        [remaining minusSet:clNodes];
    }
    
    while ([remaining count] != 0) {
        if(minNode == nil) {
            // find the node in remaining with the smallest distance
            minNode = [self smallest_distance:remaining];
            
            if (minNode->dist == INFINITY)
                break;
            
            // we found it!
            if( [minNode.name isEqualToString:target.name] ) {
                if(weight != nil) *weight = minNode->dist;
                NSMutableArray* path = [NSMutableArray array];
                GraphNode* temp = minNode;
                while (temp != nil) {
                    [path addObject:temp];
                    temp = temp->customData;
                }
                return [ NSMutableArray arrayWithArray:
                        [ [path reverseObjectEnumerator ] allObjects]];
            }
        }
        
        // didn't find it yet, keep going
        
        [remaining removeObject:minNode];
        
        // find neighbors that have not been removed yet
        NSMutableSet* neighbors = [minNode outNodes];
        [neighbors intersectSet:remaining];
        
        // loop through each neighbor to find min dist
        for (GraphNode* neighbor in [neighbors objectEnumerator]) {
            //NSLog(@"Looping neighbor %@", (NSString*)[neighbor value]);
            BOOL setPrevPath = YES;
            float alt = minNode->dist;
            alt += [[minNode edgeConnectedTo: neighbor] weight];
            
            if( alt < neighbor->dist ) {
                neighbor->dist = alt;
                if(setPrevPath) neighbor->customData = minNode;
                else neighbor->customData = nil;
            }
        }
        minNode = nil;
    }
    
    return [NSArray array];
}

// Using Dijkstra's algorithm to find shortest path
// See http://en.wikipedia.org/wiki/Dijkstra%27s_algorithm
- (NSArray*)shortestPath:(GraphNode*)source to:(GraphNode*)target {
    return [self shortestPath:source to:target weight:nil closedNodes:nil];
}

-(BOOL)normalizePath:(NSMutableArray*)path
{
    BOOL changed = NO;
    if([path count] > 2) {
        if([[path objectAtIndex:0] line] != [[path objectAtIndex:1] line]) {
            [path removeObjectAtIndex:0];
            changed = YES;
        }
        if([[path lastObject] line] != [[path objectAtIndex:[path count]-2] line]) {
            [path removeLastObject];
            changed = YES;
        }
        GraphNode* prevEl = nil;
        int transfers = 0;
        NSMutableArray *remList = [NSMutableArray array];
        for (GraphNode* el in path) {
            if(prevEl.line != el.line) transfers ++;
            else transfers = 0;
            if(transfers > 1) {
                [remList addObject:prevEl];
                changed = YES;
            }
            prevEl = el;
        }
        for (GraphNode *el in remList) {
            [path removeObject:el];
        }
    }
    return changed;
}

-(void)normalizePaths:(NSMutableDictionary*)paths
{
    for (NSNumber* n in [paths allKeys]) {
        NSArray *path = [paths objectForKey:n];
        NSMutableArray *npath = [NSMutableArray arrayWithArray:path];
        BOOL changed = [self normalizePath:npath];
        if(changed) {
            [paths setObject:npath forKey:n];
        }
    }
}

-(void)normalizePathsArray:(NSMutableArray*)paths
{
    NSMutableArray *paths2 = [NSMutableArray array];
    for (NSArray *path in paths) {
        NSMutableArray *npath = [NSMutableArray arrayWithArray:path];
        BOOL changed = [self normalizePath:npath];
        if(changed) {
            [paths2 addObject:npath];
        } else {
            [paths2 addObject:path];
        }
    }
    [paths setArray:paths2];
}

-(NSDictionary*)getPaths:(GraphNode*)source to:(GraphNode*)target {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    CGFloat weight = 0;
    NSArray *path = [self shortestPath:source to:target weight:&weight closedNodes:nil];
    [result setObject:path forKey:[NSNumber numberWithFloat:weight]];
    
    int prevLine = -1;
    int nodeNum = 0;
    for (GraphNode *n in path) {
        if((prevLine > 0 && prevLine != n.line) || nodeNum == 1) {
            NSArray *altPath = [self shortestPath:source to:target weight:&weight closedNodes:[NSSet setWithObject:n]];
            if([altPath count] > 0)
                [result setObject:altPath forKey:[NSNumber numberWithFloat:weight]];
            if([result count] >= 3) break; // max 3 paths
        }
        prevLine = n.line;
        nodeNum ++;
    }
    [self normalizePaths:result];
    
    return result;
}

-(NSArray*)getWays:(GraphNode *)source to:(GraphNode *)target withoutStations:(NSSet *)clNodes
{
    NSMutableArray *result = [NSMutableArray array];
    
    CGFloat weight = 0;
    NSArray *path = [self shortestWay:source to:target weight:&weight closedNodes:clNodes];
    [result addObject:path];
    
    int prevLine = -1;
    int nodeNum = 0;
    for (GraphNode *n in path) {
        if((prevLine > 0 && prevLine != n.line) || nodeNum == 1) {
            NSMutableSet *cll = [NSMutableSet setWithSet:clNodes];
            [cll addObject:n];
            NSArray *altPath = [self shortestWay:source to:target weight:&weight closedNodes:cll];
            if([altPath count] > 0)
                [result addObject:altPath];
            if([result count] >= 5) break; // max 5 paths
        }
        prevLine = n.line;
        nodeNum ++;
    }
    [self normalizePathsArray:result];
    
    return result;
}

- (GraphNode*)smallest_distance:(NSMutableSet*)nodes {
    NSEnumerator *e = [nodes objectEnumerator];
    GraphNode* node;
    GraphNode* minNode = [e nextObject];
    float min = minNode->dist;
    
    while ( (node = [e nextObject]) ) {
        float temp = node->dist;
        
        if ( temp < min ) {
            min = temp;
            minNode = node;
        }
    }
    
    return minNode;
}

- (BOOL)hasNode:(GraphNode*)node {
    return !![nodes_ member:node];
}

// addNode first checks to see if we already have a node
// that is equal to the passed in node.
// If an equal node already exists, the existing node is returned
// Otherwise, the new node is added to the set and then returned.
- (GraphNode*)addNode:(GraphNode*)node {
    GraphNode* existing = [nodes_ member:node];
    if (!existing) {
       [nodes_ addObject:node]; 
        existing = node;
    }
    return existing;
}

- (GraphEdge*)addEdgeFromNode:(GraphNode*)fromNode toNode:(GraphNode*)toNode {
    fromNode = [self addNode:fromNode];
    toNode   = [self addNode:toNode];
    return [fromNode linkToNode:toNode];
}

- (GraphEdge*)addEdgeFromNode:(GraphNode*)fromNode toNode:(GraphNode*)toNode withWeight:(float)weight {
    fromNode = [self addNode:fromNode];
    toNode   = [self addNode:toNode];
    return [fromNode linkToNode:toNode weight:weight];    
}

- (void)removeNode:(GraphNode*)node {
    [nodes_ removeObject:node];
}

- (void)removeEdge:(GraphEdge*)edge {
    [[edge fromNode] unlinkToNode:[edge toNode]];
}

+ (Graph*)graph {
    return [[self alloc] init];
}

@end
