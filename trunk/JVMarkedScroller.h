
@interface JVMarkedScroller : NSScroller {
	NSMutableSet *_marks;
	NSMutableArray *_shades;
	unsigned long long _nearestPreviousMark;
	unsigned long long _nearestNextMark;
	unsigned long long _currentMark;
	BOOL _jumpingToMark;
}
- (IBAction) jumpToPreviousMark:(id) sender;
- (IBAction) jumpToNextMark:(id) sender;

- (void) shiftMarksAndShadedAreasBy:(long long) displacement;

- (void) addMarkAt:(unsigned long long) location;
- (void) removeMarkAt:(unsigned long long) location;
- (void) removeMarksGreaterThan:(unsigned long long) location;
- (void) removeMarksLessThan:(unsigned long long) location;
- (void) removeMarksInRange:(NSRange) range;
- (void) removeAllMarks;

- (void) setMarks:(NSSet *) marks;
- (NSSet *) marks;

- (void) startShadedAreaAt:(unsigned long long) location;
- (void) stopShadedAreaAt:(unsigned long long) location;

- (void) removeAllShadedAreas;
@end
