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

#import "GamePack.h"
#import "GameDisabledList.h"

#import <CommonCrypto/CommonHMAC.h>

GamePack	*g_GamePack;

#import "GamePack+Private.h"

@implementation GamePack

@synthesize gameInfoList, currentGame, sharedImagesPath=_sharedImagesPath, disabledIds=_disabledIds, gameInfoPrefs;

- (id)init {
	self = [super init];
	
	self.disabledIds = [[GameDisabledList defaultList] getDisabledIdsWithBlock:^(NSArray *ids) {
		self.disabledIds = ids;
		[self loadGames];
		[self notifyGamePackUpdated];
	}];

	[self loadGames];
	
	_sharedImagesPath = [SHARED_IMAGES_FOLDER retain];
		
	return self;
}

- (void)notifyGamePackUpdated {
	[[NSNotificationCenter defaultCenter] postNotificationName:kGamePackListUpdatedNotification object:nil];
}

- (void)loadGames {
	self.gameInfoList = [[NSMutableArray alloc] init];
	
	NSString *bundleGames = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"games"];
	
	// Will revert to dynamic loading once in-app purchases is implemented and games are signed.
	[self loadGameInfosAtPath:bundleGames isBundlePath:YES];
	[self loadGameInfosAtPath:GAMES_FOLDER isBundlePath:NO];	
}

#define GAME_ENTRY(basePath, image, md5) [NSArray arrayWithObjects:@basePath "gameInfo.plist", @basePath image, md5, nil]

- (void)loadFixedBundledGameInfos:(NSString*)path {
	NSArray *gameList = [NSArray arrayWithObjects:GAME_ENTRY("Arctic Shipwreck/", "ARCTICSW.T64", @"727990fe9b25a80147b4360ca398ca91"),
						 GAME_ENTRY("DragonsDen/", "DRAGONSD.D64", @"289e5a0122fa6b1f02d868eeda6b43f8"),
						 GAME_ENTRY("International Basketball/", "International Basketball.T64", @"ef52f3ab96c489e72b70f34b22863271"),
						 GAME_ENTRY("International Soccer/", "International Soccer.t64", @"9630ff8b6d24fde84fc3757efda62317"),
						 GAME_ENTRY("International Tennis/", "International Tennis.T64", @"20c6d1f52f63423aa1e78c60a16e491f"),
						 GAME_ENTRY("Jack Attack/", "Jack Attack.t64", @"4b9c9e28ded01bc706a84c2a263e2c6f"),
						 GAME_ENTRY("jupiterlander/", "Jupiter Lander.d64", @"5551159df0dca4e648ef42527376232a"),
						 GAME_ENTRY("lemans/", "lemans.t64", @"de976ee01511e273069746cacce26224"),
						 nil];
	
	for (NSArray *gameData in gameList) {
		NSString *imagePath = [path stringByAppendingPathComponent:[gameData objectAtIndex:1]];
		NSData *data = [NSData dataWithContentsOfFile:imagePath];
		unsigned char md5_result[CC_MD5_DIGEST_LENGTH];
		CC_MD5([data bytes], [data length], md5_result);
		
		NSString *md5_str = [NSString stringWithFormat: @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
							 md5_result[0], md5_result[1],
							 md5_result[2], md5_result[3],
							 md5_result[4], md5_result[5],
							 md5_result[6], md5_result[7],
							 md5_result[8], md5_result[9],
							 md5_result[10], md5_result[11],
							 md5_result[12], md5_result[13],
							 md5_result[14], md5_result[15]];
		
		if ([md5_str compare:[gameData objectAtIndex:2] options:NSCaseInsensitiveSearch] != 0)
			continue;
		
		NSString *file = [gameData objectAtIndex:0];
		
		GameInfo *info = [[GameInfo alloc] initWithContentsOfGameInfoFile:[path stringByAppendingPathComponent:file] isBundlePath:YES];
		[gameInfoList addObject:info];
		[info release];
	}
}

- (void)loadGameInfosAtPath:(NSString*)path isBundlePath:(BOOL)isBundlePath {
	NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:path];
	NSString *file;
	while (file = [dirEnum nextObject]) {
		NSString *fileName = [file lastPathComponent];
		if (![fileName isEqualToString:@"gameInfo.plist"])
			continue;
		
		GameInfo *info = [[GameInfo alloc] initWithContentsOfGameInfoFile:[path stringByAppendingPathComponent:file] isBundlePath:isBundlePath];
		if (![self.disabledIds containsObject:info.gameId])
			[gameInfoList addObject:info];
		
		[info release];
		[dirEnum skipDescendents];
	}
}

- (GameInfo*)findByGameId:(NSString*)gameId {
	for (GameInfo *info in self.gameInfoList) {
		if ([info.gameId isEqual:gameId])
			return info;
	}
	
	return nil;
}

