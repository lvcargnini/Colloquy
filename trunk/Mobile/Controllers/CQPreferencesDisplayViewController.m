#import "CQPreferencesDisplayViewController.h"

#import "CQPreferencesListViewController.h"

#import "CQPreferencesSwitchCell.h"
#import "CQPreferencesTextCell.h"

// These are defined as constants because they are used in Settings.app
static NSString *const CQPSGroupSpecifier = @"PSGroupSpecifier";
static NSString *const CQPSTextFieldSpecifier = @"PSTextFieldSpecifier";
static NSString *const CQPSToggleSwitchSpecifier = @"PSToggleSwitchSpecifier";
static NSString *const CQPSChildPaneSpecifier = @"PSChildPaneSpecifier";
static NSString *const CQPSMultiValueSpecifier = @"PSMultiValueSpecifier";
static NSString *const CQPSTitleValueSpecifier = @"PSTitleValueSpecifier";

static NSString *const CQPSType = @"Type";
static NSString *const CQPSTitle = @"Title";
static NSString *const CQPSKey = @"Key";
static NSString *const CQPSDefaultValue = @"DefaultValue";
static NSString *const CQPSAction = @"CQAction";
static NSString *const CQPSAddress = @"CQAddress";
static NSString *const CQPSLink = @"Link";
static NSString *const CQPSEmail = @"Email";
static NSString *const CQPSFile = @"File";
static NSString *const CQPSValues = @"Values";
static NSString *const CQPSTitles = @"Titles";
static NSString *const CQPSFooterText = @"FooterText";
static NSString *const CQPSAutocorrectType = @"AutocorrectionType";
static NSString *const CQPSAutocorrectionTypeDefault = @"Default";
static NSString *const CQPSAutocorrectionTypeNo = @"No";
static NSString *const CQPSAutocorrectionTypeYes = @"Yes";
static NSString *const CQPSAutocapitalizationType = @"AutocapitalizationType";
static NSString *const CQPSAutocapitalizationTypeNone = @"None";
static NSString *const CQPSAutocapitalizationTypeSentences = @"Sentences";
static NSString *const CQPSAutocapitalizationTypeWords = @"Words";
static NSString *const CQPSAutocapitalizationTypeAllCharacters = @"AllCharacters";
static NSString *const CQPSIsSecure = @"IsSecure";
static NSString *const CQPSKeyboardType = @"KeyboardType";
static NSString *const CQPSKeyboardTypeAlphabet = @"Alphabet";
static NSString *const CQPSKeyboardTypeNumbersAndPunctuation = @"NumbersAndPunctuation";
static NSString *const CQPSKeyboardTypeNumberPad = @"NumberPad";
static NSString *const CQPSKeyboardTypeURL = @"URL";
static NSString *const CQPSKeyboardTypeEmailAddress = @"EmailAddress";
static NSString *const CQPSPreferenceSpecifiers = @"PreferenceSpecifiers";
static NSString *const CQPSPlaceholder = @"CQPlaceholder";
static NSString *const CQPSSupportedUserInterfaceIdioms = @"SupportedUserInterfaceIdioms";
static NSString *const CQPSListType = @"ListType";
static NSString *const CQPSListTypeAudio = @"Audio";
static NSString *const CQPSListTypeImage = @"Image";
static NSString *const CQPSListTypeFont = @"Font";

@implementation CQPreferencesDisplayViewController
- (id) initWithRootPlist {
	return [self initWithPlistNamed:@"Root"];
}

- (id) initWithPlistNamed:(NSString *) plist {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	_preferences = [[NSMutableArray alloc] init];

	[self performSelectorInBackground:@selector(_readSettingsFromPlist:) withObject:plist];

	return self;
}

- (void) dealloc {
	[_preferences release];
	[_selectedIndexPath release];

	[super dealloc];
}

#pragma mark -

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	if (_selectedIndexPath) {
		[self.tableView beginUpdates];
		[self.tableView reloadRowsAtIndexPaths:@[_selectedIndexPath] withRowAnimation:UITableViewRowAnimationNone];
		[self.tableView endUpdates];
	}
}

#pragma mark -

