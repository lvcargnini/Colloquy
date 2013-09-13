#import "NSRegularExpressionAdditions.h"

@implementation NSRegularExpression (Additions)
+ (NSRegularExpression *) cachedRegularExpressionWithPattern:(NSString *) pattern options:(NSRegularExpressionOptions) options error:(NSError *__autoreleasing*) error {
	static NSMutableDictionary *dangerousCache = nil;
	static dispatch_once_t pred;
	dispatch_once(&pred, ^{
		dangerousCache = [[NSMutableDictionary alloc] init];
	});

#if SYSTEM(MAC)
	NSString *key = [NSString stringWithFormat:@"%ld-%@", options, pattern];
#else
	NSString *key = [NSString stringWithFormat:@"%tu-%@", options, pattern];
#endif
	NSRegularExpression *regularExpression = dangerousCache[key];

	if (regularExpression)
		return regularExpression;

	regularExpression = [NSRegularExpression regularExpressionWithPattern:pattern options:options error:nil];

	dangerousCache[key] = regularExpression;

	return regularExpression;
}
@end
