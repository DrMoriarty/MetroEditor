#include <stdio.h>
#include <string.h>

#import "ini.h"

@implementation INIParser (Parsing)

- (int)parse: (const char *)filename
{
	int err;
	char buf [4096];
	char * lb;
	FILE * file;
	
	file = fopen (filename, "r");
	if (file == NULL)
		return INIP_ERROR_FOPEN_FAILED;

	while (1) {
		if (fgets (buf, 4095, file) == NULL)
			break;

		lb = [self trim: buf];
		//if (*lb == 0)
		//	break;

		if ((*lb != 0)){
			err = [self parseLine: lb];
			if (err != INIP_ERROR_NONE) {
				fclose (file);
				return err;
			}
			
		}
	}
	
	fclose (file);
	return INIP_ERROR_NONE;
}

- (int)parseLine: (char *) line
{
	int err;

    if (*line == ';') err = INIP_ERROR_NONE;  // comment
	else if (*line == '[') err = [self parseSection: line];
	else err = [self parseAssignment: line];
	
	return err;
}

- (int)parseSection: (char *)line
{
	INISection * section;
	NSString * name;
	char * l;
	
	l = strchr (line, ']');
	if (l == NULL)
		return INIP_ERROR_INVALID_SECTION;
	
	*l = 0;
	name = [NSString stringWithUTF8String: line +1];
	section = [[INISection alloc] initWithName: name];
	[sections setObject: section forKey: [name uppercaseString]];
	csection = section;
	return INIP_ERROR_NONE;
}

- (int)parseAssignment: (char *)line
{
	char * name, * value;
	NSString * n, * v;
	
	if (csection == nil)
		return INIP_ERROR_NO_SECTION;

	name = line;
	value = strchr (name, '=');
	if (value == NULL) {
        value = strchr(name , '\t');  // use tab separated substrings as key value pair
        if(value == NULL) {
            value = strchr(name, ' '); // and space separated 
            if(value == NULL) 
                return INIP_ERROR_INVALID_ASSIGNMENT;
        }
    }
	
	*value++ = 0;
    name = [self trim:name];
    value = [self trim:value];
	n = [NSString stringWithUTF8String: name];
	v = [NSString stringWithUTF8String: value];
	[csection insert: [n uppercaseString] value: v];
	return INIP_ERROR_NONE;
}

@end
