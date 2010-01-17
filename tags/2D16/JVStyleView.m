#import "JVStyleView.h"
#import "JVMarkedScroller.h"
#import "JVChatTranscript.h"
#import "JVChatMessage.h"
#import "JVStyle.h"
#import "JVEmoticonSet.h"

#import <ChatCore/NSStringAdditions.h>
#import <ChatCore/NSNotificationAdditions.h>

NSString *JVStyleViewDidChangeStylesNotification = @"JVStyleViewDidChangeStylesNotification";

@interface WebCoreCache
+ (void) empty;
+ (id)statistics;
@end

#pragma mark -

@interface WebView (WebViewPrivate) // WebKit 1.3 pending public API
- (void) setDrawsBackground:(BOOL) draws;
- (BOOL) drawsBackground;
@end

#pragma mark -

@interface NSScrollView (NSScrollViewWebKitPrivate)
- (void) setAllowsHorizontalScrolling:(BOOL) allow;
@end

#pragma mark -

@interface JVStyleView (JVStyleViewPrivate)
- (void) _setupMarkedScroller;
- (void) _resetDisplay;
- (void) _switchStyle;
- (void) _appendMessage:(NSString *) message;
- (void) _prependMessages:(NSString *) messages;
- (void) _styleError;
- (NSString *) _fullDisplayHTMLWithBody:(NSString *) html;
- (unsigned long) _visibleMessageCount;
- (long) _locationOfMessage:(JVChatMessage *) message;
- (long) _locationOfElementAtIndex:(unsigned long) index;
@end

#pragma mark -

@implementation JVStyleView
- (id) initWithCoder:(NSCoder *) coder {
	if( ( self = [super initWithCoder:coder] ) ) {
		_switchingStyles = NO;
		_forwarding = NO;
		_ready = NO;
		_webViewReady = NO;
		_requiresFullMessage = YES;
		_scrollbackLimit = 600;
		_transcript = nil;
		_style = nil;
		_styleVariant = nil;
		_styleParameters = [[NSMutableDictionary dictionary] retain];
		_emoticons = nil;
		[self setNextTextView:nil];
	}

	return self;
}

- (void) awakeFromNib {
	_ready = YES;
	_newWebKit = [[self mainFrame] respondsToSelector:@selector( DOMDocument )];
	[self setFrameLoadDelegate:self];
	[self performSelector:@selector( _resetDisplay ) withObject:nil afterDelay:0.];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self setNextTextView:nil];
	[super dealloc];
}

#pragma mark -

- (void) forwardSelector:(SEL) selector withObject:(id) object {
	if( [self nextTextView] ) {
		[[self window] makeFirstResponder:[self nextTextView]];
		[[self nextTextView] tryToPerform:selector with:object];
	}
}

#pragma mark -

- (void) keyDown:(NSEvent *) event {
	if( _forwarding ) return;
	_forwarding = YES;
	[self forwardSelector:@selector( keyDown: ) withObject:event];
	_forwarding = NO;
}

- (void) pasteAsPlainText:(id) sender {
	if( _forwarding ) return;
	_forwarding = YES;
	[self forwardSelector:@selector( pasteAsPlainText: ) withObject:sender];
	_forwarding = NO;
}

- (void) pasteAsRichText:(id) sender {
	if( _forwarding ) return;
	_forwarding = YES;
	[self forwardSelector:@selector( pasteAsRichText: ) withObject:sender];
	_forwarding = NO;
}

#pragma mark -

- (NSTextView *) nextTextView {
	return nextTextView;
}

- (void) setNextTextView:(NSTextView *) textView {
	nextTextView = textView;
}

#pragma mark -

- (void) setTranscript:(JVChatTranscript *) transcript {
	[_transcript autorelease];
	_transcript = [transcript retain];
}

- (JVChatTranscript *) transcript {
	return _transcript;
}

#pragma mark -

- (void) setStyle:(JVStyle *) style {
	[self setStyle:style withVariant:[style defaultVariantName]];
}

