#import "JVFScriptPluginLoader.h"
#import "JVFScriptConsolePanel.h"
#import "JVFScriptChatPlugin.h"
#import "MVChatConnection.h"
#import "JVChatWindowController.h"

#ifndef __FScript_FSNSObject_H__
#error STOP: You need F-Script installed to build Colloquy. F-Script can be found at: http://www.fscript.org
#endif

@implementation JVFScriptPluginLoader
- (id) initWithManager:(MVChatPluginManager *) manager {
	if( self = [super init] ) {
		_manager = manager;
		_fscriptInstalled = ( NSClassFromString( @"FSInterpreter" ) ? YES : NO );
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	_manager = nil;
	[super dealloc];
}

- (void) displayInstallationWarning {
	NSRunCriticalAlertPanel( NSLocalizedString( @"F-Script Framework Required", "F-Script required error title" ), NSLocalizedString( @"The F-Script framework was not found. The F-Script console and any F-Script plugins will not work during this session. For the latest version of F-Script visit http://www.fscript.org.", "F-Script framework required error message" ), nil, nil, nil );
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view {
	if( view && ! [command caseInsensitiveCompare:@"fscript"] && ! [[arguments string] caseInsensitiveCompare:@"console"] ) {
		if( ! _fscriptInstalled ) {
			[self displayInstallationWarning];
			return YES;
		}

		JVFScriptConsolePanel *console = [[[JVFScriptConsolePanel alloc] init] autorelease];
		[[view windowController] addChatViewController:console];
		[[view windowController] showChatViewController:console];
		return YES;
	} else if( ! [command caseInsensitiveCompare:@"fscript"] ) {
		if( ! _fscriptInstalled ) {
			[self displayInstallationWarning];
			return NO;
		}

		NSString *subcmd = nil;
		NSScanner *scanner = [NSScanner scannerWithString:[arguments string]];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&subcmd];
		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];

		NSString *path = nil;
		[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n\r"] intoString:&path];
		if( ! [path length] ) return YES;

		path = [path stringByStandardizingPath];

		NSEnumerator *enumerator = [_manager enumeratorOfPluginsOfClass:[JVFScriptChatPlugin class] thatRespondToSelector:@selector( init )];
		JVFScriptChatPlugin *plugin = nil;

		while( ( plugin = [enumerator nextObject] ) )
			if( [[plugin scriptFilePath] isEqualToString:path] || [[[[plugin scriptFilePath] lastPathComponent] stringByDeletingPathExtension] isEqualToString:path] )
				break;

		if( ! plugin && ! [subcmd caseInsensitiveCompare:@"load"] ) {
			[self loadPluginNamed:path];
		} else if( ( ! [subcmd caseInsensitiveCompare:@"reload"] || ! [subcmd caseInsensitiveCompare:@"load"] ) && plugin ) {
			[plugin reloadFromDisk];
		} else if( ! [subcmd caseInsensitiveCompare:@"unload"] && plugin ) {
			[_manager removePlugin:plugin];
		} else if( ! [subcmd caseInsensitiveCompare:@"console"] && plugin && view ) {
			JVFScriptConsolePanel *console = [[[JVFScriptConsolePanel alloc] initWithFScriptChatPlugin:plugin] autorelease];
			[[view windowController] addChatViewController:console];
			[[view windowController] showChatViewController:console];
		} else if( ! [subcmd caseInsensitiveCompare:@"edit"] && plugin ) {
			[[NSWorkspace sharedWorkspace] openFile:[plugin scriptFilePath]];
		}

		return YES;
	}

	return NO;
}

- (void) loadPluginNamed:(NSString *) name {
	// Look through the standard plugin paths
	if( ! _manager ) return;
	
	if( ! [name isAbsolutePath] ) {
		NSArray *paths = [[_manager class] pluginSearchPaths];
		NSFileManager *fm = [NSFileManager defaultManager];
		
		NSEnumerator *enumerator = [paths objectEnumerator];
		NSString *path = nil;
		while( path = [enumerator nextObject] ) {
			path = [path stringByAppendingPathComponent:name];
			path = [path stringByAppendingPathExtension:@"fscript"];
			if( [fm fileExistsAtPath:path] ) {
				if( ! _fscriptInstalled ) {
					[self displayInstallationWarning];
					return;
				}
				
				JVFScriptChatPlugin *plugin = [[[JVFScriptChatPlugin alloc] initWithScriptAtPath:path withManager:_manager] autorelease];
				if( plugin ) [_manager addPlugin:plugin];
				return;
			}
		}
	}
	
	JVFScriptChatPlugin *plugin = [[[JVFScriptChatPlugin alloc] initWithScriptAtPath:name withManager:_manager] autorelease];;
	if( plugin ) [_manager addPlugin:plugin];
}

- (void) reloadPlugins {
	if( ! _manager ) return;

	NSArray *paths = [[_manager class] pluginSearchPaths];
	NSString *file = nil, *path = nil;

	NSEnumerator *enumerator = [paths objectEnumerator];
	while( path = [enumerator nextObject] ) {
		NSEnumerator *denumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		while( ( file = [denumerator nextObject] ) ) {
			if( [[file pathExtension] isEqualToString:@"fscript"] ) {
				if( ! _fscriptInstalled ) {
					[self displayInstallationWarning];
					return;
				}

				JVFScriptChatPlugin *plugin = [[[JVFScriptChatPlugin alloc] initWithScriptAtPath:[NSString stringWithFormat:@"%@/%@", path, file] withManager:_manager] autorelease];
				if( plugin ) [_manager addPlugin:plugin];
			}
		}
	}
}

- (void) load {
	[self reloadPlugins];
}
@end
