#import "NSMethodSignatureAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSMethodSignature (NSMethodSignatureAdditions)
+ (id) methodSignatureWithReturnAndArgumentTypes:(const char *) retType, ... {
	NSMutableString *types = [NSMutableString stringWithFormat:@"%s@:", retType];

	char *type = NULL;
	va_list strings;

	va_start( strings, retType );

	while( ( type = va_arg( strings, char * ) ) )
		[types appendString:[NSString stringWithUTF8String:type]];

	va_end( strings );

	return [self signatureWithObjCTypes:[types UTF8String]];
}
@end

NS_ASSUME_NONNULL_END