- (void) setStyle:(JVStyle *) style withVariant:(NSString *) variant {
	if( [style isEqualTo:[self style]] ) {
		[self setStyleVariant:variant];
		return;
	}

	[_style autorelease];
	_style = [style retain];

	[_styleVariant autorelease];
	_styleVariant = [variant copyWithZone:[self zone]];

	// add single-quotes so that these are not interpreted as XPath expressions  
	[_styleParameters setObject:@"'/tmp/'" forKey:@"buddyIconDirectory"];  
	[_styleParameters setObject:@"'.tif'" forKey:@"buddyIconExtension"];

	NSString *timeFormatParameter = [NSString stringWithFormat:@"'%@'", [[NSUserDefaults standardUserDefaults] stringForKey:NSTimeFormatString]];
	[_styleParameters setObject:timeFormatParameter forKey:@"timeFormat"];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:JVStyleVariantChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _styleVariantChanged: ) name:JVStyleVariantChangedNotification object:style];

	_switchingStyles = YES;
	_requiresFullMessage = YES;

	if( ! _ready ) return;

	[self _resetDisplay];
}

- (JVStyle *) style {
	return [[_style retain] autorelease];
}

#pragma mark -

- (void) setStyleVariant:(NSString *) variant {
	[_styleVariant autorelease];
	_styleVariant = [variant copyWithZone:[self zone]];

	if( _webViewReady ) {
		[WebCoreCache empty];

#ifdef WebKitVersion146
		if( _newWebKit ) {
			NSString *styleSheetLocation = [[[self style] variantStyleSheetLocationWithName:_styleVariant] absoluteString];
			DOMHTMLLinkElement *element = (DOMHTMLLinkElement *)[[[self mainFrame] DOMDocument] getElementById:@"variantStyle"];
			if( ! styleSheetLocation ) [element setHref:@""];
			else [element setHref:styleSheetLocation];
		} else
#endif
		[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"setStylesheet( \"variantStyle\", \"%@\" );", [[[self style] variantStyleSheetLocationWithName:_styleVariant] absoluteString]]];

		[self performSelector:@selector( _checkForTransparantStyle ) withObject:nil afterDelay:0.];
	} else {
		[self performSelector:_cmd withObject:variant afterDelay:0.];
	}
}

- (NSString *) styleVariant {
	return _styleVariant;
}

#pragma mark -

- (void) setStyleParameters:(NSDictionary *) parameters {
	[_styleParameters autorelease];
	_styleParameters = [parameters mutableCopyWithZone:[self zone]];
}

- (NSDictionary *) styleParameters {
	return _styleParameters;
}

#pragma mark -

- (void) setEmoticons:(JVEmoticonSet *) emoticons {
	[_emoticons autorelease];
	_emoticons = [emoticons retain];

	if( _webViewReady ) {
		[WebCoreCache empty];

#ifdef WebKitVersion146
		if( _newWebKit ) {
			NSString *styleSheetLocation = [[[self emoticons] styleSheetLocation] absoluteString];
			DOMHTMLLinkElement *element = (DOMHTMLLinkElement *)[[[self mainFrame] DOMDocument] getElementById:@"emoticonStyle"];
			if( ! styleSheetLocation ) [element setHref:@""];
			else [element setHref:styleSheetLocation];
		} else
#endif
		[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"setStylesheet( \"emoticonStyle\", \"%@\" );", [[[self emoticons] styleSheetLocation] absoluteString]]];
	} else {
		[self performSelector:_cmd withObject:emoticons afterDelay:0.];
	}
}

- (JVEmoticonSet *) emoticons {
	return _emoticons;
}

#pragma mark -

- (void) setScrollbackLimit:(unsigned int) limit {
	_scrollbackLimit = limit;
}

- (unsigned int) scrollbackLimit {
	return _scrollbackLimit;
}

#pragma mark -

- (void) reloadCurrentStyle {
	_switchingStyles = YES;
	_requiresFullMessage = YES;
	_rememberScrollPosition = YES;

	[WebCoreCache empty];

	[self _resetDisplay];
}

- (void) clear {
	_switchingStyles = NO;
	_requiresFullMessage = YES;
	[self _resetDisplay];
}

- (void) mark {
	if( _webViewReady ) {
		unsigned int location = 0;

#ifdef WebKitVersion146
		if( _newWebKit ) {
			DOMDocument *doc = [[self mainFrame] DOMDocument];
			DOMElement *elt = [doc getElementById:@"mark"];
			if( elt ) [[elt parentNode] removeChild:elt];
			elt = [doc createElement:@"hr"];
			[elt setAttribute:@"id" :@"mark"];
			[[[doc getElementsByTagName:@"body"] item:0] appendChild:elt];
			[self scrollToBottom];
			location = [[elt valueForKey:@"offsetTop"] intValue];
		} else
#endif
		location = [[self stringByEvaluatingJavaScriptFromString:@"mark();"] intValue];

		[[self verticalMarkedScroller] removeMarkWithIdentifier:@"mark"];
		[[self verticalMarkedScroller] addMarkAt:location withIdentifier:@"mark" withColor:[NSColor redColor]];

		_requiresFullMessage = YES;
	} else {
		[self performSelector:_cmd withObject:nil afterDelay:0.];
	}
}

