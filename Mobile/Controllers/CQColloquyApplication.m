#import "CQColloquyApplication.h"

#import "CQAlertView.h"
#import "CQAnalyticsController.h"
#import "CQChatController.h"
#import "CQChatCreationViewController.h"
#import "CQChatListViewController.h"
#import "CQChatNavigationController.h"
#import "CQChatPresentationController.h"
#import "CQConnectionsController.h"
#import "CQConnectionsNavigationController.h"
#import "CQWelcomeController.h"
#import "RegexKitLite.h"

#import "CQPocketController.h"

typedef enum {
	CQSidebarOrientationNone,
	CQSidebarOrientationPortrait,
	CQSidebarOrientationLandscape,
	CQSidebarOrientationAll
} CQSidebarOrientation;

NSString *CQColloquyApplicationDidRecieveDeviceTokenNotification = @"CQColloquyApplicationDidRecieveDeviceTokenNotification";

#define BrowserAlertTag 1

static NSMutableArray *highlightWords;

@implementation CQColloquyApplication
+ (CQColloquyApplication *) sharedApplication {
	return (CQColloquyApplication *)[UIApplication sharedApplication];
}

- (id) init {
	if (!(self = [super init]))
		return nil;

	_launchDate = [[NSDate alloc] init];
	_resumeDate = [_launchDate copy];

	return self;
}

#pragma mark -

- (UIWindow *) window {
	return _mainWindow;
}

- (UITabBarController *) tabBarController {
	if ([_mainViewController isKindOfClass:[UITabBarController class]])
		return (UITabBarController *)_mainViewController;
	return nil;
}

- (UISplitViewController *) splitViewController {
	if ([_mainViewController isKindOfClass:[UISplitViewController class]])
		return (UISplitViewController *)_mainViewController;
	return nil;
}

#pragma mark -

- (NSSet *) handledURLSchemes {
	static NSMutableSet *schemes;
	if (!schemes) {
		schemes = [[NSMutableSet alloc] init];

		NSArray *urlTypes = [NSBundle mainBundle].infoDictionary[@"CFBundleURLTypes"];
		for (NSDictionary *type in urlTypes) {
			NSArray *schemesForType = type[@"CFBundleURLSchemes"];
			for (NSString *scheme in schemesForType)
				[schemes addObject:scheme.lowercaseString];
		}
	}

	return schemes;
}

- (NSArray *) highlightWords {
	if (!highlightWords) {
		highlightWords = [[NSMutableArray alloc] init];

		NSString *highlightWordsString = [[CQSettingsController settingsController] stringForKey:@"CQHighlightWords"];
		if (highlightWordsString.length) {
			[highlightWords addObjectsFromArray:[highlightWordsString cq_componentsMatchedByRegex:@"(?<=\\s|^)[/\"'](.*?)[/\"'](?=\\s|$)" capture:1]];

			highlightWordsString = [highlightWordsString stringByReplacingOccurrencesOfRegex:@"(?<=\\s|^)[/\"'](.*?)[/\"'](?=\\s|$)" withString:@""];

			[highlightWords addObjectsFromArray:[highlightWordsString componentsSeparatedByString:@" "]];
			[highlightWords removeObject:@""];
		}
	}

	return highlightWords;
}

