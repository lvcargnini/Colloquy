@class MVChatUser;
@class CQChatController;

#if SYSTEM(MAC)
@protocol JVChatViewController;
#endif

typedef enum {
	JVUserIgnored = 'usIg',
	JVMessageIgnored = 'msIg',
	JVNotIgnored = 'noIg'
} JVIgnoreMatchResult;

@interface KAIgnoreRule : NSObject {
	NSRegularExpression *_userRegex;
	NSRegularExpression *_maskRegex;
	NSRegularExpression *_messageRegex;
}

+ (id) ruleForUser:(NSString *) user mask:(NSString *) mask message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent friendlyName:(NSString *) friendlyName;
- (id) initForUser:(NSString *) user mask:(NSString *) mask message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent friendlyName:(NSString *) friendlyName;

+ (KAIgnoreRule *) ruleForUser:(NSString *) user message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent friendlyName:(NSString *) friendlyName;
- (id) initForUser:(NSString *) user message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent friendlyName:(NSString *) friendlyName;

#if SYSTEM(MAC)
- (JVIgnoreMatchResult) matchUser:(MVChatUser *) user message:(NSString *) message inView:(id <JVChatViewController>) view;
#else
- (JVIgnoreMatchResult) matchUser:(MVChatUser *) user message:(NSString *) message inTargetRoom:(id) target;
#endif

@property (nonatomic, getter=isPermanent) BOOL permanent;
@property (nonatomic, copy) NSString *friendlyName;
@property (nonatomic, copy) NSArray *rooms;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy) NSString *user;
@property (nonatomic, copy) NSString *mask;
@end