#pragma mark -

- (void) showTopic:(NSString *) topic {
	if( ! topic ) return; // don't show anything if there is no topic

	if( _webViewReady ) {
#ifdef WebKitVersion146
		if( _newWebKit ) {
			[[self windowScriptObject] callWebScriptMethod:@"showTopic" withArguments:[NSArray arrayWithObject:topic]];
		} else {
#endif
			NSMutableString *mutTopic = [topic mutableCopy];
			[mutTopic replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:NSLiteralSearch range:NSMakeRange(0, [mutTopic length])];
			[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"showTopic( \"%@\" );", mutTopic]];
#ifdef WebKitVersion146
		}
#endif
	} else {
		[self performSelector:_cmd withObject:topic afterDelay:0.];
	}
}

- (void) hideTopic {
	if( _webViewReady ) {
#ifdef WebKitVersion146
		if( _newWebKit )
			[[self windowScriptObject] callWebScriptMethod:@"hideTopic" withArguments:[NSArray array]];
		else
#endif
			[self stringByEvaluatingJavaScriptFromString:@"hideTopic();"];
	} else {
		[self performSelector:_cmd withObject:nil afterDelay:0.];
	}
}

- (void) toggleTopic:(NSString *) topic {
	if( _webViewReady ) {
		BOOL topicShowing;
#ifdef WebKitVersion146
		if( _newWebKit ) {
			DOMHTMLElement *topicElement = (DOMHTMLElement *)[[[self mainFrame] DOMDocument] getElementById:@"topic-floater"];
			topicShowing = ( topicElement != nil );
		} else {
#endif
			NSString *result = [self stringByEvaluatingJavaScriptFromString:@"document.getElementById(\"topic-floater\") != null"];
			topicShowing = [result isEqualToString:@"true"];
#ifdef WebKitVersion146
		}
#endif
		if( topicShowing ) [self hideTopic];
		else [self showTopic:topic];
	} else {
		[self performSelector:_cmd withObject:topic afterDelay:0.];
	}
}

#pragma mark -

- (BOOL) appendChatMessage:(JVChatMessage *) message {
	if( ! _webViewReady ) return; // don't schedule this to fire later since the transcript will be processed

	NSString *result = nil;

#ifdef WebKitVersion146
	if( _requiresFullMessage && _newWebKit ) {
		DOMHTMLElement *replaceElement = (DOMHTMLElement *)[[[self mainFrame] DOMDocument] getElementById:@"consecutiveInsert"];
		if( replaceElement ) _requiresFullMessage = NO; // a full message was assumed, but we can do a consecutive one
	}
#endif

	@try {
		if( _requiresFullMessage ) {
			NSArray *elements = [NSArray arrayWithObject:message];
			result = [[self style] transformChatTranscriptElements:elements withParameters:[self styleParameters]];
			_requiresFullMessage = NO;
		} else {
			result = [[self style] transformChatMessage:message withParameters:[self styleParameters]];
		}
	} @catch ( NSException *exception ) {
		result = nil;
		[self _styleError];
		return;
	}

	if( [result length] ) [self _appendMessage:result];

	return ( [result length] ? YES : NO );
}

- (BOOL) appendChatTranscriptElement:(id <JVChatTranscriptElement>) element {
	if( ! _webViewReady ) return; // don't schedule this to fire later since the transcript will be processed

	NSString *result = nil;

	@try {
		result = [[self style] transformChatTranscriptElement:element withParameters:[self styleParameters]];
	} @catch ( NSException *exception ) {
		result = nil;
		[self _styleError];
		return;
	}

	if( [result length] ) [self _appendMessage:result];

	return ( [result length] ? YES : NO );
}

#pragma mark -

- (void) highlightMessage:(JVChatMessage *) message {
/*#ifdef WebKitVersion146
	if( _newWebKit ) {
		DOMHTMLElement *element = (DOMHTMLElement *)[[[self mainFrame] DOMDocument] getElementById:[message messageIdentifier]];
		NSString *class = [element className];
		if( [[element className] rangeOfString:@"searchHighlight"].location != NSNotFound ) return;
		if( [class length] ) [element setClassName:[class stringByAppendingString:@" searchHighlight"]];
		else [element setClassName:@"searchHighlight"];
	} else
#endif
	[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"highlightMessage('%@');", [message messageIdentifier]]];
*/}

