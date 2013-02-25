#import "CQChatTranscriptView.h"

#import <ChatCore/MVChatUser.h>

#define DefaultFontSize 14

#if ENABLE(SECRETS)
@interface UIScroller : UIView
@property (nonatomic) BOOL showBackgroundShadow;
@property (nonatomic) CGPoint offset;
- (void) displayScrollerIndicators;
@end

#pragma mark -

@interface UIScrollView (Private)
@property (nonatomic) BOOL showBackgroundShadow;
@end

#pragma mark -

@interface UIWebView (UIWebViewPrivate)
- (void) scrollerWillStartDragging:(UIScroller *) scroller;
- (void) scrollerDidEndDragging:(UIScroller *) scroller willSmoothScroll:(BOOL) smooth;
- (void) scrollerDidEndSmoothScrolling:(UIScroller *) scroller;
- (UIScroller *) _scroller;
@end
#endif

#pragma mark -

@interface CQChatTranscriptView (Internal)
- (void) _addComponentsToTranscript:(NSArray *) components fromPreviousSession:(BOOL) previous animated:(BOOL) animated;
- (NSString *) _contentHTML;
- (void) _commonInitialization;
- (UIScrollView *) scrollView;
@end

#pragma mark -

@implementation CQChatTranscriptView
- (id) initWithFrame:(CGRect) frame {
	if (!(self = [super initWithFrame:frame]))
		return nil;

	[self _commonInitialization];

	return self;
}

- (id) initWithCoder:(NSCoder *) coder {
	if (!(self = [super initWithCoder:coder]))
		return nil;

	[self _commonInitialization];

	return self;
}

- (void) dealloc {
	super.delegate = nil;

	[_blockerView release];
	[_fontFamily release];
	[_styleIdentifier release];
	[_pendingComponents release];
	[_pendingPreviousSessionComponents release];

	[super dealloc];
}

#pragma mark -

@synthesize transcriptDelegate;

- (void) setDelegate:(id <UIWebViewDelegate>) delegate {
	NSAssert(NO, @"Should not be called. Use transcriptDelegate instead.");
}

@synthesize allowsStyleChanges = _allowsStyleChanges;
@synthesize styleIdentifier = _styleIdentifier;

- (void) setStyleIdentifier:(NSString *) styleIdentifier {
	NSParameterAssert(styleIdentifier);
	NSParameterAssert(styleIdentifier.length);

	if (!_allowsStyleChanges || [_styleIdentifier isEqualToString:styleIdentifier])
		return;

	id old = _styleIdentifier;
	_styleIdentifier = [styleIdentifier copy];
	[old release];

	if ([styleIdentifier hasSuffix:@"-dark"])
		self.backgroundColor = [UIColor blackColor];
	else if ([styleIdentifier isEqualToString:@"notes"])
		self.backgroundColor = [UIColor colorWithRed:(253. / 255.) green:(251. / 255.) blue:(138. / 255.) alpha:1.];
	else self.backgroundColor = [UIColor whiteColor];

	UIScrollView *scrollView = self.scrollView;
	if (scrollView)
		scrollView.indicatorStyle = [styleIdentifier hasSuffix:@"-dark"] ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleDefault;

	_blockerView.backgroundColor = self.backgroundColor;

	[self resetSoon];
}

@synthesize fontFamily = _fontFamily;

- (void) setFontFamily:(NSString *) fontFamily {
	// Since _fontFamily or fontFamily can be nil we also need to check pointer equality.
	if (!_allowsStyleChanges || _fontFamily == fontFamily || [_fontFamily isEqualToString:fontFamily])
		return;

	id old = _fontFamily;
	_fontFamily = [fontFamily copy];
	[old release];

	[self resetSoon];
}

@synthesize fontSize = _fontSize;

- (void) setFontSize:(NSUInteger) fontSize {
	if (_fontSize == fontSize)
		return;

	_fontSize = fontSize;

	[self resetSoon];
}

- (UIScrollView *) scrollView {
	if ([[UIDevice currentDevice] isSystemFive])
		return [super scrollView];

#if ENABLE(SECRETS)
	return [self performPrivateSelector:@"_scrollView"];
#endif

	return nil;
}

#pragma mark -

- (BOOL) canBecomeFirstResponder {
	return !_scrolling;
}

- (void) willStartScrolling {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(didFinishScrollingRecently) object:nil];

	[super stringByEvaluatingJavaScriptFromString:@"suspendAutoscroll()"];

	_scrolling = YES;
}