- (void)removeGameInfo:(GameInfo*)infoToRemove {
	[gameInfoList removeObject:infoToRemove];
	[self notifyGamePackUpdated];
}

- (void)addGameInfo:(GameInfo*)newInfo {
	[gameInfoList addObject:newInfo];
	[self notifyGamePackUpdated];
}

- (void)setCurrentGame:(GameInfo*)info {
	if (currentGame)
		[currentGame release];
	currentGame = [info retain];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kGameChangedNotification object:nil];
}

- (void)clearCurrentGame {
	[self setCurrentGame:nil];
}

#pragma mark -
#pragma mark GameInfo preferences

#define kGameInfoPrefsFileName		[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/gameInfoPrefs.plist"]

- (NSMutableDictionary*)gameInfoPrefs {
	if (!gameInfoPrefs) {
		self.gameInfoPrefs = [NSMutableDictionary dictionaryWithContentsOfFile:kGameInfoPrefsFileName];
		if (!gameInfoPrefs)
			self.gameInfoPrefs = [NSMutableDictionary dictionary];
	}
	
	return gameInfoPrefs;
}

- (id)getValue:(NSString*)key forGameId:(NSString*)gameId {
	NSDictionary* gamePrefs = [self.gameInfoPrefs objectForKey:gameId];
	if (!gamePrefs) return nil;
	
	return [gamePrefs objectForKey:key];
}

- (void)setValue:value forKey:(NSString*)key forGameId:(NSString*)gameId {
	NSDictionary* gamePrefs = [self.gameInfoPrefs objectForKey:gameId];
	if (!gamePrefs) {
		gamePrefs = [NSMutableDictionary dictionary];
		[self.gameInfoPrefs setObject:gamePrefs forKey:gameId];
	}
	
	[gamePrefs setValue:value forKey:key];
	
	NSData* data = [NSPropertyListSerialization dataFromPropertyList:gameInfoPrefs format:NSPropertyListBinaryFormat_v1_0 errorDescription:nil];
	[data writeToFile:kGameInfoPrefsFileName atomically:YES];
	
	//[gameInfoPrefs writeToFile:kGameInfoPrefsFileName atomically:YES];
}

#pragma mark -
#pragma mark Favourites Management

- (NSArray*)favourites {
	if (!_favouritesSet) {
		[self loadFavouritesList];
	}
	
	return _favouritesList;
}

#define kFavouritesFileName		[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/favourites.txt"]

- (void)loadFavouritesList {
	_favouritesSet = [[NSMutableSet alloc] init];
	if ([[NSFileManager defaultManager] fileExistsAtPath:kFavouritesFileName]) {
		NSArray *favs = [NSArray arrayWithContentsOfFile:kFavouritesFileName];
		for (NSString *gameId in favs) {
			[_favouritesSet addObject:[self findByGameId:gameId]];
		}
	}
	_favouritesList = [[[_favouritesSet allObjects] sortedArrayUsingSelector:@selector(compare:)] retain];
}

- (BOOL)isFavourite:(GameInfo*)gameInfo {
	return [_favouritesSet containsObject:gameInfo];
}


- (void)saveFavouritesList {
	NSMutableArray *favs = [[NSMutableArray alloc] initWithCapacity:_favouritesSet.count];
	for(GameInfo *info in _favouritesSet) {
		[favs addObject:info.gameId];
	}
	
	
	
	[favs writeToFile:kFavouritesFileName atomically:YES];
	[favs release];
	[_favouritesList release];
	_favouritesList = [[[_favouritesSet allObjects] sortedArrayUsingSelector:@selector(compare:)] retain];
}

- (void)addFavourite:(GameInfo*)gameInfo {
	if (!_favouritesSet) {
		[self loadFavouritesList];
	}
	
	[_favouritesSet addObject:gameInfo];
	[self saveFavouritesList];
	[[NSNotificationCenter defaultCenter] postNotificationName:kGamePackFavouritesUpdatedNotification object:nil];
}

- (void)removeFavourite:(GameInfo*)gameInfo {
	if (!_favouritesSet) {
		[self loadFavouritesList];
	}
	
	[_favouritesSet removeObject:gameInfo];
	[self saveFavouritesList];
	[[NSNotificationCenter defaultCenter] postNotificationName:kGamePackFavouritesUpdatedNotification object:nil];
}

#pragma mark -
#pragma mark Inactive Titles
- (void)updateInactiveGamesWithIds:(NSArray*)inactiveIds {
	
	// NSMutableSet* newIds = [NSMutableSet setWithArray:inactiveIds];
	for (NSString* gameId in inactiveIds) {
		GameInfo* info = [self findByGameId:gameId];
		[self removeGameInfo:info];
	}
}

#pragma mark -
#pragma mark Static Members

+ (GamePack*)globalGamePack {
	if (!g_GamePack) {
		g_GamePack = [[GamePack alloc] init];
	}
	
	return g_GamePack;
}

@end