- (void) updateAnalytics {
	CQAnalyticsController *analyticsController = [CQAnalyticsController defaultController];

	[analyticsController setObject:[[[CQSettingsController settingsController] stringForKey:@"CQChatTranscriptStyle"] lowercaseString] forKey:@"transcript-style"];

	NSString *information = ([[CQSettingsController settingsController] boolForKey:@"CQGraphicalEmoticons"] ? @"emoji" : @"text");
	[analyticsController setObject:information forKey:@"emoticon-style"];

	information = ([[CQSettingsController settingsController] boolForKey:@"CQDisableLandscape"] ? @"0" : @"1");
	[analyticsController setObject:information forKey:@"landscape"];

	information = ([[CQSettingsController settingsController] boolForKey:@"CQDisableBuiltInBrowser"] ? @"0" : @"1");
	[analyticsController setObject:information forKey:@"browser"];

	information = [[NSLocale autoupdatingCurrentLocale] localeIdentifier];
	[analyticsController setObject:information forKey:@"locale"];

	[analyticsController setObject:[[[CQSettingsController settingsController] stringForKey:@"CQChatAutocompleteBehavior"] lowercaseString] forKey:@"autocomplete-behavior"];

	[analyticsController setObject:[[CQSettingsController settingsController] objectForKey:@"CQMultitaskingTimeout"] forKey:@"multitasking-timeout"];

	NSInteger showNotices = [[CQSettingsController settingsController] integerForKey:@"JVChatAlwaysShowNotices"];
	information = (!showNotices ? @"auto" : (showNotices == 1 ? @"all" : @"none"));
	[analyticsController setObject:information forKey:@"notices-behavior"];

	information = ([[[CQSettingsController settingsController] stringForKey:@"JVQuitMessage"] hasCaseInsensitiveSubstring:@"Colloquy for"] ? @"default" : @"custom");
	[analyticsController setObject:information forKey:@"quit-message"];
}

- (void) setDefaultMessageStringForKey:(NSString *) key {
	NSString *message = [[CQSettingsController settingsController] stringForKey:key];
	if ([message hasCaseInsensitiveSubstring:@"Colloquy for iPhone"]) {
		message = [NSString stringWithFormat:NSLocalizedString(@"Colloquy for %@ - http://colloquy.mobi", @"Status message, with the device name inserted"), [UIDevice currentDevice].localizedModel];
		[[CQSettingsController settingsController] setObject:message forKey:key];
	}
}

- (void) userDefaultsChanged {
	if (![NSThread isMainThread])
		return;

	highlightWords = nil;

	if ([UIDevice currentDevice].isPadModel) {
		NSNumber *newSwipeOrientationValue = [[CQSettingsController settingsController] objectForKey:@"CQSplitSwipeOrientations"];

		if (![_oldSwipeOrientationValue isEqualToNumber:newSwipeOrientationValue]) {
			_oldSwipeOrientationValue = [newSwipeOrientationValue copy];

			if (self.modalViewController)
				_userDefaultsChanged = YES;
			else [self reloadSplitViewController];

			BOOL disableSingleSwipe = [self splitViewController:nil shouldHideViewController:nil inOrientation:UIInterfaceOrientationLandscapeLeft] || [self splitViewController:nil shouldHideViewController:nil inOrientation:UIInterfaceOrientationPortrait];
			if (disableSingleSwipe)
				[[CQSettingsController settingsController] setInteger:0 forKey:@"CQSingleFingerSwipe"];
		}
	}

	[self updateAnalytics];
}

