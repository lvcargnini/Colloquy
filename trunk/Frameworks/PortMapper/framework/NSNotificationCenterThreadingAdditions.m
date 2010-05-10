#import "NSNotificationCenterThreadingAdditions.h"
#import <pthread.h>

@implementation NSNotificationCenter (NSNotificationCenterThreadingAdditions)

+ (void)_postNotification:(NSNotification *)aNotification {
    [[self defaultCenter] postNotification:aNotification];
}

+ (void)_postNotificationViaDictionary:(NSDictionary *)anInfoDictionary {
    NSString *name   = [anInfoDictionary objectForKey:@"name"];
    id        object = [anInfoDictionary objectForKey:@"object"];
    [[self defaultCenter] postNotificationName:name 
                                        object:object 
                                      userInfo:nil];
}


- (void)postNotificationOnMainThread:(NSNotification *)aNotification {
    if( pthread_main_np() ) return [self postNotification:aNotification];
    [[self class] performSelectorOnMainThread:@selector( _postNotification: ) withObject:aNotification waitUntilDone:NO];
}

- (void) postNotificationOnMainThreadWithName:(NSString *)aName object:(id)anObject {
    if( pthread_main_np() ) return [self postNotificationName:aName object:anObject userInfo:nil];
    NSMutableDictionary *info = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:2];
    if (aName) {
        [info setObject:aName forKey:@"name"];
    }
    if (anObject) {
        [info setObject:anObject forKey:@"object"];
    }
    [[self class] performSelectorOnMainThread:@selector(_postNotificationViaDictionary:)
                                   withObject:info 
                                waitUntilDone:NO];
	[info release];
}
@end