- (void) didFinishScrolling {
	CGPoint offset = CGPointZero;
	UIScrollView *scrollView = self.scrollView;
	if (scrollView) {
		offset = scrollView.contentOffset;
	} else {
		id scroller = [self performPrivateSelector:@"_scroller"];
		offset = [scroller performPrivateSelectorReturningPoint:@"offset"];
	}

	NSString *command = [NSString stringWithFormat:@"updateScrollPosition(%f)", offset.y];
	[super stringByEvaluatingJavaScriptFromString:command];

	[super stringByEvaluatingJavaScriptFromString:@"resumeAutoscroll()"];

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(didFinishScrollingRecently) object:nil];
	[self performSelector:@selector(didFinishScrollingRecently) withObject:nil afterDelay:0.5];
}

- (void) didFinishScrollingRecently {
	_scrolling = NO;
}

#pragma mark -

- (BOOL) gestureRecognizer:(UIGestureRecognizer *) gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *) otherGestureRecognizer {
	return YES;
}

#pragma mark -

#if ENABLE(SECRETS)
- (void) scrollerWillStartDragging:(UIScroller *) scroller {
	[super scrollerWillStartDragging:scroller];

	[self willStartScrolling];
}

- (void) scrollerDidEndDragging:(UIScroller *) scroller willSmoothScroll:(BOOL) smooth {
	[super scrollerDidEndDragging:scroller willSmoothScroll:smooth];

	if (!smooth) [self didFinishScrolling];
}

- (void) scrollerDidEndSmoothScrolling:(UIScroller *) scroller {
	[super scrollerDidEndSmoothScrolling:scroller];

	[self didFinishScrolling];
}
#endif

- (void) scrollViewWillBeginDragging:(UIScrollView *) scrollView {
	[super scrollViewWillBeginDragging:scrollView];

	[self willStartScrolling];
}

- (void) scrollViewDidEndDragging:(UIScrollView *) scrollView willDecelerate:(BOOL) decelerate {
	[super scrollViewDidEndDragging:scrollView willDecelerate:decelerate];

	if (!decelerate) [self didFinishScrolling];
}

- (void) scrollViewDidEndDecelerating:(UIScrollView *) scrollView {
	[super scrollViewDidEndDecelerating:scrollView];

	[self didFinishScrolling];
}

#pragma mark -

- (void) longPressGestureRecognizerRecognized:(UILongPressGestureRecognizer *) longPressGestureRecognizer {
	CGPoint point = [longPressGestureRecognizer locationInView:self];
	NSString *tappedURL = [super stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"urlUnderTapAtPoint(%d, %d)", (int)point.x, (int)point.y]];

	if (transcriptDelegate && [transcriptDelegate respondsToSelector:@selector(transcriptView:handleLongPressURL:atLocation:)])
		[transcriptDelegate transcriptView:self handleLongPressURL:[NSURL URLWithString:tappedURL] atLocation:_lastTouchLocation];
}

- (void) swipeGestureRecognized:(UISwipeGestureRecognizer *) swipeGestureRecognizer {
	if (transcriptDelegate && [transcriptDelegate respondsToSelector:@selector(transcriptView:receivedSwipeWithTouchCount:leftward:)])
		[transcriptDelegate transcriptView:self receivedSwipeWithTouchCount:swipeGestureRecognizer.numberOfTouches leftward:(swipeGestureRecognizer.direction & UISwipeGestureRecognizerDirectionLeft)];
}

#pragma mark -

- (UIView *) hitTest:(CGPoint) point withEvent:(UIEvent *) event {
	_lastTouchLocation = [[UIApplication sharedApplication].keyWindow.rootViewController.view convertPoint:point fromView:self];

	return [super hitTest:point withEvent:event];;
}

#pragma mark -