- (void) performDeferredLaunchWork {
	NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
	NSString *version = infoDictionary[@"CFBundleShortVersionString"];

	if (![[[CQSettingsController settingsController] stringForKey:@"CQLastVersionUsed"] isEqualToString:version]) {
		NSString *bundleVersion = infoDictionary[@"CFBundleVersion"];
		NSString *displayVersion = nil;
		if (bundleVersion.length)
			displayVersion = [NSString stringWithFormat:@"%@ (%@)", version, bundleVersion];
		else displayVersion = version;
		[[CQSettingsController settingsController] setObject:displayVersion forKey:@"CQCurrentVersion"];

		if (![[CQSettingsController settingsController] boolForKey:@"JVSetUpDefaultQuitMessage"]) {
			[self setDefaultMessageStringForKey:@"JVQuitMessage"];
			[[CQSettingsController settingsController] setBool:YES forKey:@"JVSetUpDefaultQuitMessage"];
		}

		if (![[CQSettingsController settingsController] boolForKey:@"JVSetUpDefaultAwayMessage"]) {
			[self setDefaultMessageStringForKey:@"CQAwayStatus"];
			[[CQSettingsController settingsController] setBool:YES forKey:@"JVSetUpDefaultAwayMessage"];
		}

		if (![CQConnectionsController defaultController].connections.count && ![CQConnectionsController defaultController].bouncers.count)
			[self showWelcome:nil];

		[[CQSettingsController settingsController] setObject:version forKey:@"CQLastVersionUsed"];
	}

	CQAnalyticsController *analyticsController = [CQAnalyticsController defaultController];

	NSString *information = infoDictionary[@"CFBundleShortVersionString"];
	[analyticsController setObject:information forKey:@"application-version"];

	information = infoDictionary[@"CFBundleVersion"];
	[analyticsController setObject:information forKey:@"application-build-version"];

#if TARGET_IPHONE_SIMULATOR
	information = @"simulator";
#else
	if ([infoDictionary objectForKey:@"SignerIdentity"]) {
		information = @"cracked";
	} else {
		NSString *type = [infoDictionary objectForKey:@"CQBuildType"];
		BOOL officialBundleIdentifier = [[infoDictionary objectForKey:@"CFBundleIdentifier"] isEqualToString:@"info.colloquy.mobile"];
		if ([type isEqualToString:@"personal"] || !officialBundleIdentifier)
			information = @"personal";
		else if ([type isEqualToString:@"beta"] && officialBundleIdentifier)
			information = @"beta";
		else if ([type isEqualToString:@"official"] || officialBundleIdentifier)
			information = @"official";
	}
#endif

	[analyticsController setObject:information forKey:@"install-type"];

	information = [[NSLocale autoupdatingCurrentLocale] localeIdentifier];
	[analyticsController setObject:information forKey:@"locale"];

	[analyticsController setObject:([UIDevice currentDevice].multitaskingSupported ? @"1" : @"0") forKey:@"multitasking-supported"];
	[analyticsController setObject:@([UIScreen mainScreen].scale) forKey:@"screen-scale-factor"];

	if (_deviceToken.length)
		[analyticsController setObject:_deviceToken forKey:@"device-push-token"];

	[self updateAnalytics];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDefaultsChanged) name:CQSettingsDidChangeNotification object:nil];
}

- (void) handleNotificationWithUserInfo:(NSDictionary *) userInfo {
	if (!userInfo.count)
		return;

	NSString *connectionServer = userInfo[@"s"];
	NSString *connectionIdentifier = userInfo[@"c"];
	if (connectionServer.length || connectionIdentifier.length) {
		NSString *roomName = userInfo[@"r"];
		NSString *senderNickname = userInfo[@"n"];
		NSString *action = userInfo[@"a"];

		MVChatConnection *connection = nil;

		if (connectionIdentifier.length)
			connection = [[CQConnectionsController defaultController] connectionForUniqueIdentifier:connectionIdentifier];
		if (!connection && connectionServer.length)
			connection = [[CQConnectionsController defaultController] connectionForServerAddress:connectionServer];

		if (connection) {
			[connection connectAppropriately];

			BOOL animationEnabled = [UIView areAnimationsEnabled];
			[UIView setAnimationsEnabled:NO];

			if (![[UIDevice currentDevice] isPadModel])
				self.tabBarController.selectedViewController = [CQChatController defaultController].chatNavigationController;;

			if (roomName.length) {
				if ([action isEqualToString:@"j"])
					[connection joinChatRoomNamed:roomName];
				[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:roomName andConnection:connection];
			} else if (senderNickname.length) {
				[[CQChatController defaultController] showChatControllerForUserNicknamed:senderNickname andConnection:connection];
			}

			[UIView setAnimationsEnabled:animationEnabled];
		}
	}
}

#pragma mark -

