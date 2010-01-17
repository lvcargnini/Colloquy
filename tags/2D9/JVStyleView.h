@class JVMarkedScroller;
@class JVChatTranscript;
@class JVChatMessage;
@class JVStyle;
@class JVEmoticonSet;

@protocol JVChatTranscriptElement;

extern NSString *JVStyleViewDidChangeStylesNotification;

@interface JVStyleView : WebView {
	IBOutlet NSTextView *nextTextView;
	BOOL _forwarding;
	BOOL _switchingStyles;
	BOOL _ready;
	BOOL _webViewReady;
	JVChatTranscript *_transcript;
	JVStyle *_style;
	NSString *_styleVariant;
	NSDictionary *_styleParameters;
	JVEmoticonSet *_emoticons;
	unsigned int _scrollbackLimit;
	BOOL _requiresFullMessage;
}
- (void) setTranscript:(JVChatTranscript *) transcript;
- (JVChatTranscript *) transcript;

- (void) setStyle:(JVStyle *) style;
- (void) setStyle:(JVStyle *) style withVariant:(NSString *) variant;
- (JVStyle *) style;

- (void) setStyleVariant:(NSString *) variant;
- (NSString *) styleVariant;

- (void) setStyleParameters:(NSDictionary *) parameters;
- (NSDictionary *) styleParameters;

- (void) setEmoticons:(JVEmoticonSet *) emoticons;
- (JVEmoticonSet *) emoticons;

- (void) setScrollbackLimit:(unsigned int) limit;
- (unsigned int) scrollbackLimit;

- (void) reloadCurrentStyle;
- (void) clear;

- (void) showTopic:(NSString *) topic;
- (void) hideTopic;
- (void) toggleTopic:(NSString *) topic;

- (BOOL) appendChatMessage:(JVChatMessage *) message;
- (BOOL) appendChatTranscriptElement:(id <JVChatTranscriptElement>) element;

- (void) markScrollbarForMessage:(JVChatMessage *) message;
- (void) markScrollbarForMessages:(NSArray *) messages;
- (void) clearScrollbarMarks;

- (JVMarkedScroller *) verticalMarkedScroller;
- (IBAction) jumpToPreviousHighlight:(id) sender;
- (IBAction) jumpToNextHighlight:(id) sender;
- (void) jumpToMessage:(JVChatMessage *) message;
- (void) scrollToBottom;

- (NSTextView *) nextTextView;
- (void) setNextTextView:(NSTextView *) textView;
@end