#import "section.h"

@implementation INISection
@synthesize assignments;
@synthesize allKeys = orderedKeys;

- initWithName: (NSString *)name {

	self = [super init];
	assignments = [[NSMutableDictionary alloc] init];
	sname = name;
    unnamed = 0;
    orderedKeys = [[NSMutableArray alloc] init];
	return self;
}

- (void)insert: (NSString *)name value: (NSString *)value {

    if([name length] == 0) {
        name = [NSString stringWithFormat:@"UNNAMED_KEY%d", unnamed++];
    }
	[assignments setObject: value forKey: name];
    [orderedKeys addObject:name];
	return;
}

- (NSString *)retrieve: (NSString *)name {
	NSString * ret;

	ret = [assignments objectForKey: name];
	return ret;
}

@end