- (void) clearHighlightForMessage:(JVChatMessage *) message {
/*#ifdef WebKitVersion146
	if( _newWebKit ) {
		DOMHTMLElement *element = (DOMHTMLElement *)[[[self mainFrame] DOMDocument] getElementById:[message messageIdentifier]];
		NSMutableString *class = [[[element className] mutableCopy] autorelease];
		[class replaceOccurrencesOfString:@"searchHighlight" withString:@"" options:NSLiteralSearch range:NSMakeRange( 0, [class length] )];
		[element setClassName:class];
	} else
#endif
	[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"resetHighlightMessage('%@');", [message messageIdentifier]]];
*/}

- (void) clearAllMessageHighlights {
/*#ifdef WebKitVersion146
	if( _newWebKit ) {
		[[self windowScriptObject] callWebScriptMethod:@"resetHighlightMessage" withArguments:[NSArray arrayWithObject:[NSNull null]]];
	} else
#endif
	[self stringByEvaluatingJavaScriptFromString:@"resetHighlightMessage(null);"];
*/}

#pragma mark -

- (void) highlightString:(NSString *) string inMessage:(JVChatMessage *) message {
#ifdef WebKitVersion146
	if( _newWebKit ) {
		[[self windowScriptObject] callWebScriptMethod:@"searchHighlight" withArguments:[NSArray arrayWithObjects:[message messageIdentifier], string, nil]];
	} else
#endif
	[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"searchHighlight('%@','%@');", [message messageIdentifier], string]];
}

- (void) clearStringHighlightsForMessage:(JVChatMessage *) message {
#ifdef WebKitVersion146
	if( _newWebKit ) {
		[[self windowScriptObject] callWebScriptMethod:@"resetSearchHighlight" withArguments:[NSArray arrayWithObject:[message messageIdentifier]]];
	} else
#endif
	[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"resetSearchHighlight('%@');", [message messageIdentifier]]];
}

- (void) clearAllStringHighlights {
#ifdef WebKitVersion146
	if( _newWebKit ) {
		[[self windowScriptObject] callWebScriptMethod:@"resetSearchHighlight" withArguments:[NSArray arrayWithObject:[NSNull null]]];
	} else
#endif
	[self stringByEvaluatingJavaScriptFromString:@"resetSearchHighlight(null);"];
}

#pragma mark -

- (void) markScrollbarForMessage:(JVChatMessage *) message {
	if( _switchingStyles || ! _webViewReady ) {
		[self performSelector:_cmd withObject:message afterDelay:0.];
		return;
	}

	long loc = [self _locationOfMessage:message];
	if( loc ) [[self verticalMarkedScroller] addMarkAt:loc];
}

- (void) markScrollbarForMessage:(JVChatMessage *) message usingMarkIdentifier:(NSString *) identifier andColor:(NSColor *) color {
	if( _switchingStyles || ! _webViewReady ) return; // can't queue, too many args. NSInvocation?

	long loc = [self _locationOfMessage:message];
	if( loc ) [[self verticalMarkedScroller] addMarkAt:loc withIdentifier:identifier withColor:color];
}

- (void) markScrollbarForMessages:(NSArray *) messages {
	if( _switchingStyles || ! _webViewReady ) {
		[self performSelector:_cmd withObject:messages afterDelay:0.];
		return;
	}

	JVMarkedScroller *scroller = [self verticalMarkedScroller];
	NSEnumerator *enumerator = [messages objectEnumerator];
	JVChatMessage *message = nil;

	while( ( message = [enumerator nextObject] ) ) {
		long loc = [self _locationOfMessage:message];
		if( loc ) [scroller addMarkAt:loc];
	}
}

#pragma mark -

- (void) clearScrollbarMarks {
	JVMarkedScroller *scroller = [self verticalMarkedScroller];
	[scroller removeAllMarks];
	[scroller removeAllShadedAreas];
}

- (void) clearScrollbarMarksWithIdentifier:(NSString *) identifier {
	JVMarkedScroller *scroller = [self verticalMarkedScroller];
	[scroller removeMarkWithIdentifier:identifier];
}

#pragma mark -