- (BOOL) webView:(UIWebView *) webView shouldStartLoadWithRequest:(NSURLRequest *) request navigationType:(UIWebViewNavigationType) navigationType {
	if (navigationType == UIWebViewNavigationTypeOther)
		return YES;

	if (navigationType != UIWebViewNavigationTypeLinkClicked)
		return NO;

	if ([request.URL.scheme isCaseInsensitiveEqualToString:@"colloquy"]) {
		if ([transcriptDelegate respondsToSelector:@selector(transcriptView:handleNicknameTap:atLocation:)]) {
			NSRange endOfSchemeRange = [request.URL.absoluteString rangeOfString:@"://"];
			if (endOfSchemeRange.location == NSNotFound)
				return NO;

			NSString *nickname = [[request.URL.absoluteString substringFromIndex:(endOfSchemeRange.location + endOfSchemeRange.length)] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			[transcriptDelegate transcriptView:self handleNicknameTap:nickname atLocation:_lastTouchLocation];
		}

		return NO;
	}

	if ([transcriptDelegate respondsToSelector:@selector(transcriptView:handleOpenURL:)])
		if ([transcriptDelegate transcriptView:self handleOpenURL:request.URL])
			return NO;

	[[UIApplication sharedApplication] openURL:request.URL];

	return NO;
}

- (void) webViewDidFinishLoad:(UIWebView *) webView {
	[self performSelector:@selector(_checkIfLoadingFinished) withObject:nil afterDelay:0.];

	[super stringByEvaluatingJavaScriptFromString:@"document.body.style.webkitTouchCallout='none';"];
}

#pragma mark -

- (void) addPreviousSessionComponents:(NSArray *) components {
	NSParameterAssert(components != nil);

	if (_loading || _resetPending) {
		if (_pendingPreviousSessionComponents) [_pendingPreviousSessionComponents addObjectsFromArray:components];
		else _pendingPreviousSessionComponents = [components mutableCopy];
		return;
	}

	[self _addComponentsToTranscript:components fromPreviousSession:YES animated:NO];
}

- (void) addComponents:(NSArray *) components animated:(BOOL) animated {
	NSParameterAssert(components != nil);

	if (_loading || _resetPending) {
		if (_pendingComponents) [_pendingComponents addObjectsFromArray:components];
		else _pendingComponents = [components mutableCopy];
		return;
	}

	[self _addComponentsToTranscript:components fromPreviousSession:NO animated:animated];
}

- (void) addComponent:(NSDictionary *) component animated:(BOOL) animated {
	NSParameterAssert(component != nil);

	if (_loading || _resetPending) {
		if (!_pendingComponents)
			_pendingComponents = [[NSMutableArray alloc] init];
		[_pendingComponents addObject:component];
		return;
	}

	[self _addComponentsToTranscript:[NSArray arrayWithObject:component] fromPreviousSession:NO animated:animated];
}

- (void) noteNicknameChangedFrom:(NSString *) oldNickname to:(NSString *) newNickname {
	[super stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"nicknameChanged(\"%@\", \"%@\")", oldNickname, newNickname]];
}

- (void) scrollToBottomAnimated:(BOOL) animated {
	[super stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"scrollToBottom(%@)", (animated ? @"true" : @"false")]];
}

- (void) flashScrollIndicators {
	UIScrollView *scrollView = self.scrollView;
	if (scrollView) {
		[scrollView flashScrollIndicators];
	} else {
		id scroller = [self performPrivateSelector:@"_scroller"];
		[scroller performPrivateSelector:@"displayScrollerIndicators"];
	}
}

- (void) markScrollback {
	[super stringByEvaluatingJavaScriptFromString:@"markScrollback()"];
}

- (void) resetSoon {
	if (_resetPending)
		return;

	_resetPending = YES;
	[self performSelector:@selector(reset) withObject:nil afterDelay:0];
}

- (void) reset {
	_resetPending = NO;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reset) object:nil];

	[self stopLoading];

	_blockerView.hidden = NO;

	_loading = YES;
	[self loadHTMLString:[self _contentHTML] baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];

	if ([transcriptDelegate respondsToSelector:@selector(transcriptViewWasReset:)])
		[transcriptDelegate transcriptViewWasReset:self];
}

#pragma mark -

- (NSString *) stringByEvaluatingJavaScriptFromString:(NSString *) script {
	NSLog(@"Refusing to evaluate %@\n%@", script, [NSThread callStackSymbols]);

	return nil;
}

#pragma mark -

