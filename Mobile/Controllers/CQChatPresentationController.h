@protocol CQChatViewController;

NS_ASSUME_NONNULL_BEGIN

@interface CQChatPresentationController : UIViewController {
	UIToolbar *_toolbar;
	NSArray *_standardToolbarItems;
	UIViewController <CQChatViewController> *_topChatViewController;
}
@property (nonatomic, copy) NSArray *standardToolbarItems;
- (void) setStandardToolbarItems:(NSArray *) items animated:(BOOL) animated;

@property (nonatomic, strong) id <CQChatViewController> topChatViewController;

- (void) updateToolbarAnimated:(BOOL) animated;
- (void) updateToolbarForInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation animated:(BOOL) animated;
@end

NS_ASSUME_NONNULL_END
