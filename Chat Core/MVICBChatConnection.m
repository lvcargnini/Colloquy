/*
 * Chat Core
 * ICB Protocol Support
 *
 * Copyright (c) 2006, 2007 Julio M. Merino Vidal <jmmv@NetBSD.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *    1. Redistributions of source code must retain the above
 *       copyright notice, this list of conditions and the following
 *       disclaimer.
 *    2. Redistributions in binary form must reproduce the above
 *       copyright notice, this list of conditions and the following
 *       disclaimer in the documentation and/or other materials
 *       provided with the distribution.
 *    3. The name of the author may not be used to endorse or promote
 *       products derived from this software without specific prior
 *       written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 * GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 * IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
 * IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <stdarg.h>
#import <Foundation/Foundation.h>

#import "MVChatConnectionPrivate.h"
#import "MVChatRoomPrivate.h"
#import "MVChatUserPrivate.h"
#import "MVICBChatConnection.h"
#import "MVICBChatRoom.h"
#import "MVICBChatUser.h"

#import "AsyncSocket.h"
#import "ICBPacket.h"
#import "InterThreadMessaging.h"
#import "NSStringAdditions.h"
#import "NSNotificationAdditions.h"

@interface MVICBChatConnection (MVICBChatConnectionPrivate)
- (void) _connect;
- (void) _startSendQueue;
- (void) _stopSendQueue;
- (void) _sendQueue;
- (void) socket:(AsyncSocket *) sock
         didConnectToHost:(NSString *) host port:(UInt16) port;
- (void) socket:(AsyncSocket *) sock
	     didReadData:(NSData *) data withTag:(long) tag;
- (void) socketDidDisconnect:(AsyncSocket *)sock;
- (void) _writeDataToServer:(id) raw;
- (void) _readNextMessageFromServer;
- (void) _joinChatRoomNamed:(NSString *) name
		 withPassphrase:(NSString *) passphrase
	     alreadyJoined:(BOOL) joined;
@end

#pragma mark -

@implementation MVICBChatConnection

#pragma mark Class accessors

+ (NSArray *) defaultServerPorts {
	id defaultPort = [NSNumber numberWithUnsignedShort:7326];
	return [NSArray arrayWithObjects:defaultPort, nil];
}

#pragma mark Constructors and finalizers

- (id) init {
	if( ( self = [super init] ) ) {
		_username = [NSUserName() retain];
		_nickname = [_username retain];
		_password = @"";
		_server = @"localhost";
		_serverPort = [[[MVICBChatConnection defaultServerPorts]
		                objectAtIndex:0] shortValue];
		_initialChannel = @"1";
		_room = nil;
		_threadWaitLock = [[NSConditionLock alloc] initWithCondition:0];
		_loggedIn = NO;
	}

	return self;
}

- (void) finalize {
	[self disconnect];
	[super finalize];
}

#pragma mark Accessors

- (NSString *) nickname {
	return _nickname;
}

- (NSString *) password {
	return _password;
}

- (NSString *) server {
	return _server;
}

- (unsigned short) serverPort {
	return _serverPort;
}

- (MVChatConnectionType) type {
	return MVChatConnectionICBType;
}

- (NSString *) urlScheme {
	return @"icb";
}

- (NSString *) username {
	return _username;
}

#pragma mark Modifiers

- (void) setAwayStatusMessage:(NSAttributedString *) message {
}

- (void) setNickname:(NSString *) newNickname {
	NSParameterAssert( newNickname );
	NSParameterAssert( [newNickname length] > 0 );

	if( ! [newNickname isEqualToString:_nickname] ) {
		id old = _nickname;
		_nickname = [newNickname copyWithZone:nil];
		[old release];

		if( [self isConnected] )
			[self performSelector:@selector( ctsCommandName: )
			      withObject:_nickname inThread:_connectionThread];
	}
}

- (void) setPassword:(NSString *) newPassword {
	[_password release];

	if( ! newPassword )
		_password = @"";
	else
		_password = [newPassword copyWithZone:nil];
}

- (void) setServer:(NSString *) newServer {
	NSParameterAssert( newServer );
	NSParameterAssert( [newServer length] > 0 );

	id old = _server;
	_server = [newServer copyWithZone:nil];
	[old release];
}

- (void) setServerPort:(unsigned short) port {
	if( port != 0 )
		_serverPort = port;
	else
		_serverPort = [[[MVICBChatConnection defaultServerPorts]
		                objectAtIndex:0] shortValue];
}

- (void) setUsername:(NSString *) newUsername {
	NSParameterAssert( newUsername );
	NSParameterAssert( [newUsername length] > 0 );

	id old = _username;
	_username = [newUsername copyWithZone:nil];
	[old release];
}

#pragma mark Connection handling

- (void) connect {
	if( _status != MVChatConnectionDisconnectedStatus &&
	    _status != MVChatConnectionServerDisconnectedStatus &&
		_status != MVChatConnectionSuspendedStatus )
		return;

	id old = _lastConnectAttempt;
	_lastConnectAttempt = [[NSDate alloc] init];
	[old release];

	_loggedIn = NO;
	[self _willConnect];

	// Spawn the thread to handle the connection to the server.
	[NSThread detachNewThreadSelector:@selector( _runloop )
	          toTarget:self withObject:nil];

	// Wait until the thread has initialized and set _connectionThread
	// to point to itself.
	[_threadWaitLock lockWhenCondition:1];
	[_threadWaitLock unlockWithCondition:0];

	// Start the connection.
	if( _connectionThread )
		[self performSelector:@selector( _connect )
		      inThread:_connectionThread];
}

- (void) disconnectWithReason:(NSAttributedString *) reason {
	[self cancelPendingReconnectAttempts];
	if( _sendQueueProcessing && _connectionThread )
		[self performSelector:@selector( _stopSendQueue )
		      withObject:nil inThread:_connectionThread];

	if( _status == MVChatConnectionConnectedStatus ) {
		[self _willDisconnect];
		[_chatConnection disconnect];
		[self _didDisconnect];
	} else if( _status == MVChatConnectionConnectingStatus ) {
		if( _connectionThread ) {
			[self _willDisconnect];
			[_chatConnection performSelector:@selector( disconnect )
							 inThread:_connectionThread];
			[self _didDisconnect];
		}
	}
}

- (void) sendRawMessage:(id) raw immediately:(BOOL) now {
	NSParameterAssert( raw );
	NSParameterAssert( [raw isKindOfClass:[NSData class]] ||
	                   [raw isKindOfClass:[NSString class]] );

	if( now ) {
		if( _connectionThread )
			[self performSelector:@selector( _writeDataToServer: )
			      withObject:raw inThread:_connectionThread];
	} else {
		if( ! _sendQueue )
			_sendQueue = [[NSMutableArray allocWithZone:nil]
						  initWithCapacity:20];

		@synchronized( _sendQueue ) {
			[_sendQueue addObject:raw];
		}

		if( ! _sendQueueProcessing && _connectionThread )
			[self performSelector:@selector( _startSendQueue )
			      withObject:nil inThread:_connectionThread];
	}
}

#pragma mark Rooms handling

- (MVChatRoom *) chatRoomWithUniqueIdentifier:(id) identifier {
	NSParameterAssert( [identifier isKindOfClass:[NSString class]] );

	MVChatRoom *room;
	@synchronized( _joinedRooms ) {
		room = [self joinedChatRoomWithName:identifier];
		if( !room ) {
			room = [[MVICBChatRoom alloc] initWithName:identifier
										  andConnection:self];
			[self _addJoinedRoom:room];
		}
	}
	return room;
}

- (void) fetchChatRoomList {
}

- (void) joinChatRoomNamed:(NSString *) name
			withPassphrase:(NSString *) passphrase {
	[self _joinChatRoomNamed:name withPassphrase:passphrase alreadyJoined:NO];
}

#pragma mark Users handling

- (NSSet *) chatUsersWithNickname:(NSString *) nickname {
	return [NSSet setWithObject:[self chatUserWithUniqueIdentifier:nickname]];
}

- (MVChatUser *) chatUserWithUniqueIdentifier:(id) identifier {
	NSParameterAssert( [identifier isKindOfClass:[NSString class]] );

	NSString *uniqueIdentfier = [identifier lowercaseString];
	if( [uniqueIdentfier isEqualToString:[_localUser uniqueIdentifier]] )
		return [self localUser];

	if( ! _knownUsers )
		_knownUsers = [[NSMutableDictionary alloc] initWithCapacity:200];

	MVChatUser *user = nil;
	@synchronized( _knownUsers ) {
		user = [_knownUsers objectForKey:uniqueIdentfier];
		if( user )
			return user;

		user = [[MVICBChatUser alloc] initWithNickname:identifier
		                              andConnection:self];
		if( user )
			[_knownUsers setObject:user forKey:uniqueIdentfier];
	}

	return [user autorelease];
}

- (NSSet *) knownChatUsers {
	@synchronized( _knownUsers ) {
		return [NSSet setWithArray:[_knownUsers allValues]];
	} return nil;
}

@end

#pragma mark -

@implementation MVICBChatConnection (MVICBChatConnectionPrivate)

#pragma mark Connection thread

- (oneway void) _runloop {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[_threadWaitLock lockWhenCondition:0];

	if( [_connectionThread respondsToSelector:@selector( cancel )] )
		[_connectionThread cancel];

	_connectionThread = [NSThread currentThread];
	if( [_connectionThread respondsToSelector:@selector( setName: )] )
		[_connectionThread setName:[[self url] absoluteString]];
	[NSThread prepareForInterThreadMessages];

	[_threadWaitLock unlockWithCondition:1];

	if( [pool respondsToSelector:@selector( drain )] )
		[pool drain];
	[pool release];
	pool = nil;

	BOOL active = YES;
	while( active && ( _status == MVChatConnectionConnectedStatus ||
					   _status == MVChatConnectionConnectingStatus ||
					   [_chatConnection isConnected] ) ) {
		pool = [[NSAutoreleasePool alloc] init];
		active = [[NSRunLoop currentRunLoop]
		          runMode:NSDefaultRunLoopMode
				  beforeDate:[NSDate dateWithTimeIntervalSinceNow:5.]];
		if( [pool respondsToSelector:@selector( drain )] )
			[pool drain];
		[pool release];
	}

	pool = [[NSAutoreleasePool alloc] init];

	// Make sure the connection has sent all the delegate calls it
	// has scheduled.
	[[NSRunLoop currentRunLoop]
	 runMode:NSDefaultRunLoopMode
	 beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.]];

	if( [NSThread currentThread] == _connectionThread )
		_connectionThread = nil;

	if( [pool respondsToSelector:@selector( drain )] )
		[pool drain];
	[pool release];
}

- (void) _connect {
	[_chatConnection setDelegate:nil];
	[_chatConnection disconnect];
	[_chatConnection release];

	_chatConnection = [[AsyncSocket alloc] initWithDelegate:self];

	if( ! [_chatConnection connectToHost:[self server]
	                       onPort:[self serverPort]
						   error:NULL] )
		[self _didNotConnect];
}

#pragma mark Outgoing queue management

- (void) _startSendQueue {
	if( ! _sendQueueProcessing ) {
		_sendQueueProcessing = YES;
		[self performSelector:@selector( _sendQueue ) withObject:nil];
	}
}

- (void) _stopSendQueue {
	_sendQueueProcessing = NO;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
	          selector:@selector( _sendQueue ) object:nil];
}

- (void) _sendQueue {
	@synchronized( _sendQueue ) {
		if( ! [_sendQueue count] ) {
			_sendQueueProcessing = NO;
			return;
		}
	}

	NSData *data = nil;
	@synchronized( _sendQueue ) {
		data = [[_sendQueue objectAtIndex:0] retain];
		[_sendQueue removeObjectAtIndex:0];

		if( [_sendQueue count] )
			[self performSelector:@selector( _sendQueue ) withObject:nil];
		else
			_sendQueueProcessing = NO;
	}

	[self _writeDataToServer:data];
	[data release];
}

#pragma mark Packet reading and writing

- (void) _readNextMessageFromServer {
	[_chatConnection readDataToLength:1 withTimeout:-1. tag:0];
}

- (void) _sendPacket:(ICBPacket *) packet immediately:(BOOL) now {
	NSData *data = [[packet rawData] retain];
	[self sendRawMessage:data immediately:now];

	// XXX The message reported should really be raw...
	[[NSNotificationCenter defaultCenter]
	 postNotificationOnMainThreadWithName:MVChatConnectionGotRawMessageNotification
	 object:self
	 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
	                        [[packet description] retain], @"message",
							[NSNumber numberWithBool:YES], @"outbound",
							nil]];
}

- (void) _writeDataToServer:(id) raw {
	NSMutableData *data = nil;
	NSString *string = nil;

	if( [raw isKindOfClass:[NSMutableData class]] ) {
		data = [raw retain];
		string = [[NSString allocWithZone:nil]
		          initWithData:data encoding:[self encoding]];
	} else if( [raw isKindOfClass:[NSData class]] ) {
		data = [raw mutableCopyWithZone:nil];
		string = [[NSString allocWithZone:nil]
				  initWithData:data encoding:[self encoding]];
	} else if( [raw isKindOfClass:[NSString class]] ) {
		data = [[raw dataUsingEncoding:[self encoding]
		             allowLossyConversion:YES] mutableCopyWithZone:nil];
		string = [raw retain];
	}

	[_chatConnection writeData:data withTimeout:-1. tag:0];

	[string release];
	[data release];
}

#pragma mark AsyncSocket notifications

- (void) socket:(AsyncSocket *) sock
         didConnectToHost:(NSString *) host port:(UInt16) port {
	[self ctsLoginPacket];
	[self _readNextMessageFromServer];
}

- (void) socket:(AsyncSocket *) sock
         didReadData:(NSData *) data withTag:(long) tag {
	if( tag == 0 ) {
		NSAssert( [data length] == 1, @"read mismatch" );
		unsigned int len = (unsigned int)
			(((const char *)[data bytes])[0]) & 0xFF;
		if( len == 0 )
			[_chatConnection readDataToLength:1 withTimeout:-1. tag:0];
		else
			[_chatConnection readDataToLength:len withTimeout:-1. tag:1];
	} else {
		ICBPacket *packet = [[ICBPacket alloc] initFromRawData:data];
		[self stcDemux:packet];
		[packet release];
		[self _readNextMessageFromServer];
	}
}

- (void) socketDidDisconnect:(AsyncSocket *) sock {
	[self _didDisconnect];
}

#pragma mark Error handling

- (void) _postProtocolError:(NSString *) reason {
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	[userInfo setObject:reason forKey:@"reason"];
	NSError *error = [NSError errorWithDomain:MVChatConnectionErrorDomain
	                          code:MVChatConnectionProtocolError
							  userInfo:userInfo];
	[self performSelectorOnMainThread:@selector( _postError: )
		  withObject:error waitUntilDone:NO];
}

#pragma mark Rooms handling

- (void) _joinChatRoomNamed:(NSString *) name
		 withPassphrase:(NSString *) passphrase
		 alreadyJoined:(BOOL) joined {
	if( [name compare:[_room name]] != 0 ) {
		MVICBChatRoom *oldroom = _room;

		_room = (MVICBChatRoom *)[self chatRoomWithUniqueIdentifier:name];
		[_room _addMemberUser:_localUser];
		if( !joined )
			[self ctsCommandGroup:[name retain]];

		[_room _setDateJoined:[NSDate date]];
		[_room _setDateParted:nil];
		[_room _clearMemberUsers];
		[_room _clearBannedUsers];

		[[NSNotificationCenter defaultCenter]
		 postNotificationOnMainThreadWithName:MVChatRoomJoinedNotification
		 object:_room];

		[self ctsCommandTopic];
		[self ctsCommandWho:name];

		if( !joined && [name compare:@"ICB"] != 0 ) {
			[[NSNotificationCenter defaultCenter]
			 postNotificationOnMainThreadWithName:MVChatRoomPartedNotification
		     object:oldroom];
			 [oldroom release];
		}
	}
}

@end

#pragma mark -

@implementation MVICBChatConnection (MVICBChatConnectionProtocolHandlers)

#pragma mark Client to server

- (void) ctsCommandGroup:(NSString *) name {
	ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'h'];
	[packet addFields:@"g", name, nil];
	[self _sendPacket:packet immediately:NO];
	[packet release];
}

- (void) ctsCommandName:(NSString *) name {
	ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'h'];
	[packet addFields:@"name", name, nil];
	[self _sendPacket:packet immediately:NO];
	[packet release];
}

- (void) ctsCommandPersonal:(NSString *) who
         withMessage:(NSString *) message {
	NSParameterAssert( message );
	NSParameterAssert( who );

	size_t maxlen = 250 - [who length];

	do {
		NSString *part;
		if( [message length] < maxlen ) {
			part = message;
			message = nil;
		} else {
			part = [message substringToIndex:maxlen - 1];
			message = [message substringFromIndex:maxlen - 1];
		}

		ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'h'];
		NSString *cmd = [NSString stringWithFormat:@"%@ %@", who, part];
		[packet addFields:@"m", cmd, nil];
		[self _sendPacket:packet immediately:NO];
		[packet release];
	} while( message );
}

- (void) ctsCommandTopic {
	ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'h'];
	[packet addFields:@"topic", @"", nil];
	[self _sendPacket:packet immediately:NO];
	[packet release];
}

- (void) ctsCommandTopicSet:(NSString *) topic {
	ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'h'];
	[packet addFields:@"topic", topic, nil];
	[self _sendPacket:packet immediately:NO];
	[packet release];
}

- (void) ctsCommandWho:(NSString *) group {
	ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'h'];
	[packet addFields:@"w", group, nil];
	[self _sendPacket:packet immediately:NO];
	[packet release];
}

- (void) ctsLoginPacket {
	ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'a'];
	[packet addFields:_username, _nickname, _initialChannel,
	                  @"login", _password, @"", @"", nil];
	[self _sendPacket:packet immediately:NO];
	[packet release];
}

- (void) ctsOpenPacket:(NSString *) message {
	NSParameterAssert( message );

	do {
		NSString *part;
		if( [message length] < 255 ) {
			part = message;
			message = nil;
		} else {
			part = [message substringToIndex:254];
			message = [message substringFromIndex:254];
		}

		ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'b'];
		[packet addFields:part, nil];
		[self _sendPacket:packet immediately:NO];
		[packet release];
	} while( message );
}

- (void) ctsPongPacket {
	ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'m'];
	[self _sendPacket:packet immediately:NO];
	[packet release];
}

- (void) ctsPongPacketWithId:(NSString *) ident {
	ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'m'];
	[packet addFields:ident, nil];
	[self _sendPacket:packet immediately:NO];
	[packet release];
}

#pragma mark Server to client

- (void) stcDemux:(ICBPacket *) packet {
	static const struct info {
		char type;
		NSString *selector;
		int minfields;
		int maxfields;
	} info[] = {
		{ 'a',  @"stcLoginPacket:",         0,  0 },
		{ 'b',  @"stcOpenPacket:",          2,  2 },
		{ 'c',  @"stcPersonalPacket:",      2,  2 },
		{ 'd',  @"stcStatusPacket:",        2,  2 },
		{ 'e',  @"stcErrorPacket:",         1,  1 },
		{ 'f',  @"stcImportantPacket:",     2,  2 },
		{ 'g',  @"stcExitPacket:",          0,  0 },
		{ 'i',  @"stcCommandOutputPacket:", 1, -1 },
		{ 'j',  @"stcProtocolPacket:",      1,  3 },
		{ 'k',  @"stcBeepPacket:",          1,  1 },
		{ 'l',  @"stcPingPacket:",          0,  1 },
		{ 'm',  @"stcPongPacket:",          0,  1 },
		{ '\0', nil,                        0,  0 }
	};

	// XXX The message reported should really be raw...
	[[NSNotificationCenter defaultCenter]
	 postNotificationOnMainThreadWithName:MVChatConnectionGotRawMessageNotification
	 object:self
	 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
	                        [[packet description] retain], @"message",
							[NSNumber numberWithBool:NO], @"outbound",
							nil]];

	const struct info *i = &info[0];
	while( i->type != '\0' ) {
		if( i->type == [packet type] ) {
			NSArray *fields = [packet fields];
			int count = (int)[fields count];

			if( count < i->minfields || ( i->maxfields != -1 &&
										  count > i->maxfields ) ) {
				[self _postProtocolError:[NSString stringWithFormat:@"Received a "
					"packet of type \"%c\" with an incorrect number of fields.",
					[packet type]]];
			} else {
				SEL selector = NSSelectorFromString(i->selector);
				[self performSelector:selector withObject:fields];
				break;
			}
		}
		i++;
	}

	if( i->type == '\0' )
		[self _postProtocolError:[NSString stringWithFormat:@"Received an "
		      "ICB packet with unknown type (%c).",
			  [packet type]]];
}

- (void) stcBeepPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( [fields count] == 1 );

	NSString *who = [fields objectAtIndex:0];

	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
	                          [self chatUserWithUniqueIdentifier:who], @"user",
							  [NSString locallyUniqueString], @"identifier",
							  nil];
	[[NSNotificationCenter defaultCenter]
	 postNotificationOnMainThreadWithName:MVChatConnectionGotBeepNotification
	 object:self userInfo:userInfo];
}

- (void) stcCommandOutputPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( [fields count] >= 1 );

	NSString *type = [fields objectAtIndex:0];
	NSString *selname = [NSString stringWithFormat:@"stcCommandOutputPacket%@:",
	                                               [type uppercaseString]];
	SEL selector = NSSelectorFromString(selname);
	if( [self respondsToSelector:selector] )
		[self performSelector:selector withObject:fields];
	else
		[self _postProtocolError:[NSString stringWithFormat:@"Received a "
		      "command output packet with unknown type (%@).", type]];
}

- (void) stcCommandOutputPacketCO:(NSArray *) fields {
	NSString *message = [fields objectAtIndex:1];
	if( [message hasPrefix:@"The topic is: "] ) {
		[_room _setTopic:[[message substringFromIndex:14]
		                  dataUsingEncoding:[self encoding]]];
		[[NSNotificationCenter defaultCenter]
		 postNotificationOnMainThreadWithName:MVChatRoomTopicChangedNotification
		 object:_room userInfo:nil];
	} else {
		[[NSNotificationCenter defaultCenter]
		 postNotificationOnMainThreadWithName:MVChatConnectionGotInformationalMessageNotification
		 object:self
		 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
	                            [message retain], @"message",
								nil]];
	}
}

- (void) stcCommandOutputPacketWH:(NSArray *) fields {
}

- (void) stcCommandOutputPacketWL:(NSArray *) fields {
	MVChatUser *who = [self chatUserWithUniqueIdentifier:[fields objectAtIndex:2]];
	[_room _addMemberUser:who];
	[[NSNotificationCenter defaultCenter]
	 postNotificationOnMainThreadWithName:MVChatRoomMemberUsersSyncedNotification
	 object:_room
	 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObject:who], @"added", nil]];
}

- (void) stcExitPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( [fields count] == 0 );

	[self performSelectorOnMainThread:@selector( disconnect )
          withObject:nil waitUntilDone:NO];
}

- (void) stcErrorPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( [fields count] == 1 );

	NSString *message = [fields objectAtIndex:0];

	if( [message compare:@"Open messages not permitted in quiet groups."] == 0 ) {
		NSError *error = [NSError errorWithDomain:MVChatConnectionErrorDomain
					 			  code:MVChatConnectionCantSendToRoomError
								  userInfo:[NSDictionary dictionaryWithObjectsAndKeys:_room, @"room", nil]];
		[self performSelectorOnMainThread:@selector( _postError: )
			  withObject:error waitUntilDone:NO];
	} else if( [message compare:@"Nickname already in use."] == 0 ) {
		if( _loggedIn ) {
			// XXX
		} else {
			NSError *error = [NSError errorWithDomain:MVChatConnectionErrorDomain
									  code:MVChatConnectionErroneusNicknameError
									  userInfo:[NSDictionary dictionaryWithObjectsAndKeys:_nickname, @"nickname", nil]];
			[self performSelectorOnMainThread:@selector( _postError: )
				  withObject:error waitUntilDone:NO];

			// The server will probably send us an exit packet, but let's be
			// sure to disconnect ourselves.
			[self performSelectorOnMainThread:@selector( disconnect )
		          withObject:nil waitUntilDone:NO];
		}
	} else if( [message compare:@"You aren't the moderator."] == 0 ) {
		// XXX
	} else
		[self _postProtocolError:[NSString stringWithFormat:@"Received an "
		      "unhandled error packet: %@", [fields objectAtIndex:0]]];
}

- (void) stcImportantPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( [fields count] == 2 );

	NSString *category = [fields objectAtIndex:0];
	NSString *text = [fields objectAtIndex:1];
	NSString *message = [NSString stringWithFormat:@"%@, %@",
						 category, text];

	[[NSNotificationCenter defaultCenter]
	 postNotificationOnMainThreadWithName:MVChatConnectionGotImportantMessageNotification
	 object:self
	 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                            [message retain], @"message",
							nil]];
}

- (void) stcLoginPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( [fields count] == 0 );

	[self performSelectorOnMainThread:@selector( _didConnect )
		  withObject:nil waitUntilDone:NO];

	_loggedIn = YES;

	[_localUser release];
	_localUser = [[MVICBChatUser alloc] initLocalUserWithConnection:self];
	[self _markUserAsOnline:_localUser];

	[_room release];
	_room = (MVICBChatRoom *)[self chatRoomWithUniqueIdentifier:_initialChannel];
	[_room _setDateJoined:[NSDate date]];
	[_room _setDateParted:nil];
	[_room _clearMemberUsers];
	[_room _clearBannedUsers];

	[_room _addMemberUser:_localUser];
	[self ctsCommandTopic];
	[self ctsCommandWho:[_room name]];
	[[NSNotificationCenter defaultCenter]
	 postNotificationOnMainThreadWithName:MVChatRoomJoinedNotification
	 object:_room];
}

- (void) stcOpenPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( [fields count] == 2 );

	NSString *who = [fields objectAtIndex:0];
	NSString *msg = [fields objectAtIndex:1];

	MVChatUser *user = [self chatUserWithUniqueIdentifier:who];
	[user _setIdleTime:0.];

	NSData *msgdata = [NSData dataWithBytes:[msg cString] length:[msg length]];

	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
	                          user, @"user",
							  msgdata, @"message",
							  [NSString locallyUniqueString], @"identifier",
							  nil];
	[[NSNotificationCenter defaultCenter]
	 postNotificationOnMainThreadWithName:MVChatRoomGotMessageNotification
	 object:_room userInfo:userInfo];
}

- (void) stcPersonalPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( [fields count] == 2 );

	NSString *who = [fields objectAtIndex:0];
	NSString *msg = [fields objectAtIndex:1];

	MVChatUser *user = [self chatUserWithUniqueIdentifier:who];
	NSData *msgdata = [NSData dataWithBytes:[msg cString] length:[msg length]];

	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
	                          msgdata, @"message",
							  [NSString locallyUniqueString], @"identifier",
							  nil];
	[[NSNotificationCenter defaultCenter]
	 postNotificationOnMainThreadWithName:MVChatConnectionGotPrivateMessageNotification
	 object:user userInfo:userInfo];
}

- (void) stcPingPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( [fields count] <= 1 );

	if( [fields count] == 1 ) {
		NSString *ident = [fields objectAtIndex:0];
		[self ctsPongPacketWithId:ident];
	} else
		[self ctsPongPacket];
}

- (void) stcPongPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( [fields count] <= 1 );
}

- (void) stcProtocolPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( [fields count] >= 1 && [fields count] <= 3 );
}

- (void) stcStatusPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( [fields count] == 2 );

	NSString *category = [fields objectAtIndex:0];

	NSMutableString *tmp = [NSMutableString stringWithCapacity:[category length]];
	[tmp setString:category];
	[tmp replaceOccurrencesOfString:@"-" withString:@""
	     options:NSLiteralSearch range:NSMakeRange(0, [category length])];
	NSString *selname = [NSString stringWithFormat:@"stcStatusPacket%@:", tmp];

	SEL selector = NSSelectorFromString(selname);
	if( [self respondsToSelector:selector] )
		[self performSelector:selector withObject:fields];
	else
		[self _postProtocolError:[NSString stringWithFormat:@"Received a "
		      "status message with an unsupported category (%@).",
			  category]];
}

- (void) stcStatusPacketArrive:(NSArray *) fields {
	NSString *msg = [fields objectAtIndex:1];

	NSArray *words = [msg componentsSeparatedByString:@" "];
	MVChatUser *sender = [self chatUserWithUniqueIdentifier:[words objectAtIndex:0]];
	[sender _setIdleTime:0.];
	[_room _addMemberUser:sender];
	[[NSNotificationCenter defaultCenter]
	 postNotificationOnMainThreadWithName:MVChatRoomUserJoinedNotification
	 object:_room
	 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", nil]];
}

- (void) stcStatusPacketBoot:(NSArray *) fields {
	NSString *msg = [fields objectAtIndex:1];

	NSRange r;

	r = [msg rangeOfString:@" was auto-booted "];
	if( r.location != NSNotFound ) {
		MVChatUser *who = [self chatUserWithUniqueIdentifier:
			                    [msg substringToIndex:r.location]];
		MVChatUser *server = [self chatUserWithUniqueIdentifier:@"server"];
		NSData *reason = [@"Spamming" dataUsingEncoding:_encoding];

		if( [who isLocalUser] ) {
			[_room _setDateParted:[NSDate date]];
			[[NSNotificationCenter defaultCenter]
			 postNotificationOnMainThreadWithName:MVChatRoomKickedNotification
			 object:_room
			 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:reason, @"reason",
			                                                     server, @"byUser", nil]];
		} else {
			[_room _removeMemberUser:who];
			[[NSNotificationCenter defaultCenter]
			 postNotificationOnMainThreadWithName:MVChatRoomUserKickedNotification
			 object:_room
			 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:reason, @"reason",
				                                                 server, @"byUser",
																 who, @"user", nil]];
		}
	}
}

- (void) stcStatusPacketDepart:(NSArray *) fields {
	NSString *msg = [fields objectAtIndex:1];

	NSArray *words = [msg componentsSeparatedByString:@" "];
	MVChatUser *sender = [self chatUserWithUniqueIdentifier:[words objectAtIndex:0]];
	[_room _removeMemberUser:sender];
	[[NSNotificationCenter defaultCenter]
	 postNotificationOnMainThreadWithName:MVChatRoomUserPartedNotification
	 object:_room
	 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", nil]];
}

- (void) stcStatusPacketNoPass:(NSArray *) fields {
}

- (void) stcStatusPacketSignoff:(NSArray *) fields {
	NSString *msg = [fields objectAtIndex:1];

	NSArray *words = [msg componentsSeparatedByString:@" "];
	MVChatUser *sender = [self chatUserWithUniqueIdentifier:[words objectAtIndex:0]];
	[_room _removeMemberUser:sender];
	[[NSNotificationCenter defaultCenter]
	 postNotificationOnMainThreadWithName:MVChatRoomUserPartedNotification
	 object:_room
	 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", nil]];
}

- (void) stcStatusPacketSignon:(NSArray *) fields {
	NSString *msg = [fields objectAtIndex:1];

	NSArray *words = [msg componentsSeparatedByString:@" "];
	MVChatUser *sender = [self chatUserWithUniqueIdentifier:[words objectAtIndex:0]];
	[sender _setIdleTime:0.];
	[_room _addMemberUser:sender];
	[[NSNotificationCenter defaultCenter]
	 postNotificationOnMainThreadWithName:MVChatRoomUserJoinedNotification
	 object:_room
	 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", nil]];
}

- (void) stcStatusPacketStatus:(NSArray *) fields {
	NSString *msg = [fields objectAtIndex:1];

	NSRange r;

	r = [msg rangeOfString:@"You are now in group "];
	if( r.location == 0 ) {
		NSString *name;

		NSString *part = [msg substringFromIndex:r.length];
		r = [part rangeOfString:@" as moderator"];
		if( r.location != NSNotFound )
			name = [part substringToIndex:r.location];
		else
			name = part;

		[name retain]; // XXX Needed to avoid a crash, but may cause a leak...
		[self _joinChatRoomNamed:name withPassphrase:nil alreadyJoined:YES];
	}
}

- (void) stcStatusPacketTopic:(NSArray *) fields {
	NSString *msg = [fields objectAtIndex:1];

	NSRange r;

	r = [msg rangeOfString:@" changed the topic to "];
	if( r.location != NSNotFound ) {
		MVChatUser *sender =
		    [self chatUserWithUniqueIdentifier:[msg substringToIndex:r.location]];
		NSString *topic = [msg substringFromIndex:r.location + r.length];
		unsigned int l = [topic length];
		if( l < 2 || ( [topic characterAtIndex:0] != '"' ||
			           [topic characterAtIndex:l - 1] != '"' ) ) {
			[self _postProtocolError:@"Received an invalid topic"];
		} else {
			[_room _setTopic:[[topic substringWithRange:NSMakeRange(1, l - 2)]
			       dataUsingEncoding:[self encoding]]];
			[_room _setTopicAuthor:sender];
			[_room _setTopicDate:[NSDate date]];
			[[NSNotificationCenter defaultCenter]
			 postNotificationOnMainThreadWithName:MVChatRoomTopicChangedNotification
			 object:_room userInfo:nil];
		}
	}
}

@end
