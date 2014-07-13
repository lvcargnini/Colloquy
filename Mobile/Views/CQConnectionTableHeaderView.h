@class MVChatConnection;

typedef enum {
	CQConnectionTableCellNotConnectedStatus,
	CQConnectionTableCellServerDisconnectedStatus,
	CQConnectionTableCellReconnectingStatus,
	CQConnectionTableCellConnectingStatus,
	CQConnectionTableCellConnectedStatus
} CQConnectionTableCellStatus;

@interface CQConnectionTableHeaderView : UITableViewHeaderFooterView {
	@protected
	UIImageView *_iconImageView;
	UIImageView *_badgeImageView;
	UILabel *_serverLabel;
	UILabel *_nicknameLabel;
	UILabel *_timeLabel;
	NSDate *_connectDate;
	CQConnectionTableCellStatus _status;
}
- (void) takeValuesFromConnection:(MVChatConnection *) connection;
- (void) updateConnectTime;

@property (nonatomic, copy) NSString *server;
@property (nonatomic, copy) NSString *nickname;
@property (nonatomic, copy) NSDate *connectDate;
@property (nonatomic) CQConnectionTableCellStatus status;

@property (nonatomic) BOOL editing;
- (void) setEditing:(BOOL) editing animated:(BOOL) animated;

@property (nonatomic) BOOL showingDeleteConfirmation;
@property (nonatomic) BOOL showsReorderControl;
@end
