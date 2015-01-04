typedef NS_OPTIONS(NSUInteger, CQSettingsLocation) {
	CQSettingsLocationDevice = (1 << 0) ,
	CQSettingsLocationCloud = (1 << 1) ,
};

extern NSString *const CQSettingsDidChangeNotification;

@protocol CQSettings <NSObject>
@optional
- (instancetype) init;

- (id) objectForKey:(NSString *) defaultName;
- (void) setObject:(id) value forKey:(NSString *) defaultName;
- (void) removeObjectForKey:(NSString *) defaultName;

- (NSString *) stringForKey:(NSString *) defaultName;
- (NSArray *) arrayForKey:(NSString *) defaultName;
- (NSDictionary *) dictionaryForKey:(NSString *) defaultName;
- (NSData *) dataForKey:(NSString *) defaultName;
- (NSArray *) stringArrayForKey:(NSString *) defaultName;
- (NSInteger) integerForKey:(NSString *) defaultName;
- (float) floatForKey:(NSString *) defaultName;
- (double) doubleForKey:(NSString *) defaultName;
- (BOOL) boolForKey:(NSString *) defaultName;

- (void) setInteger:(NSInteger) value forKey:(NSString *) defaultName;
- (void) setFloat:(float) value forKey:(NSString *) defaultName;
- (void) setDouble:(double) value forKey:(NSString *) defaultName;
- (void) setBool:(BOOL) value forKey:(NSString *) defaultName;

- (void) registerDefaults:(NSDictionary *) registrationDictionary;

- (BOOL) synchronize;
@end

@interface CQSettingsController : NSObject <CQSettings> {
	CQSettingsLocation _settingsLocation;
	BOOL _mirroringEnabled;
}

+ (instancetype) settingsController;

@property (nonatomic) CQSettingsLocation settingsLocation;
@property (nonatomic) BOOL mirroringEnabled; // send to CQSettingsLocationDevice as well, if using CQSettingsLocationCloud

- (void) onLocation:(CQSettingsLocation) location block:(void (^)(id settingsController)) block;
@end