- (void) _readSettingsFromPlist:(NSString *) plist {
	NSString *settingsBundlePath = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
	NSString *settingsPath = [settingsBundlePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", plist]];

	NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:settingsPath];
	if (!preferences)
		return;

	if (!self.title.length)
		self.title = preferences[CQPSTitle];
	if (!self.title.length)
		self.title = [plist capitalizedStringWithLocale:[NSLocale currentLocale]];

	__block NSMutableDictionary *workingSection = nil;
	[preferences[CQPSPreferenceSpecifiers] enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
		if ([object[CQPSType] isEqualToString:CQPSGroupSpecifier]) {
			id old = workingSection;
			workingSection = [object mutableCopy];
			[old release];

			workingSection[@"rows"] = [NSMutableArray array];

			[_preferences addObject:workingSection];
		} else {
			NSMutableArray *rows = nil;
			if (_preferences.count)
				rows = [_preferences[(_preferences.count - 1)][@"rows"] retain];

			if (!rows) {
				rows = [[NSMutableArray alloc] init];
				workingSection = [[NSMutableDictionary alloc] init];
				workingSection[@"rows"] = rows;

				[_preferences addObject:workingSection];
			}

			NSArray *supportedInterfaceIdioms = object[CQPSSupportedUserInterfaceIdioms];
			BOOL supportsCurrentInterfaceIdiom = YES;
			if (supportedInterfaceIdioms) {
				supportsCurrentInterfaceIdiom = NO;

				for (NSString *userInterfaceIdiom in supportedInterfaceIdioms) {
					if (([userInterfaceIdiom isEqualToString:@"Pad"] && [UIDevice currentDevice].isPadModel) || ([userInterfaceIdiom isEqualToString:@"Phone"] && ![UIDevice currentDevice].isPadModel)) {
						supportsCurrentInterfaceIdiom = YES;

						break;
					}
				}
			}
			

			if (supportsCurrentInterfaceIdiom)
				[rows addObject:[[object copy] autorelease]];

			[rows release];
		}
	}];
	[workingSection release];

	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	return _preferences.count;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	return [_preferences[section][@"rows"] count];
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	return _preferences[section][CQPSTitle];
}

