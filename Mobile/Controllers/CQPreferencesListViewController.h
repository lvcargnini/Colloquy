#import "CQTableViewController.h"

@class AVAudioPlayer;
@class CQPreferencesListEditViewController;
@class CQPreferencesListViewController;

typedef NS_ENUM(NSInteger, CQPreferencesListType) {
	CQPreferencesListTypeNone,
	CQPreferencesListTypeAudio,
	CQPreferencesListTypeFont,
	CQPreferencesListTypeImage
};

NS_ASSUME_NONNULL_BEGIN

typedef void (^CQPreferencesListBlock)(CQPreferencesListViewController *preferencesListViewController);

@interface CQPreferencesListViewController : CQTableViewController {
	@protected
	NSMutableArray *_items;
	UIImage *_itemImage;
	NSString *_addItemLabelText;
	NSString *_noItemsLabelText;
	NSString *_editViewTitle;
	NSString *_editPlaceholder;
	NSString *_footerText;
	NSUInteger _editingIndex;
	NSInteger _selectedItemIndex;
	CQPreferencesListEditViewController *_editingViewController;
	id _customEditingViewController;
	id __weak _target;
	SEL _action;
	CQPreferencesListBlock _preferencesListBlock;
	BOOL _pendingChanges;
	BOOL _allowEditing;

	CQPreferencesListType _listType;

	AVAudioPlayer *_audioPlayer;
}
@property (nonatomic) BOOL allowEditing;
@property (nonatomic) NSInteger selectedItemIndex;
@property (nonatomic, copy) NSArray *items;
@property (nonatomic, copy) NSArray *values;
@property (nonatomic, copy) NSArray *details;
@property (nonatomic, strong) UIImage *itemImage;
@property (nonatomic, copy) NSString *addItemLabelText;
@property (nonatomic, copy) NSString *noItemsLabelText;
@property (nonatomic, copy) NSString *editViewTitle;
@property (nonatomic, copy) NSString *editPlaceholder;
@property (nonatomic, copy) NSString *footerText;
@property (nonatomic, strong) id customEditingViewController;

@property (nonatomic, nullable, weak) id target;
@property (nonatomic) SEL action;
@property (nonatomic, copy) CQPreferencesListBlock preferencesListBlock;

@property (nonatomic) CQPreferencesListType listType;
@end

NS_ASSUME_NONNULL_END