- (void) reloadSplitViewController {
	[_connectionsPopoverController dismissPopoverAnimated:YES];
	_connectionsPopoverController = nil;

	[_colloquiesPopoverController dismissPopoverAnimated:YES];
	_colloquiesPopoverController = nil;
	_colloquiesBarButtonItem = nil;

	UISplitViewController *splitViewController = [[UISplitViewController alloc] init];

	_connectionsBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Connections", @"Connections button title") style:UIBarButtonItemStyleBordered target:self action:@selector(toggleConnections:)];

	CQChatPresentationController *presentationController = [CQChatController defaultController].chatPresentationController;
	[presentationController setStandardToolbarItems:@[_connectionsBarButtonItem] animated:NO];

	splitViewController.viewControllers = @[[CQChatController defaultController].chatNavigationController, presentationController];
	splitViewController.delegate = self;

	_mainViewController = splitViewController;
	_mainWindow.rootViewController = _mainViewController;
}

- (BOOL) application:(UIApplication *) application didFinishLaunchingWithOptions:(NSDictionary *) launchOptions {
	NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]];
	[[CQSettingsController settingsController] registerDefaults:defaults];

	_deviceToken = [[CQSettingsController settingsController] stringForKey:@"CQPushDeviceToken"];

	[CQConnectionsController defaultController];
	[CQChatController defaultController];

	_mainWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	if ([_mainWindow respondsToSelector:@selector(setTintColor:)])
		_mainWindow.tintColor = [UIColor colorWithRed:0.427 green:0.086 blue:0.396 alpha:1];

	[self userDefaultsChanged];

	if ([[UIDevice currentDevice] isPadModel]) {
		[self reloadSplitViewController];
	} else {
		UITabBarController *tabBarController = [[UITabBarController alloc] initWithNibName:nil bundle:nil];
		tabBarController.delegate = self;

		NSArray *viewControllers = @[[CQConnectionsController defaultController].connectionsNavigationController, [CQChatController defaultController].chatNavigationController];
		tabBarController.viewControllers = viewControllers;

		_mainViewController = tabBarController;
		_mainWindow.rootViewController = _mainViewController;

		tabBarController.selectedIndex = [[CQSettingsController settingsController] integerForKey:@"CQSelectedTabIndex"];
	}

	[_mainWindow makeKeyAndVisible];

	[self handleNotificationWithUserInfo:launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]];

	[self performSelector:@selector(performDeferredLaunchWork) withObject:nil afterDelay:1.];

	return YES;
}

- (void) applicationWillEnterForeground:(UIApplication *) application {
	[self cancelAllLocalNotifications];
}

- (void) applicationWillResignActive:(UIApplication *) application {
	_oldSwipeOrientationValue = [[CQSettingsController settingsController] objectForKey:@"CQSplitSwipeOrientations"];
}

- (void) application:(UIApplication *) application didReceiveLocalNotification:(UILocalNotification *) notification {
	[self handleNotificationWithUserInfo:notification.userInfo];
}

- (void) application:(UIApplication *) application didReceiveRemoteNotification:(NSDictionary *) userInfo {
	NSDictionary *apsInfo = userInfo[@"aps"];
	if (!apsInfo.count)
		return;

	if ([self areNotificationBadgesAllowed])
		self.applicationIconBadgeNumber = [apsInfo[@"badge"] integerValue];
}

- (void) application:(UIApplication *) application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *) deviceToken {
	if (!deviceToken.length) {
		[[CQAnalyticsController defaultController] setObject:nil forKey:@"device-push-token"];
		[[CQSettingsController settingsController] removeObjectForKey:@"CQPushDeviceToken"];

		_deviceToken = nil;
		return;
	}

	const unsigned *tokenData = deviceToken.bytes;
	NSString *deviceTokenString = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x", ntohl(tokenData[0]), ntohl(tokenData[1]), ntohl(tokenData[2]), ntohl(tokenData[3]), ntohl(tokenData[4]), ntohl(tokenData[5]), ntohl(tokenData[6]), ntohl(tokenData[7])];

	if ([_deviceToken isEqualToString:deviceTokenString] || !deviceTokenString)
		return;

	[[CQAnalyticsController defaultController] setObject:deviceTokenString forKey:@"device-push-token"];
	[[CQSettingsController settingsController] setObject:deviceTokenString forKey:@"CQPushDeviceToken"];

	_deviceToken = deviceTokenString;

	[[NSNotificationCenter defaultCenter] postNotificationName:CQColloquyApplicationDidRecieveDeviceTokenNotification object:self userInfo:@{@"deviceToken": deviceTokenString}];
}

