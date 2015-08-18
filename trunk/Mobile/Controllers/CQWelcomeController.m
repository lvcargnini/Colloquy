#import "CQWelcomeController.h"

#import "CQColloquyApplication.h"
#import "CQHelpTopicsViewController.h"
#import "CQWelcomeViewController.h"

NS_ASSUME_NONNULL_BEGIN

@implementation  CQWelcomeController
- (void) viewDidLoad {
	if (_shouldShowOnlyHelpTopics && !_rootViewController)
		_rootViewController = [[CQHelpTopicsViewController alloc] init];
	else if (!_rootViewController)
		_rootViewController = [[CQWelcomeViewController alloc] init];

	[super viewDidLoad];

	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close:)];
	_rootViewController.navigationItem.leftBarButtonItem = doneButton;
}

- (void) close:(__nullable id) sender {
	if (!_shouldShowOnlyHelpTopics)
		[[CQColloquyApplication sharedApplication] showConnections:nil];

	[super close:sender];
}
@end

NS_ASSUME_NONNULL_END