- (void) webView:(WebView *) sender didFinishLoadForFrame:(WebFrame *) frame {
	[self performSelector:@selector( _checkForTransparantStyle )];

	[self setPreferencesIdentifier:[[self style] identifier]];
	[[self preferences] setJavaScriptEnabled:YES];

	[[self verticalMarkedScroller] removeAllMarks];
	[[self verticalMarkedScroller] removeAllShadedAreas];

	if( [[self window] isFlushWindowDisabled] ) [[self window] enableFlushWindow];
	[[self window] displayIfNeeded];

	[self performSelector:@selector( _webkitIsReady ) withObject:nil afterDelay:0.];
}

#pragma mark -
#pragma mark Highlight/Message Jumping

- (JVMarkedScroller *) verticalMarkedScroller {
	NSScrollView *scrollView = [[[[self mainFrame] frameView] documentView] enclosingScrollView];
	JVMarkedScroller *scroller = (JVMarkedScroller *)[scrollView verticalScroller];
	if( scroller && ! [scroller isMemberOfClass:[JVMarkedScroller class]] ) {
		[self _setupMarkedScroller];
		scroller = (JVMarkedScroller *)[scrollView verticalScroller];
		if( scroller && ! [scroller isMemberOfClass:[JVMarkedScroller class]] )
			return nil; // not sure, but somthing is wrong
	}

	return scroller;
}

- (IBAction) jumpToMark:(id) sender {
	[[self verticalMarkedScroller] jumpToMarkWithIdentifier:@"mark"];
}

- (IBAction) jumpToPreviousHighlight:(id) sender {
	[[self verticalMarkedScroller] jumpToPreviousMark:sender];
}

- (IBAction) jumpToNextHighlight:(id) sender {
	[[self verticalMarkedScroller] jumpToNextMark:sender];
}

- (void) jumpToMessage:(JVChatMessage *) message {
	unsigned long loc = [self _locationOfMessage:message];
	if( loc ) {
		NSScroller *scroller = [self verticalMarkedScroller];
		float scale = NSHeight( [scroller rectForPart:NSScrollerKnobSlot] ) / ( NSHeight( [scroller frame] ) / [scroller knobProportion] );
		float shift = ( ( NSHeight( [scroller rectForPart:NSScrollerKnobSlot] ) * [scroller knobProportion] ) / 2. ) / scale;
		[[(NSScrollView *)[scroller superview] documentView] scrollPoint:NSMakePoint( 0., loc - shift )];
	}
}

- (void) scrollToBottom {
	if( ! _webViewReady ) {
		[self performSelector:_cmd withObject:nil afterDelay:0.];
		return;
	}

#ifdef WebKitVersion146
	if( _newWebKit ) {
		DOMHTMLElement *body = [(DOMHTMLDocument *)[[self mainFrame] DOMDocument] body];
		[body setValue:[body valueForKey:@"offsetHeight"] forKey:@"scrollTop"];
	} else
#endif
	[self stringByEvaluatingJavaScriptFromString:@"scrollToBottom();"];
}
@end

#pragma mark -

@implementation JVStyleView (JVStyleViewPrivate)
- (void) _checkForTransparantStyle {
#ifdef WebKitVersion146
	if( _newWebKit ) {
		DOMCSSStyleDeclaration *style = [self computedStyleForElement:[(DOMHTMLDocument *)[[self mainFrame] DOMDocument] body] pseudoElement:nil];
		DOMCSSValue *value = [style getPropertyCSSValue:@"background-color"];
		DOMCSSValue *altvalue = [style getPropertyCSSValue:@"background"];
		if( ( value && [[value cssText] rangeOfString:@"rgba"].location != NSNotFound ) || ( altvalue && [[altvalue cssText] rangeOfString:@"rgba"].location != NSNotFound ) )
			[self setDrawsBackground:NO]; // allows rgba backgrounds to see through to the Desktop
		else [self setDrawsBackground:YES];
		[self setNeedsDisplay:YES];
	}
#endif
}

- (void) _webkitIsReady {
	_webViewReady = YES;
	if( _switchingStyles )
		[NSThread detachNewThreadSelector:@selector( _switchStyle ) toTarget:self withObject:nil];
}

- (void) _resetDisplay {
	[[self class] cancelPreviousPerformRequestsWithTarget:self selector:_cmd object:nil];

	[self stopLoading:nil];
	[self clearScrollbarMarks];

	_webViewReady = NO;
	if( _rememberScrollPosition ) {
#ifdef WebKitVersion146
		if( _newWebKit ) {
			DOMHTMLElement *body = [(DOMHTMLDocument *)[[self mainFrame] DOMDocument] body];
			_lastScrollPosition = [[body valueForKey:@"scrollTop"] intValue];
		} else
#endif
		_lastScrollPosition = [[self stringByEvaluatingJavaScriptFromString:@"document.body.scrollTop"] intValue];
	} else _lastScrollPosition = 0;

	[[self window] disableFlushWindow];
	[[self mainFrame] loadHTMLString:[self _fullDisplayHTMLWithBody:@""] baseURL:nil];
}