- (void) _addComponentsToTranscript:(NSArray *) components fromPreviousSession:(BOOL) previousSession animated:(BOOL) animated {
	if (!components.count)
		return;

	NSMutableString *command = [[NSMutableString alloc] initWithString:@"appendComponents(["];
	NSCharacterSet *escapedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"\\'\""];

	for (NSDictionary *component in components) {
		NSString *type = [component objectForKey:@"type"];
		NSString *messageString = [component objectForKey:@"message"];
		if (!messageString)
			continue;

		NSString *escapedMessage = [messageString stringByEscapingCharactersInSet:escapedCharacters];
		BOOL isMessage = [type isEqualToString:@"message"];
		BOOL isNotice = [[component objectForKey:@"notice"] boolValue];

		if (isMessage || isNotice) {
			MVChatUser *user = [component objectForKey:@"user"];
			if (!user)
				continue;

			BOOL action = [[component objectForKey:@"action"] boolValue];
			BOOL highlighted = [[component objectForKey:@"highlighted"] boolValue];

			NSString *escapedNickname = [user.nickname stringByEscapingCharactersInSet:escapedCharacters];

			if (isNotice)
				[command appendFormat:@"{type:'notice',sender:'%@',message:'%@',highlighted:%@,action:%@,self:%@},", escapedNickname, escapedMessage, (highlighted ? @"true" : @"false"), (action ? @"true" : @"false"), (user.localUser ? @"true" : @"false")];
			else [command appendFormat:@"{type:'message',sender:'%@',message:'%@',highlighted:%@,action:%@,self:%@},", escapedNickname, escapedMessage, (highlighted ? @"true" : @"false"), (action ? @"true" : @"false"), (user.localUser ? @"true" : @"false")];
		} else if ([type isEqualToString:@"event"]) {
			NSString *identifier = [component objectForKey:@"identifier"];
			if (!identifier)
				continue;

			NSString *escapedIdentifer = [identifier stringByEscapingCharactersInSet:escapedCharacters];

			[command appendFormat:@"{type:'event',message:'%@',identifier:'%@'},", escapedMessage, escapedIdentifer];
		} else if ([type isEqualToString:@"console"]) {
			[command appendFormat:@"{type:'console',message:'%@',outbound:%@},", escapedMessage, ([[component objectForKey:@"outbound"] boolValue] ? @"true" : @"false")];
		}
	}

	[command appendFormat:@"],%@,false,%@)", (previousSession ? @"true" : @"false"), (animated ? @"false" : @"true")];

	[super stringByEvaluatingJavaScriptFromString:command];

	[command release];
}

- (void) _commonInitialization {
	super.delegate = self;

	UIScrollView *scrollView = self.scrollView;
	if (!scrollView)
		scrollView = [self performPrivateSelector:@"_scroller"];
	[scrollView performPrivateSelector:@"setShowBackgroundShadow:" withBoolean:NO];

	_allowsStyleChanges = YES;
	_blockerView = [[UIView alloc] initWithFrame:self.bounds];
	_blockerView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	[self addSubview:_blockerView];

	self.styleIdentifier = @"standard";

	[self resetSoon];

	for (NSUInteger i = 1; i <= 3; i++) {
		UISwipeGestureRecognizer *swipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeGestureRecognized:)];
		swipeGestureRecognizer.numberOfTouchesRequired = i;
		swipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionRight;

		[self addGestureRecognizer:swipeGestureRecognizer];

		[swipeGestureRecognizer release];

		swipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeGestureRecognized:)];
		swipeGestureRecognizer.numberOfTouchesRequired = i;
		swipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;

		[self addGestureRecognizer:swipeGestureRecognizer];

		[swipeGestureRecognizer release];
	}

	UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressGestureRecognizerRecognized:)];
	longPressGestureRecognizer.delegate = self;

	[self addGestureRecognizer:longPressGestureRecognizer];
	[longPressGestureRecognizer release];
}

- (NSString *) _variantStyleString {
	NSMutableString *styleString = [[NSMutableString alloc] init];

	if (_fontFamily.length)
		[styleString appendFormat:@"font-family: %@; ", _fontFamily];
	if (_fontSize && _fontSize != DefaultFontSize)
		[styleString appendFormat:@"font-size: %dpx; ", _fontSize];

	if (styleString.length) {
		[styleString insertString:@"body { " atIndex:0];
		[styleString appendString:@"}"];
	}

	return [styleString autorelease];
}

- (NSString *) _contentHTML {
	NSString *templateString = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"base" ofType:@"html"] encoding:NSUTF8StringEncoding error:NULL];
	return [NSString stringWithFormat:templateString, _styleIdentifier, [self _variantStyleString]];
}

- (void) _checkIfLoadingFinished {
	NSString *result = [super stringByEvaluatingJavaScriptFromString:@"isDocumentReady()"];
	if (![result isEqualToString:@"true"]) {
		[self performSelector:_cmd withObject:nil afterDelay:0.05];
		return;
	}

	_loading = NO;

	[self _addComponentsToTranscript:_pendingPreviousSessionComponents fromPreviousSession:YES animated:NO];

	[_pendingPreviousSessionComponents release];
	_pendingPreviousSessionComponents = nil;

	[self _addComponentsToTranscript:_pendingComponents fromPreviousSession:NO animated:NO];

	[_pendingComponents release];
	_pendingComponents = nil;

	[self performSelector:@selector(_unhideBlockerView) withObject:nil afterDelay:0.05];
}

- (void) _unhideBlockerView {
	_blockerView.hidden = YES;
}
@end
