#import <Foundation/NSDictionary.h>

@interface NSDictionary (NSDictionaryAdditions)
- (id) initWithKeys:(NSArray *) keys fromDictionary:(NSDictionary *) dictionary;

- (NSData *) postDataRepresentation; // doesn't support form data
@end