- (void) _switchStyle {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[NSThread setThreadPriority:0.25];

	usleep( 250 ); // wait, WebKit might not be ready.

	JVStyle *style = [[self style] retain];
	JVChatTranscript *transcript = [[self transcript] retain];
	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:[self styleParameters]];
	unsigned long elementCount = [transcript elementCount];
	unsigned long i = elementCount;
	NSEnumerator *enumerator = nil;
	NSArray *elements = nil;
	id element = nil;
	NSString *result = nil;
	NSMutableArray *highlightedMsgs = [NSMutableArray arrayWithCapacity:( [self scrollbackLimit] / 8 )];

	[parameters setObject:@"'yes'" forKey:@"bulkTransform"];

	for( i = elementCount; i > ( elementCount - MIN( [self scrollbackLimit], elementCount ) ); i -= MIN( 25, i ) ) {
		elements = [transcript elementsInRange:NSMakeRange( i - MIN( 25, i ), MIN( 25, i ) )];

		enumerator = [elements objectEnumerator];
		while( ( element = [enumerator nextObject] ) )
			if( [element isKindOfClass:[JVChatMessage class]] && [element isHighlighted] )
				[highlightedMsgs addObject:element];

		@try {
			result = [style transformChatTranscriptElements:elements withParameters:parameters];
		} @catch ( NSException *exception ) {
			result = nil;
			[self performSelectorOnMainThread:@selector( _styleError ) withObject:exception waitUntilDone:YES];
			goto quickEnd;
		}

		if( [self style] != style ) goto quickEnd;
		if( result ) {
			[self performSelectorOnMainThread:@selector( _prependMessages: ) withObject:result waitUntilDone:YES];
			usleep( 100000 ); // give time to other threads
		}
	}

	_switchingStyles = NO;
	[self performSelectorOnMainThread:@selector( markScrollbarForMessages: ) withObject:highlightedMsgs waitUntilDone:YES];

quickEnd:
	[self performSelectorOnMainThread:@selector( _switchingStyleFinished: ) withObject:nil waitUntilDone:YES];

	NSNotification *note = [NSNotification notificationWithName:JVStyleViewDidChangeStylesNotification object:self userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
	
	[style release];
	[transcript release];
	[pool release];
}