- (void) application:(UIApplication *) application didFailToRegisterForRemoteNotificationsWithError:(NSError *) error {
	NSLog(@"Error during remote notification registration. Error: %@", error);
}

- (BOOL) application:(UIApplication *) application handleOpenURL:(NSURL *) url {
	if ([url.scheme isCaseInsensitiveEqualToString:@"colloquy"]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"CQPocketShouldConvertTokenFromTokenNotification" object:nil];

		return YES;
	}

	return [[CQConnectionsController defaultController] handleOpenURL:url];
}

- (void) applicationWillTerminate:(UIApplication *) application {
	[UIApplication sharedApplication].applicationIconBadgeNumber = 0;

	[self submitRunTime];
}

#pragma mark -

- (void)splitViewController:(UISplitViewController *) splitViewController popoverController:(UIPopoverController *) popoverController willPresentViewController:(UIViewController *) viewController {
	if (![viewController isKindOfClass:[CQChatNavigationController class]])
		return;

	CQChatNavigationController *navigationController = (CQChatNavigationController *)viewController;
	((CQChatListViewController *)(navigationController.topViewController)).active = YES;
}

- (void) splitViewController:(UISplitViewController *) splitViewController willHideViewController:(UIViewController *) viewController withBarButtonItem:(UIBarButtonItem *) barButtonItem forPopoverController:(UIPopoverController *) popoverController {
	CQChatPresentationController *chatPresentationController = [CQChatController defaultController].chatPresentationController;
	NSMutableArray *items = [chatPresentationController.standardToolbarItems mutableCopy];

	if (items[0] == barButtonItem) {

		return;
	}

	if (viewController == [CQChatController defaultController].chatNavigationController) {
		_colloquiesPopoverController = popoverController;
		_colloquiesBarButtonItem = barButtonItem;

		[barButtonItem setAction:@selector(toggleColloquies:)];
		[barButtonItem setTarget:self];
	}

	[items insertObject:barButtonItem atIndex:0];

	[chatPresentationController setStandardToolbarItems:items animated:NO];
}

- (void) splitViewController:(UISplitViewController *) splitViewController willShowViewController:(UIViewController *) viewController invalidatingBarButtonItem:(UIBarButtonItem *) barButtonItem {
	CQChatPresentationController *chatPresentationController = [CQChatController defaultController].chatPresentationController;
	NSMutableArray *items = [chatPresentationController.standardToolbarItems mutableCopy];

	if (viewController == [CQChatController defaultController].chatNavigationController) {
		_colloquiesPopoverController = nil;

		NSAssert(_colloquiesBarButtonItem == barButtonItem, @"Bar button item was not the known Colloquies bar button item.");
		_colloquiesBarButtonItem = nil;
	}

	[items removeObjectIdenticalTo:barButtonItem];

	[chatPresentationController setStandardToolbarItems:items animated:NO];
}

- (BOOL) splitViewController:(UISplitViewController *) splitViewController shouldHideViewController:(UIViewController *) viewController inOrientation:(UIInterfaceOrientation) interfaceOrientation {
	NSUInteger allowedOrientation = [[CQSettingsController settingsController] integerForKey:@"CQSplitSwipeOrientations"];
	if (allowedOrientation == CQSidebarOrientationNone)
		return NO;

	if (allowedOrientation == CQSidebarOrientationAll)
		return YES;

	if (UIInterfaceOrientationIsLandscape(interfaceOrientation) && (allowedOrientation == CQSidebarOrientationLandscape))
		return YES;

	if (UIInterfaceOrientationIsPortrait(interfaceOrientation) && (allowedOrientation == CQSidebarOrientationPortrait))
		return YES;

	return NO;
}

