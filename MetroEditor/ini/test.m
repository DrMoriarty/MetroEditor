
#include <stdio.h>
#import "ini.h"

int main (c, args)
	char **		args;
{
	INIParser * parser;
	NSAutoreleasePool * pool;
	NSString * str;
	int songcnt;
	BOOL isalbum;
	int err;

	pool = [[NSAutoreleasePool alloc] init];
	parser = [[INIParser alloc] init];
	err = [parser parse: args [1]];
	if (err != INIP_ERROR_NONE) {
		printf ("%s: parse failed: %i\n", args [1], err);
		[parser release];
		return 1;
	}

	str = [parser get: @"ALBUM1" section: @"Supertramp Albums"];
	printf ("Name: '%s', Value='%s'\n", "ALBUM1", [str cString]);

	songcnt = [parser getInt: @"SONGCNT" section: @"Supertramp Albums"];
	printf ("SONGCNT=%i\n", songcnt);

	isalbum = [parser getBool: @"ISALBUM" section: @"Supertramp Albums"];
	printf ("ISALBUM: %s\n", ((isalbum == YES) ? "YES" : "NO"));

	[parser release];
	[pool release];
	return 0;
}
