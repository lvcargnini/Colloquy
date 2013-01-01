#import "CQTableViewController.h"

@implementation CQTableViewController
- (id) initWithStyle:(UITableViewStyle) style {
	if (!(self = [super initWithStyle:style]))
		return nil;
	return self;
}

- (void) dealloc {
	if ([self isViewLoaded]) {
		self.tableView.dataSource = nil;
		self.tableView.delegate = nil;
	}

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}

#pragma mark -

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation {
	if (interfaceOrientation == UIInterfaceOrientationPortrait)
		return YES;
	if (![[UIDevice currentDevice] isPadModel] && interfaceOrientation == UIDeviceOrientationPortraitUpsideDown)
		return NO;
	return ![[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"];
}

- (UIInterfaceOrientation) preferredInterfaceOrientationForPresentation {
	return UIInterfaceOrientationMaskPortrait;
}

- (NSUInteger) supportedInterfaceOrientations {
	UIInterfaceOrientationMask supportedOrientations = UIInterfaceOrientationMaskPortrait;
	if (![UIDevice currentDevice].isPhoneModel)
		supportedOrientations |= UIInterfaceOrientationMaskPortraitUpsideDown;

	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"])
		supportedOrientations |= UIInterfaceOrientationMaskLandscape;

	return supportedOrientations;
}

#pragma mark -

- (void) viewDidLoad {
	[self.tableView hideEmptyCells];
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_reloadTableView) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
}

#pragma mark -

- (void) _reloadTableView {
	if ([self isViewLoaded])
		[self.tableView reloadData];
}
@end