- (NSString *) tableView:(UITableView *) tableView titleForFooterInSection:(NSInteger) section {
	return _preferences[section][CQPSFooterText];
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	NSDictionary *rowDictionary = _preferences[indexPath.section][@"rows"][indexPath.row];
	if ([rowDictionary[CQPSType] isEqualToString:CQPSTitleValueSpecifier])
		if (!rowDictionary[CQPSAction])
			return nil;
	return indexPath;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	NSDictionary *rowDictionary = _preferences[indexPath.section][@"rows"][indexPath.row];
	id key = rowDictionary[CQPSKey];
	id value = nil;
	if (key) {
		value = [[CQSettingsController settingsController] objectForKey:key];
		if (!value)
			value = rowDictionary[CQPSDefaultValue];
	}

	if ([rowDictionary[CQPSType] isEqualToString:CQPSTextFieldSpecifier]) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];
		cell.textField.text = [[NSBundle mainBundle] localizedStringForKey:value value:@"" table:nil];

		if (!cell.textField.text.length) {
			if (value)
				cell.textField.text = value;
			else cell.textField.text = rowDictionary[CQPSDefaultValue];
		}

		cell.textLabel.text = [[NSBundle mainBundle] localizedStringForKey:rowDictionary[CQPSTitle] value:@"" table:nil];;
		cell.textFieldBlock = ^(UITextField *textField) {
			[[CQSettingsController settingsController] setObject:textField.text forKey:key];
		};

		NSString *autocorrectionType = rowDictionary[CQPSAutocorrectType];
		if ([autocorrectionType isEqualToString:CQPSAutocorrectionTypeNo])
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
		else if ([autocorrectionType isEqualToString:CQPSAutocorrectionTypeYes])
			cell.textField.autocorrectionType = UITextAutocorrectionTypeYes;
		else cell.textField.autocorrectionType = UITextAutocorrectionTypeDefault;

		NSString *autocapitalizationType = rowDictionary[CQPSAutocapitalizationType];
		if ([autocapitalizationType isEqualToString:CQPSAutocapitalizationTypeAllCharacters])
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
		else if ([autocapitalizationType isEqualToString:CQPSAutocapitalizationTypeWords])
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
		else if ([autocapitalizationType isEqualToString:CQPSAutocapitalizationTypeSentences])
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
		else cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;

		cell.textField.secureTextEntry = [rowDictionary[CQPSIsSecure] boolValue];

		NSString *keyboardType = rowDictionary[CQPSKeyboardType];
		if ([keyboardType isEqualToString:CQPSKeyboardTypeEmailAddress])
			cell.textField.keyboardType = UIKeyboardTypeEmailAddress;
		else if ([keyboardType isEqualToString:CQPSKeyboardTypeNumberPad])
			cell.textField.keyboardType = UIKeyboardTypeNumberPad;
		else if ([keyboardType isEqualToString:CQPSKeyboardTypeNumbersAndPunctuation])
			cell.textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
		else if ([keyboardType isEqualToString:CQPSKeyboardTypeURL])
			cell.textField.keyboardType = UIKeyboardTypeURL;
		else cell.textField.keyboardType = UIKeyboardTypeDefault;

		cell.textField.placeholder = rowDictionary[CQPSPlaceholder];

		return cell;
	} else if ([rowDictionary[CQPSType] isEqualToString:CQPSToggleSwitchSpecifier]) {
		CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];
		cell.switchControl.on = [value boolValue];
		cell.textLabel.text = [[NSBundle mainBundle] localizedStringForKey:rowDictionary[CQPSTitle] value:@"" table:nil];
		cell.switchControlBlock = ^(UISwitch *switchControl) {
			[[CQSettingsController settingsController] setBool:switchControl.on forKey:key];
		};

		return cell;
	} else if ([rowDictionary[CQPSType] isEqualToString:CQPSChildPaneSpecifier]) {
		UITableViewCell *cell = [UITableViewCell reusableTableViewCellWithStyle:UITableViewCellStyleValue1 inTableView:tableView];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.detailTextLabel.text = [[NSBundle mainBundle] localizedStringForKey:value value:@"" table:nil];
		cell.textLabel.text = [[NSBundle mainBundle] localizedStringForKey:rowDictionary[CQPSTitle] value:@"" table:nil];

		return cell;
	} else if ([rowDictionary[CQPSType] isEqualToString:CQPSMultiValueSpecifier]) {
		UITableViewCell *cell = [UITableViewCell reusableTableViewCellWithStyle:UITableViewCellStyleValue1 inTableView:tableView];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.textLabel.text = [[NSBundle mainBundle] localizedStringForKey:rowDictionary[CQPSTitle] value:@"" table:nil];

		NSUInteger index = [rowDictionary[CQPSValues] indexOfObject:value];
		cell.detailTextLabel.text = rowDictionary[CQPSTitles][index];

		return cell;
	} else if ([rowDictionary[CQPSType] isEqualToString:CQPSTitleValueSpecifier]) {
		UITableViewCell *cell = [UITableViewCell reusableTableViewCellWithStyle:UITableViewCellStyleValue1 inTableView:tableView];
		if (rowDictionary[CQPSAction])
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		else cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.textLabel.text = [[NSBundle mainBundle] localizedStringForKey:rowDictionary[CQPSTitle] value:@"" table:nil];
		cell.detailTextLabel.text = [[NSBundle mainBundle] localizedStringForKey:value value:@"" table:nil];

		return cell;
	}

	return nil;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	id old = _selectedIndexPath;
	_selectedIndexPath = [indexPath retain];
	[old release];

	UIViewController *viewController = nil;
	NSDictionary *rowDictionary = _preferences[indexPath.section][@"rows"][indexPath.row];
	if ([rowDictionary[CQPSType] isEqualToString:CQPSChildPaneSpecifier]) {
		viewController = [[CQPreferencesDisplayViewController alloc] initWithPlistNamed:rowDictionary[CQPSFile]];
	} else if ([rowDictionary[CQPSType] isEqualToString:CQPSMultiValueSpecifier]) {
		CQPreferencesListViewController *preferencesListViewController = [[CQPreferencesListViewController alloc] init];
		preferencesListViewController.allowEditing = NO;
		preferencesListViewController.items = rowDictionary[CQPSTitles];

		id key = rowDictionary[CQPSKey];
		id value = [[CQSettingsController settingsController] objectForKey:key];
		if (!value)
			value = rowDictionary[CQPSDefaultValue];
		preferencesListViewController.selectedItemIndex = [rowDictionary[CQPSValues] indexOfObject:value];
		preferencesListViewController.preferencesListBlock = ^(CQPreferencesListViewController *editedPreferencesListViewController) {
			id newValue = rowDictionary[CQPSValues][editedPreferencesListViewController.selectedItemIndex];
			[[CQSettingsController settingsController] setObject:newValue forKey:key];
		};

		NSString *listType = rowDictionary[CQPSListType];
		if ([listType isCaseInsensitiveEqualToString:CQPSListTypeAudio])
			preferencesListViewController.listType = CQPreferencesListTypeAudio;
		else if ([listType isCaseInsensitiveEqualToString:CQPSListTypeImage])
			preferencesListViewController.listType = CQPreferencesListTypeImage;
		else if ([listType isCaseInsensitiveEqualToString:CQPSListTypeFont])
			preferencesListViewController.listType = CQPreferencesListTypeFont;
		viewController = preferencesListViewController;
	} else if ([rowDictionary[CQPSType] isEqualToString:CQPSTitleValueSpecifier]) {
		NSString *address = rowDictionary[CQPSAddress];
		if ([rowDictionary[CQPSAction] isEqualToString:CQPSLink])
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:address]];
		else if ([rowDictionary[CQPSAction] isEqualToString:CQPSEmail]) {
			MFMailComposeViewController *mailComposeViewController = [[MFMailComposeViewController alloc] init];
			mailComposeViewController.mailComposeDelegate = self;
			mailComposeViewController.toRecipients = @[address];
			mailComposeViewController.subject = NSLocalizedString(@"Mobile Colloquy Support", @"Mobile Colloquy Support subject header");

			[self.navigationController presentViewController:mailComposeViewController animated:[UIView areAnimationsEnabled] completion:NULL];

			[mailComposeViewController release];
		}

		[tableView deselectRowAtIndexPath:indexPath animated:[UIView areAnimationsEnabled]];
	} else {
		[_selectedIndexPath release];
		_selectedIndexPath = nil;

		return;
	}

	if (viewController) {
		viewController.title = rowDictionary[CQPSTitle];

		[self.navigationController pushViewController:viewController animated:[UIView areAnimationsEnabled]];
	}

	[viewController release];
}

- (void) mailComposeController:(MFMailComposeViewController *) controller didFinishWithResult:(MFMailComposeResult) result error:(NSError *) error {
	[controller dismissViewControllerAnimated:[UIView areAnimationsEnabled] completion:NULL];
}
@end
