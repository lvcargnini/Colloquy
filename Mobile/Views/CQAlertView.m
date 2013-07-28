#import "CQAlertView.h"

@implementation CQAlertView
- (id) init {
	if (!(self = [super init]))
		return nil;

	_textFieldInformation = [[NSMutableArray alloc] init];

	return self;
}

#pragma mark -

- (void) _updateTextFieldsForDisplay {
	if (_textFieldInformation.count == 0)
		self.alertViewStyle = UIAlertViewStyleDefault;
	else if (_textFieldInformation.count == 1)
		self.alertViewStyle = UIAlertViewStylePlainTextInput;
	else self.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;

	for (NSUInteger i = 0; i < _textFieldInformation.count; i++) {
		NSDictionary *textFieldInformation = _textFieldInformation[i];
		UITextField *textField = [self textFieldAtIndex:i];

		textField.placeholder = textFieldInformation[@"placeholder"];
		textField.text = textFieldInformation[@"text"];
		textField.secureTextEntry = !!textFieldInformation[@"secure"];
	}
}

- (void) addTextFieldWithPlaceholder:(NSString *) placeholder andText:(NSString *) text {
	NSAssert(_textFieldInformation.count + 1 < 3, @"alertView's are limited to a max of 2 textfields as of iOS 5", nil);

	NSMutableDictionary *textFieldInformation = [NSMutableDictionary dictionary];

	if (placeholder.length)
		textFieldInformation[@"placeholder"] = placeholder;
	if (text.length)
		textFieldInformation[@"text"] = text;

	[_textFieldInformation addObject:textFieldInformation];

	[self _updateTextFieldsForDisplay];
}

- (void) addSecureTextFieldWithPlaceholder:(NSString *) placeholder {
	NSAssert(_textFieldInformation.count + 1 < 3, @"alertView's are limited to a max of 2 textfields as of iOS 5", nil);

	NSMutableDictionary *textFieldInformation = [NSMutableDictionary dictionary];

	if (placeholder.length)
		textFieldInformation[@"placeholder"] = placeholder;
	textFieldInformation[@"secure"] = @YES;

	[_textFieldInformation addObject:textFieldInformation];

	[self _updateTextFieldsForDisplay];
}
@end
