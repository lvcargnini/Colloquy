#import "CQTextCompletionView.h"
#import "MVChatString.h"

@protocol CQChatInputBarDelegate;
@class CQTextCompletionView;

typedef NS_ENUM(NSInteger, CQChatInputBarResponderState) {
	CQChatInputBarNotResponder,
	CQChatInputBarResponder
};

@interface CQChatInputBar : UIView <UITextViewDelegate, CQTextCompletionViewDelegate> {
	@protected
	UIView *_backgroundView;
	UITextView *_inputView;
	CQTextCompletionView *_completionView;
	NSArray *_completions;
	NSRange _completionRange;
	BOOL _completionCapturedKeyboard;
	BOOL _disableCompletionUntilNextWord;
	BOOL _autocomplete;
	BOOL _spaceCyclesCompletions;
	BOOL _autocorrect;
	BOOL _autocapitalizeNextLetter;
	BOOL _textNeedsClearing;
	UITextAutocapitalizationType _defaultAutocapitalizationType;
	UIViewAnimationCurve _animationCurve;
	NSTimeInterval _animationDuration;
	UIButton *_accessoryButton;
	UIImageView *_overlayBackgroundView;
	UIImageView *_overlayBackgroundViewPiece;
	UIView *_topLineView;
	NSMutableDictionary *_accessoryImages;
	CQChatInputBarResponderState _responderState;
}
@property (nonatomic, weak) IBOutlet id <CQChatInputBarDelegate> delegate;

@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, strong) UIFont *font;

@property (nonatomic) BOOL autocomplete;
@property (nonatomic) BOOL spaceCyclesCompletions;
@property (nonatomic) BOOL autocorrect;

@property (nonatomic, readonly) UITextView *textView;
@property (nonatomic, readonly) NSRange caretRange;
@property (nonatomic) UITextAutocapitalizationType autocapitalizationType;

@property (nonatomic, readonly, getter=isShowingCompletions) BOOL showingCompletions;

- (void) showCompletionsForText:(NSString *) text inRange:(NSRange) range;
- (void) hideCompletions;

- (void) updateTextViewContentSize;

- (void) setAccessoryImage:(UIImage *) image forResponderState:(CQChatInputBarResponderState) responderState controlState:(UIControlState) controlState;
- (UIImage *) accessoryImageForResponderState:(CQChatInputBarResponderState) responderState controlState:(UIControlState) controlState;
@end

@protocol CQChatInputBarDelegate <NSObject>
@optional
- (void) chatInputBarTextDidChange:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBarShouldBeginEditing:(CQChatInputBar *) chatInputBar;
- (void) chatInputBarDidBeginEditing:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBarShouldEndEditing:(CQChatInputBar *) chatInputBar;
- (void) chatInputBarDidEndEditing:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBarShouldIndent:(CQChatInputBar *) chatInputBar;
- (void) chatInputBarDidChangeSelection:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar sendText:(MVChatString *) text;
- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar shouldAutocorrectWordWithPrefix:(NSString *) word;
- (NSArray *) chatInputBar:(CQChatInputBar *) chatInputBar completionsForWordWithPrefix:(NSString *) word inRange:(NSRange) range;
- (void) chatInputBarAccessoryButtonPressed:(CQChatInputBar *) chatInputBar;
- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar shouldChangeHeightBy:(CGFloat) difference;
@end
