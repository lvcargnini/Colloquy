#import "CQChatNavigationController.h"

#import "CQChatController.h"
#import "CQChatListViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface CQChatNavigationController () <UINavigationControllerDelegate>
@end

@implementation CQChatNavigationController {
	CQChatListViewController *_chatListViewController;
	BOOL _active;
}

- (instancetype) init {
	if (!(self = [super init]))
		return nil;

	self.title = NSLocalizedString(@"Colloquies", @"Colloquies tab title");

	return self;
}

- (void) dealloc {
	self.delegate = nil;
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	if (!_chatListViewController) {
		_chatListViewController = [[CQChatListViewController alloc] init];
		[self pushViewController:_chatListViewController animated:NO];

		self.delegate = self;
	}
}

#pragma mark -

- (void) pushViewController:(UIViewController *) controller animated:(BOOL) animated {
	if ([controller conformsToProtocol:@protocol(CQChatViewController)])
		[_chatListViewController selectChatViewController:(id <CQChatViewController>)controller animatedSelection:NO animatedScroll:animated];
	[super pushViewController:controller animated:animated];
}

#pragma mark -

- (void) navigationController:(UINavigationController *) navigationController willShowViewController:(UIViewController *) viewController animated:(BOOL) animated {
	if (viewController == self.rootViewController)
		[CQChatController defaultController].totalImportantUnreadCount = 0;
}

#pragma mark -

- (void) selectChatViewController:(id) controller animatedSelection:(BOOL) animatedSelection animatedScroll:(BOOL) animatedScroll {
	[_chatListViewController selectChatViewController:controller animatedSelection:animatedSelection animatedScroll:animatedScroll];
}

#pragma mark -

- (void) _showNextChatController {
	[[CQChatController defaultController] showPendingChatControllerAnimated:YES];
}
@end

NS_ASSUME_NONNULL_END