#pragma mark -

- (void) showActionSheet:(UIActionSheet *) sheet {
	[self showActionSheet:sheet forSender:nil animated:YES];
}

- (void) showActionSheet:(UIActionSheet *) sheet fromPoint:(CGPoint) point {
	[self showActionSheet:sheet forSender:nil orFromPoint:point animated:YES];
}

- (void) showActionSheet:(UIActionSheet *) sheet forSender:(id) sender animated:(BOOL) animated {
	[self showActionSheet:sheet forSender:sender orFromPoint:CGPointZero animated:animated];
}

- (void) showActionSheet:(UIActionSheet *) sheet forSender:(id) sender orFromPoint:(CGPoint) point animated:(BOOL) animated {
	if (sender && [[UIDevice currentDevice] isPadModel]) {
		id old = _visibleActionSheet;
		[old dismissWithClickedButtonIndex:[old cancelButtonIndex] animated:NO];
		_visibleActionSheet = nil;

		if ([sender isKindOfClass:[UIBarButtonItem class]]) {
			[sheet showFromBarButtonItem:sender animated:animated];
			_visibleActionSheet = sheet;
		} else if ([sender isKindOfClass:[UIView class]]) {
			UIView *view = sender;
			[sheet showFromRect:view.bounds inView:view animated:animated];
			_visibleActionSheet = sheet;
		}

		return;
	}

	UITabBar *tabBar = self.tabBarController.tabBar;
	if (tabBar && !self.modalViewController) {
		[sheet showFromTabBar:tabBar];
		return;
	}

	if ([sender isKindOfClass:[UIView class]]) {
		[sheet showInView:sender];
		return;
	}

	if (!CGPointEqualToPoint(point, CGPointZero)) {
		[sheet showFromRect:(CGRect){ point, { 1., 1. } } inView:_mainViewController.view animated:animated];
		return;
	}

	[sheet showInView:_mainViewController.view];
}

#pragma mark -

- (UIViewController *) modalViewController {
	return _mainViewController.presentedViewController;
}

- (void) presentModalViewController:(UIViewController *) modalViewController {
	[self presentModalViewController:modalViewController animated:YES singly:YES];
}

- (void) presentModalViewController:(UIViewController *) modalViewController animated:(BOOL) animated {
	[self presentModalViewController:modalViewController animated:animated singly:YES];
}

- (void) _presentModalViewControllerWithInfo:(NSDictionary *) info {
	UIViewController *modalViewController = info[@"modalViewController"];
	BOOL animated = [info[@"animated"] boolValue];

	[self presentModalViewController:modalViewController animated:animated singly:YES];
}

- (void) presentModalViewController:(UIViewController *) modalViewController animated:(BOOL) animated singly:(BOOL) singly {
	if (singly && self.modalViewController) {
		[self dismissModalViewControllerAnimated:animated];
		if (animated) {
			[self performSelector:@selector(_presentModalViewControllerWithInfo:) withObject:@{
				@"modalViewController": modalViewController,
				@"animated": @(animated)
			} afterDelay:0.5];
			return;
		}
	}

	[_mainViewController presentViewController:modalViewController animated:animated completion:NULL];
}

- (void) dismissModalViewControllerAnimated:(BOOL) animated {
	[_mainViewController dismissViewControllerAnimated:animated completion:NULL];

	if (_userDefaultsChanged) {
		_userDefaultsChanged = NO;

		[self reloadSplitViewController];
	}
}

#pragma mark -

