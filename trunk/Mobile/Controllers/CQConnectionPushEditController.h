#import "CQTableViewController.h"

@class MVChatConnection;

NS_ASSUME_NONNULL_BEGIN

@interface CQConnectionPushEditController : CQTableViewController {
	@protected
	MVChatConnection *_connection;
}
@property (nonatomic, strong) MVChatConnection *connection;
@property (nonatomic, assign) BOOL newConnection;
@end

NS_ASSUME_NONNULL_END
