#import "CQChatController.h"
#import "CQChatInputBar.h"
#import "CQChatTranscriptViewDelegate.h"
#import "CQImportantChatMessageViewController.h"

#import "MVChatString.h"

#define ReconnectAlertTag 1
#define RejoinRoomAlertTag 2

#define ToolbarTitleButtonTag 1
#define ToolbarLastButtonTag 2

@class CQChatTableCell;
@class CQChatInputBar;
@class CQChatInputStyleViewController;
@class CQUIChatTranscriptView;
@class CQWKChatTranscriptView;
@class MVChatUser;
@class MVChatUserWatchRule;

extern NSString *CQChatViewControllerHandledMessageNotification;
extern NSString *CQChatViewControllerRecentMessagesUpdatedNotification;
extern NSString *CQChatViewControllerUnreadMessagesUpdatedNotification;

typedef NS_ENUM(NSInteger, CQDirectChatBatchType) {
	CQBatchTypeUnknown = -1,
	CQBatchTypeBuffer = 0
};


@interface CQDirectChatController : UIViewController <CQChatViewController, CQChatInputBarDelegate, CQChatTranscriptViewDelegate, CQImportantChatMessageDelegate, UIAlertViewDelegate, UIActionSheetDelegate> {
	@protected
	IBOutlet CQChatInputBar *chatInputBar;
	IBOutlet UIView <CQChatTranscriptView> *transcriptView;
	IBOutlet UIView *containerView;

	CQChatInputStyleViewController *_styleViewController;

	BOOL _coalescePendingUpdates;
	NSMutableArray *_pendingPreviousSessionComponents;
	NSMutableArray *_pendingComponents;
	NSMutableArray *_recentMessages;
	NSMutableArray *_sentMessages;

	id _target;
	NSStringEncoding _encoding;
	MVChatUserWatchRule *_watchRule;

	NSUInteger _unreadMessages;
	NSUInteger _unreadHighlightedMessages;
	BOOL _active;
	BOOL _showingAlert;
	BOOL _allowEditingToEnd;
	BOOL _didSendRecently;
	BOOL _revealKeyboard;
	BOOL _showingKeyboard;
	BOOL _showDeviceTokenWhenRegistered;

	NSTimeInterval _lastTimestampTime;
	NSTimeInterval _lastMessageTime;

	NSMutableDictionary *_batchStorage; // { "batchIdentifier": any associated data }
	NSMutableDictionary *_batchTypeAssociation; // { @(batchType): [ "batchIdentifier", "otherBatchIdentifier" ] }
}
- (instancetype) initWithNibName:(NSString *) nibNameOrNil bundle:(NSBundle *) nibBundleOrNil NS_UNAVAILABLE;
- (instancetype) initWithStyle:(UITableViewStyle) style NS_UNAVAILABLE;
- (instancetype) initWithCoder:(NSCoder *) aDecoder NS_UNAVAILABLE;

- (instancetype) initWithTarget:(id) target NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) MVChatUser *user;

@property (nonatomic, readonly) NSArray *recentMessages;

@property (nonatomic, copy) NSDate *mostRecentIncomingMessageTimestamp;
@property (nonatomic, copy) NSDate *mostRecentOutgoingMessageTimestamp;

- (void) clearController;

- (void) markScrollback;

- (void) showRecentlySentMessages;

- (void) sendMessage:(MVChatString *) message asAction:(BOOL) action;

- (void) addMessage:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier;
- (void) addMessage:(NSDictionary *) message;

- (void) addEventMessage:(NSString *) message withIdentifier:(NSString *) identifier;
- (void) addEventMessage:(NSString *) message withIdentifier:(NSString *) identifier announceWithVoiceOver:(BOOL) announce;

- (void) addEventMessageAsHTML:(NSString *) message withIdentifier:(NSString *) identifier;
- (void) addEventMessageAsHTML:(NSString *) message withIdentifier:(NSString *) identifier announceWithVoiceOver:(BOOL) announce;

- (BOOL) canAnnounceWithVoiceOverAndMessageIsImportant:(BOOL) important;
@end
