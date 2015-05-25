#import "MVChatRoom.h"
#import "MVChatRoomPrivate.h"

@class MVXMPPChatConnection;
@class MVXMPPChatUser;
@class JabberID;

NS_ASSUME_NONNULL_BEGIN

@interface MVXMPPChatRoom : MVChatRoom {
@private
	MVChatUser *_localMemberUser;
}
- (id) initWithJabberID:(JabberID *) identifier andConnection:(MVXMPPChatConnection *) connection;
@end

@interface MVXMPPChatRoom (MVXMPPChatRoomPrivate)
- (void) _setLocalMemberUser:(MVChatUser *) user;
@end

NS_ASSUME_NONNULL_END
