#import <ChatCore/MVChatPluginManager.h>

@interface MVChatScriptPlugin : NSObject <MVChatPlugin> {
	NSAppleScript *_script;
	NSMutableSet *_doseNotRespond;
}
- (id) initWithScript:(NSAppleScript *) script andManager:(MVChatPluginManager *) manager;

- (NSAppleScript *) script;
- (id) callScriptHandler:(unsigned long) handler withArguments:(NSDictionary *) arguments forSelector:(SEL) selector;

- (BOOL) respondsToSelector:(SEL) selector;
- (void) doesNotRespondToSelector:(SEL) selector;
@end

@interface NSAppleScript (NSAppleScriptIdentifier)
- (NSNumber *) scriptIdentifier;
@end