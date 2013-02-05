
#import "ini.h"

@implementation INIParser

- init {

	self = [super init];
	sections = [[NSMutableDictionary alloc] init];
	return self;
}


@end
