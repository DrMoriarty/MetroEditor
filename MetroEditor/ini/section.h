#import <Foundation/Foundation.h>

@interface INISection : NSObject {

	NSMutableDictionary * assignments;
	NSString * sname;
    int unnamed;
    NSMutableArray *orderedKeys;
}

@property (nonatomic, retain)	NSMutableDictionary * assignments;
@property (nonatomic, readonly) NSArray* allKeys;
- initWithName: (NSString *)name;
- (void)insert: (NSString *)name value: (NSString *)value;
- (NSString *)retrieve: (NSString *)name;

@end
