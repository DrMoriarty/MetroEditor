#import <Foundation/Foundation.h>
#import "section.h"

#define INIP_ERROR_NONE			0
#define INIP_ERROR_INVALID_ASSIGNMENT	1
#define INIP_ERROR_FOPEN_FAILED		2
#define INIP_ERROR_INVALID_SECTION	3
#define INIP_ERROR_NO_SECTION		4

@interface INIParser : NSObject {

	NSMutableDictionary * sections;
	INISection * csection;
}

- init;

@end

#import "utils.h"
#import "parse.h"
#import "retrieve.h"
