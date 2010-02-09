/*
 Frodo, Commodore 64 emulator for the iPhone
 Copyright (C) 2007-2010 Stuart Carnie
 See gpl.txt for license information.
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "GameInstaller.h"
#import "GamePack.h"
#import "CocoaUtility.h"
#import "EncryptDecrypt.h"
#import "GameZipExtracter.h"

@implementation GameInstaller

+ (void)copyImages:(NSString*)srcPath dstPath:(NSString*)dstPath {
	NSFileManager	*mgr = [NSFileManager defaultManager];
	NSError			*error;
	if ([mgr fileExistsAtPath:dstPath]) {
		NSArray *files = [mgr contentsOfDirectoryAtPath:srcPath error:nil];
		for (NSString *file in files) {
			NSString *dstFile = [dstPath stringByAppendingPathComponent:file];
			[mgr removeItemAtPath:dstFile error:nil];
			[mgr copyItemAtPath:[srcPath stringByAppendingPathComponent:file] toPath:dstFile error:&error];
		}
	} else {
		BOOL result = [mgr copyItemAtPath:srcPath toPath:dstPath error:&error];
		if (!result) {
			NSLog(@"Unable to move images, %@", error);
		}
	}
}

+ (BOOL)installPackWithData:(NSData*)data andSignature:(NSData*)signature andProgressDelegate:(id<MMProgressReport>)delegate {
	NSAutoreleasePool *localPool = [[NSAutoreleasePool alloc] init];
	@try {
		GameZipExtracter *ext = [[[GameZipExtracter alloc] initWithData:data andSignature:signature] autorelease];
		if (!ext) {
			return NO;
		}
		
		NSFileManager *mgr = [NSFileManager defaultManager];
		
		// ensure games folder
		if (![mgr fileExistsAtPath:GAMES_FOLDER]) {
			[mgr createDirectoryAtPath:GAMES_FOLDER attributes:nil];
		}
		
		// install images
		NSString	*imagesPath = [[GamePack globalGamePack] sharedImagesPath];
		[GameInstaller copyImages:[ext.basePath stringByAppendingPathComponent:@"images"] dstPath:imagesPath];
		
		// install games
		float increment = 1.0 / [ext.packs count];
		float currentProgress = 0.0f;
		for (NSString *key in ext.packs) {
			currentProgress += increment;
			[delegate setProgress:currentProgress];
			
			NSArray		*files = [ext.packs objectForKey:key];
			NSString	*gameInfoFile = [ext findFileNamed:@"gameInfo.plist" inArray:files];
			if (gameInfoFile == nil) {
				NSLog(@"Incorrect install archive, missing gameInfo.plist");
				continue;
			}
			GameInfo	*newInfo = [[[GameInfo alloc] initWithContentsOfGameInfoFile:gameInfoFile isBundlePath:NO] autorelease];
			NSLog(@"Installing game, id='%@'", newInfo.gameId);
			[delegate setMessage:[NSString stringWithFormat:@"Enabling %@", newInfo.gameTitle]];
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 25.0 / 1000.0, false);
			
			GameInfo	*existingInfo = [[GamePack globalGamePack] findByGameId:newInfo.gameId];
			
			// TODO: Need to change to a prompt to allow option to override all games
			// game is already installed or is a newer version
			//if (existingInfo && newInfo.version <= existingInfo.version) {
			//	NSLog(@"A newer version of the archive is already installed, skipping");
			//	continue;
			//}
			
			if (existingInfo) {
				[existingInfo uninstall];
			}
			
			NSString	*installPath = [GAMES_FOLDER stringByAppendingPathComponent:newInfo.gameId];			
			NSError		*error;
			BOOL result = [mgr copyItemAtPath:newInfo.basePath toPath:installPath error:&error];
			
			if (!result) {
				NSLog(@"Unable to move install archive, %@", error);
				return NO;
			}
			
			newInfo.basePath = installPath;
			[[GamePack globalGamePack] addGameInfo:newInfo];
		}
	} @finally {
		[localPool release];
	}
	return YES;
}

@end