- (void) setNetworkActivityIndicatorVisible:(BOOL) visible {
	if (visible) {
		++_networkIndicatorStack;
		super.networkActivityIndicatorVisible = YES;
	} else {
		if (_networkIndicatorStack)
			--_networkIndicatorStack;
		if (!_networkIndicatorStack)
			super.networkActivityIndicatorVisible = NO;
	}
}

#pragma mark -

- (void) showHelp:(id) sender {
	CQWelcomeController *welcomeController = [[CQWelcomeController alloc] init];
	welcomeController.shouldShowOnlyHelpTopics = YES;

	[self presentModalViewController:welcomeController animated:YES];
}

- (void) showWelcome:(id) sender {
	CQWelcomeController *welcomeController = [[CQWelcomeController alloc] init];

	[self presentModalViewController:welcomeController animated:YES];
}

- (void) toggleConnections:(id) sender {
	if (_connectionsPopoverController.popoverVisible)
		[_connectionsPopoverController dismissPopoverAnimated:YES];
	else [self showConnections:sender];
}

- (void) showConnections:(id) sender {
	if ([[UIDevice currentDevice] isPadModel]) {
		if (!_connectionsPopoverController)
			_connectionsPopoverController = [[UIPopoverController alloc] initWithContentViewController:[CQConnectionsController defaultController].connectionsNavigationController];

		if (!_connectionsPopoverController.popoverVisible) {
			[self dismissPopoversAnimated:NO];
			[_connectionsPopoverController presentPopoverFromBarButtonItem:_connectionsBarButtonItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
		}
	} else {
		[[CQConnectionsController defaultController].connectionsNavigationController popToRootViewControllerAnimated:NO];
		self.tabBarController.selectedViewController = [CQConnectionsController defaultController].connectionsNavigationController;
	}
}

- (void) toggleColloquies:(id) sender {
	if (_colloquiesPopoverController.popoverVisible)
		[_colloquiesPopoverController dismissPopoverAnimated:YES];
	else [self showColloquies:sender];
}

- (void) showColloquies:(id) sender {
	[self showColloquies:sender hidingTopViewController:YES];
}

- (void) showColloquies:(id) sender hidingTopViewController:(BOOL) hidingTopViewController {
	if ([[UIDevice currentDevice] isPadModel]) {
		if (!_colloquiesPopoverController.popoverVisible) {
			[self dismissPopoversAnimated:NO];
			[_colloquiesPopoverController presentPopoverFromBarButtonItem:_colloquiesBarButtonItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
		}
	} else {
		self.tabBarController.selectedViewController = [CQChatController defaultController].chatNavigationController;
		if (hidingTopViewController)
			[[CQChatController defaultController].chatNavigationController popToRootViewControllerAnimated:YES];
	}
}

- (void) dismissPopoversAnimated:(BOOL) animated {
	[_colloquiesPopoverController dismissPopoverAnimated:animated];
	[_connectionsPopoverController dismissPopoverAnimated:animated];

	id <CQChatViewController> controller = [CQChatController defaultController].visibleChatController;
	if ([controller respondsToSelector:@selector(dismissPopoversAnimated:)])
		[controller dismissPopoversAnimated:animated];
}

- (void) submitRunTime {
	NSTimeInterval runTime = ABS([_resumeDate timeIntervalSinceNow]);
	[[CQAnalyticsController defaultController] setObject:@(runTime) forKey:@"run-time"];
	[[CQAnalyticsController defaultController] synchronizeSynchronously];
}

#pragma mark -

- (BOOL) isSpecialApplicationURL:(NSURL *) url {
#if !TARGET_IPHONE_SIMULATOR
	return (url && ([url.host hasCaseInsensitiveSubstring:@"phobos.apple."]));
#else
	return NO;
#endif
}

- (NSString *) applicationNameForURL:(NSURL *) url {
	if (!url)
		return nil;
	NSString *scheme = url.scheme;
#if !TARGET_IPHONE_SIMULATOR
	NSString *host = url.host;
	if ([host hasCaseInsensitiveSubstring:@"phobos.apple."])
		return NSLocalizedString(@"iTunes", @"iTunes application name");
	if ([scheme isCaseInsensitiveEqualToString:@"mailto"])
		return NSLocalizedString(@"Mail", @"Mail application name");
#endif
	if ([scheme isCaseInsensitiveEqualToString:@"http"] || [scheme isCaseInsensitiveEqualToString:@"https"])
		return NSLocalizedString(@"Safari", @"Safari application name");
	return nil;
}

- (BOOL) openURL:(NSURL *) url {
	return [self openURL:url promptForExternal:YES];
}

- (BOOL) openURL:(NSURL *) url promptForExternal:(BOOL) prompt {
	if ([[CQConnectionsController defaultController] handleOpenURL:url])
		return YES;

	if (url && ![self canOpenURL:url])
		return NO;

	if ([self isSpecialApplicationURL:url]) {
		if (!prompt)
			return [super openURL:url];

		CQAlertView *alert = [[CQAlertView alloc] init];

		alert.tag = BrowserAlertTag;

		NSString *applicationName = [self applicationNameForURL:url];
		if (applicationName)
			alert.title = [NSString stringWithFormat:NSLocalizedString(@"Open Link in %@?", @"Open link in app alert title"), applicationName];
		else alert.title = NSLocalizedString(@"Open Link?", @"Open link alert title");

		alert.message = NSLocalizedString(@"Opening this link will close Colloquy.", @"Opening link alert message");
		alert.delegate = self;

		alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title")];

		[alert associateObject:url forKey:@"userInfo"];
		[alert addButtonWithTitle:NSLocalizedString(@"Open", @"Open button title")];

		[alert show];
	} else [super openURL:url];

	return YES;
}

#pragma mark -

- (void) alertView:(UIAlertView *) alertView clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (alertView.tag != BrowserAlertTag || alertView.cancelButtonIndex == buttonIndex)
		return;
	[super openURL:[alertView associatedObjectForKey:@"userInfo"]];
}

#pragma mark -

- (void) tabBarController:(UITabBarController *) tabBarController didSelectViewController:(UIViewController *) viewController {
	[[CQSettingsController settingsController] setInteger:tabBarController.selectedIndex forKey:@"CQSelectedTabIndex"];
}

#pragma mark -

- (UIColor *) tintColor {
	if ([[UIDevice currentDevice] isPadModel])
		return nil;

	NSString *style = [[CQSettingsController settingsController] stringForKey:@"CQChatTranscriptStyle"];
	if ([style hasSuffix:@"-dark"])
		return [UIColor blackColor];
	if ([style isEqualToString:@"notes"])
		return [UIColor colorWithRed:0.224 green:0.082 blue:0. alpha:1.];
	return nil;
}

#pragma mark -

- (BOOL) areNotificationBadgesAllowed {
	return (!_deviceToken || [self enabledRemoteNotificationTypes] & UIRemoteNotificationTypeBadge);
}

- (BOOL) areNotificationSoundsAllowed {
	return (!_deviceToken || [self enabledRemoteNotificationTypes] & UIRemoteNotificationTypeSound);
}

- (BOOL) areNotificationAlertsAllowed {
	return (!_deviceToken || [self enabledRemoteNotificationTypes] & UIRemoteNotificationTypeAlert);
}

- (void) presentLocalNotificationNow:(UILocalNotification *) notification {
	if (![self areNotificationAlertsAllowed])
		notification.alertBody = nil;
	if (![self areNotificationSoundsAllowed])
		notification.soundName = nil;
	if (![self areNotificationBadgesAllowed])
		notification.applicationIconBadgeNumber = 0;
	[super presentLocalNotificationNow:notification];
}

- (void) registerForRemoteNotifications {
#if !TARGET_IPHONE_SIMULATOR
	static BOOL registeredForPush;
	if (!registeredForPush) {
		[self registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
		registeredForPush = YES;
	}
#endif
}
@end
