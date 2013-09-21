#import "CQChatNavigationController.h"

#import "CQChatController.h"
#import "CQChatListViewController.h"
#import "CQColloquyApplication.h"

@implementation CQChatNavigationController
- (id) init {
	if (!(self = [super init]))
		return nil;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_userDefaultsChanged) name:CQSettingsDidChangeNotification object:nil];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	self.delegate = nil;
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	if (!_chatListViewController) {
		_chatListViewController = [[CQChatListViewController alloc] init];
		[self pushViewController:_chatListViewController animated:NO];

		self.title = NSLocalizedString(@"Colloquies", @"Colloquies tab title");
		self.tabBarItem.image = [UIImage imageNamed:@"colloquies.png"];
		self.delegate = self;

		if (![UIDevice currentDevice].isSystemSeven)
			self.navigationBar.tintColor = [CQColloquyApplication sharedApplication].tintColor;
	}

	[[CQChatController defaultController] showPendingChatControllerAnimated:NO];
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

- (void) navigationController:(UINavigationController *) navigationController didShowViewController:(UIViewController *) viewController animated:(BOOL) animated {
	if ([[UIDevice currentDevice] isPadModel])
		return;

	if (viewController == self.rootViewController) {
		[[CQChatController defaultController] visibleChatControllerWasHidden];

		if ([[CQChatController defaultController] hasPendingChatController])
			[self performSelector:@selector(_showNextChatController) withObject:nil afterDelay:0.33];
	}
}

#pragma mark -

- (void) selectChatViewController:(id) controller animatedSelection:(BOOL) animatedSelection animatedScroll:(BOOL) animatedScroll {
	[_chatListViewController selectChatViewController:controller animatedSelection:animatedSelection animatedScroll:animatedScroll];
}

#pragma mark -

- (void) _showNextChatController {
	[[CQChatController defaultController] showPendingChatControllerAnimated:YES];
}

- (void) _userDefaultsChanged {
	if (![NSThread isMainThread])
		return;

	if (![UIDevice currentDevice].isSystemSeven)
		self.navigationBar.tintColor = [CQColloquyApplication sharedApplication].tintColor;
}
@end