- (void) _switchingStyleFinished:(id) sender {
	_switchingStyles = NO;

	if( _rememberScrollPosition ) {
		_rememberScrollPosition = NO;
#ifdef WebKitVersion146
		if( _newWebKit ) {
			DOMHTMLElement *body = [(DOMHTMLDocument *)[[self mainFrame] DOMDocument] body];
			[body setValue:[NSNumber numberWithUnsignedInt:_lastScrollPosition] forKey:@"scrollTop"];
		} else
#endif
		[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.body.scrollTop = %d", _lastScrollPosition]];
	}
}

- (void) _appendMessage:(NSString *) message {
	unsigned int messageCount = [self _visibleMessageCount];
	unsigned int scrollbackLimit = [self scrollbackLimit];
	BOOL subsequent = ( [message rangeOfString:@"<?message type=\"subsequent\"?>"].location != NSNotFound );

	if( ! subsequent && ( messageCount + 1 ) > scrollbackLimit ) {
		long loc = [self _locationOfElementAtIndex:( ( messageCount + 1 ) - scrollbackLimit )];
		if( loc > 0 ) [[self verticalMarkedScroller] shiftMarksAndShadedAreasBy:( loc * -1 )];
	}

#ifdef WebKitVersion146
	if( _newWebKit ) {
		DOMHTMLElement *element = (DOMHTMLElement *)[[[self mainFrame] DOMDocument] createElement:@"span"];
		DOMHTMLElement *replaceElement = (DOMHTMLElement *)[[[self mainFrame] DOMDocument] getElementById:@"consecutiveInsert"];
		if( ! replaceElement ) subsequent = NO;

		NSMutableString *transformedMessage = [message mutableCopy];
		[transformedMessage replaceOccurrencesOfString:@"  " withString:@"&nbsp; " options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];
		[transformedMessage replaceOccurrencesOfString:@"<?message type=\"subsequent\"?>" withString:@"" options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];

		// parses the message so we can get the DOM tree
		[element setInnerHTML:transformedMessage];

		[transformedMessage release];
		transformedMessage = nil;

		// check if we are near the bottom of the chat area, and if we should scroll down later
		NSNumber *scrollNeeded = [[[self mainFrame] DOMDocument] evaluateWebScript:@"( document.body.scrollTop >= ( document.body.offsetHeight - ( window.innerHeight * 1.1 ) ) )"];
		DOMHTMLElement *body = [(DOMHTMLDocument *)[[self mainFrame] DOMDocument] body];

		unsigned int i = 0;
		if( ! subsequent ) { // append message normally
			[[replaceElement parentNode] removeChild:replaceElement];
			while( [[element childNodes] length] ) { // append all children
				DOMNode *node = [[element firstChild] retain];
				[element removeChild:node];
				[body appendChild:node];
				[node release];
			}
		} else if( [[element childNodes] length] >= 1 ) { // append as a subsequent message
			DOMNode *parent = [replaceElement parentNode];
			DOMNode *nextSib = [replaceElement nextSibling];
			[parent replaceChild:[element firstChild] :replaceElement]; // replaces the consecutiveInsert node
			while( [[element childNodes] length] ) { // append all remaining children (in reverse order)
				DOMNode *node = [[element firstChild] retain];
				[element removeChild:node];
				if( nextSib ) [parent insertBefore:node :nextSib];
				else [parent appendChild:node];
				[node release];
			}
		}

		// enforce the scrollback limit
		if( scrollbackLimit > 0 && [[body childNodes] length] > scrollbackLimit )
			for( i = 0; [[body childNodes] length] > scrollbackLimit && i < ( [[body childNodes] length] - scrollbackLimit ); i++ )
				[body removeChild:[[body childNodes] item:0]];

		if( [scrollNeeded respondsToSelector:@selector( boolValue )] && [scrollNeeded boolValue] )
			[self scrollToBottom];
	} else
#endif
	{ // old JavaScript method
		NSMutableString *transformedMessage = [message mutableCopy];
		[transformedMessage escapeCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\\\"'"]];
		[transformedMessage replaceOccurrencesOfString:@"\n" withString:@"\\n" options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];
		[transformedMessage replaceOccurrencesOfString:@"  " withString:@"&nbsp; " options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];
		[transformedMessage replaceOccurrencesOfString:@"<?message type=\"subsequent\"?>" withString:@"" options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];
		if( subsequent ) [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"scrollBackLimit = %d; appendConsecutiveMessage( \"%@\" );", scrollbackLimit, transformedMessage]];
		else [self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"scrollBackLimit = %d; appendMessage( \"%@\" );", scrollbackLimit, transformedMessage]];
		[transformedMessage release];
	}
}

- (void) _prependMessages:(NSString *) messages {
#ifdef WebKitVersion146
	if( _newWebKit ) {
		NSMutableString *result = [messages mutableCopy];
		[result replaceOccurrencesOfString:@"  " withString:@"&nbsp; " options:NSLiteralSearch range:NSMakeRange( 0, [result length] )];

		// check if we are near the bottom of the chat area, and if we should scroll down later
		NSNumber *scrollNeeded = [[[self mainFrame] DOMDocument] evaluateWebScript:@"( document.body.scrollTop >= ( document.body.offsetHeight - ( window.innerHeight * 1.1 ) ) )"];

		// parses the message so we can get the DOM tree
		DOMHTMLElement *element = (DOMHTMLElement *)[[[self mainFrame] DOMDocument] createElement:@"span"];
		[element setInnerHTML:result];

		[result release];
		result = nil;

		DOMHTMLElement *body = [(DOMHTMLDocument *)[[self mainFrame] DOMDocument] body];
		DOMNode *firstMessage = [body firstChild];

		while( [[element childNodes] length] ) { // append all children
			if( firstMessage ) [body insertBefore:[element firstChild] :firstMessage];
			else [body appendChild:[element firstChild]];
		}

		if( [scrollNeeded boolValue] ) [self scrollToBottom];
	} else
#endif
	{ // old JavaScript method
		NSMutableString *result = [messages mutableCopy];
		[result escapeCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\\\"'"]];
		[result replaceOccurrencesOfString:@"\n" withString:@"\\n" options:NSLiteralSearch range:NSMakeRange( 0, [result length] )];
		[result replaceOccurrencesOfString:@"  " withString:@"&nbsp; " options:NSLiteralSearch range:NSMakeRange( 0, [result length] )];
		[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"prependMessages( \"%@\" );", result]];
		[result release];
	}
}

