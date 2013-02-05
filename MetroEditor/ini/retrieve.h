
@interface INIParser (Retrieve)

- (BOOL)exists: (NSString *)name section: (NSString *)section;
- (INISection *)getSection: (NSString *)name;
- (NSString *)get: (NSString *)name section: (NSString *)section;
- (BOOL)getBool: (NSString *)name section: (NSString *)section;
- (int)getInt: (NSString *)name section: (NSString *)section;

@end
