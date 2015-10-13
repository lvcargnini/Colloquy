@protocol CQBrowserViewControllerDelegate;

NS_ASSUME_NONNULL_BEGIN

extern NSString *CQColloquyApplicationDidRecieveDeviceTokenNotification;

typedef NS_OPTIONS(NSInteger, CQAppIconOptions) {
	CQAppIconOptionNone = 0,
	CQAppIconOptionConnect = 1 << 0,
	CQAppIconOptionDisconnect = 1 << 1,
	CQAppIconOptionMarkAllAsRead = 1 << 2
};

@interface CQColloquyApplication : UIApplication
+ (CQColloquyApplication *) sharedApplication;

- (void) showHelp:(__nullable id) sender;
- (void) showWelcome:(__nullable id) sender;
- (void) showConnections:(__nullable id) sender;

- (void) dismissPopoversAnimated:(BOOL) animated;

- (BOOL) isSpecialApplicationURL:(NSURL *) url;
- (NSString *) applicationNameForURL:(NSURL *) url;

- (void) showActionSheet:(UIActionSheet *) sheet;
- (void) showActionSheet:(UIActionSheet *) sheet fromPoint:(CGPoint) point;
- (void) showActionSheet:(UIActionSheet *) sheet forSender:(__nullable id) sender animated:(BOOL) animated;

@property (nonatomic, readonly) UIViewController *mainViewController;
@property (nonatomic, readonly) UIViewController *modalViewController;

- (void) presentModalViewController:(UIViewController *) modalViewController animated:(BOOL) animated;
- (void) presentModalViewController:(UIViewController *) modalViewController animated:(BOOL) animated singly:(BOOL) singly;
- (void) dismissModalViewControllerAnimated:(BOOL) animated;

@property (readonly) BOOL areNotificationBadgesAllowed;
@property (readonly) BOOL areNotificationSoundsAllowed;
@property (readonly) BOOL areNotificationAlertsAllowed;

- (void) registerForPushNotifications;

@property (nonatomic, readonly) NSDate *launchDate;
@property (nonatomic, strong) NSDate *resumeDate;

- (void) updateAppShortcuts;
@property (nonatomic) CQAppIconOptions appIconOptions;

- (void) submitRunTime;

@property (nonatomic, readonly) NSSet *handledURLSchemes;
@property (nonatomic, readonly) NSString *deviceToken;
@property (nonatomic, readonly) NSArray *highlightWords;
@property (nonatomic, readonly) UIColor *tintColor;

@property (readonly, strong) UISplitViewController *splitViewController;
@end

NS_ASSUME_NONNULL_END
