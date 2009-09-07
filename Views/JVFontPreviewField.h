@interface JVFontPreviewField : NSTextField {
	NSFont *_actualFont;
	BOOL _showPointSize;
	BOOL _showFontFace;
}
- (void) selectFont:(id) sender;
- (IBAction) chooseFontWithFontPanel:(id) sender;
- (void) setShowPointSize:(BOOL) show;
@end

@interface NSObject (JVFontPreviewFieldDelegate)
- (BOOL) fontPreviewField:(JVFontPreviewField *) field shouldChangeToFont:(NSFont *) font;
- (void) fontPreviewField:(JVFontPreviewField *) field didChangeToFont:(NSFont *) font;
@end