- (void) _styleError {
	NSRunCriticalAlertPanel( NSLocalizedString( @"An internal Style error occurred.", "the stylesheet parse failed" ), NSLocalizedString( @"The %@ Style has been damaged or has an internal error preventing new messages from displaying. Please contact the %@ author about this.", "the style contains and error" ), @"OK", nil, nil, [[self style] displayName], [[self style] displayName] );
}

- (void) _styleVariantChanged:(NSNotification *) notification {
	NSString *variant = [[notification userInfo] objectForKey:@"variant"];
	if( [variant isEqualToString:[self styleVariant]] )
		[self setStyleVariant:variant];
}

#pragma mark -

- (NSString *) _fullDisplayHTMLWithBody:(NSString *) html {
	NSURL *resources = [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]];
	NSURL *defaultStyleSheetLocation = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"default" ofType:@"css"]];
	NSString *variantStyleSheetLocation = [[[self style] variantStyleSheetLocationWithName:[self styleVariant]] absoluteString];
	if( ! variantStyleSheetLocation ) variantStyleSheetLocation = @"";
	NSString *shell = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"template" ofType:@"html"]];
	return [NSString stringWithFormat:shell, @"", [resources absoluteString], [defaultStyleSheetLocation absoluteString], [[[self emoticons] styleSheetLocation] absoluteString], [[[self style] mainStyleSheetLocation] absoluteString], variantStyleSheetLocation, [[[self style] baseLocation] absoluteString], [[self style] contentsOfHeaderFile], html];
}

#pragma mark -

- (long) _locationOfMessageWithIdentifier:(NSString *) identifier {
	if( ! _webViewReady ) return 0;
	if( ! [identifier length] ) return 0;
#ifdef WebKitVersion146
	if( _newWebKit ) {
		DOMElement *element = [[[self mainFrame] DOMDocument] getElementById:identifier];
		id value = [element valueForKey:@"offsetTop"];
		if( [value respondsToSelector:@selector( intValue )] )
			return [value intValue];
		return 0;
	} else
#endif
	return [[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"locationOfMessage( \"%@\" );", identifier]] intValue];
}

- (long) _locationOfMessage:(JVChatMessage *) message {
	return [self _locationOfMessageWithIdentifier:[message messageIdentifier]];
}

- (long) _locationOfElementAtIndex:(unsigned long) index {
	if( ! _webViewReady ) return 0;
#ifdef WebKitVersion146
	if( _newWebKit ) {
		DOMHTMLElement *body = [(DOMHTMLDocument *)[[self mainFrame] DOMDocument] body];
		id value = [[[body childNodes] item:index] valueForKey:@"offsetTop"];
		if( index < [[body childNodes] length] && [value respondsToSelector:@selector( intValue )] )
			return [value intValue];
		return 0;
	} else
#endif
	return [[self stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"locationOfElementAtIndex( %d );", index]] intValue];
}

- (unsigned long) _visibleMessageCount {
	if( ! _webViewReady ) return 0;
#ifdef WebKitVersion146
	if( _newWebKit ) {
		return [[[(DOMHTMLDocument *)[[self mainFrame] DOMDocument] body] childNodes] length];
	} else
#endif
	return [[self stringByEvaluatingJavaScriptFromString:@"scrollBackMessageCount();"] intValue];
}

#pragma mark -

- (void) _setupMarkedScroller {
	if( ! _webViewReady ) {
		[self performSelector:_cmd withObject:nil afterDelay:0.];
		return;
	}

	NSScrollView *scrollView = [[[[self mainFrame] frameView] documentView] enclosingScrollView];
	[scrollView setHasHorizontalScroller:NO];
	[scrollView setAllowsHorizontalScrolling:NO];

	JVMarkedScroller *scroller = (JVMarkedScroller *)[scrollView verticalScroller];
	if( scroller && ! [scroller isMemberOfClass:[JVMarkedScroller class]] ) {
		NSRect scrollerFrame = [[scrollView verticalScroller] frame];
		NSScroller *oldScroller = scroller;
		scroller = [[[JVMarkedScroller alloc] initWithFrame:scrollerFrame] autorelease];
		[scroller setFloatValue:[oldScroller floatValue] knobProportion:[oldScroller knobProportion]];
		[scrollView setVerticalScroller:scroller];
	}
}
@end