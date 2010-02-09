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

#import <Foundation/Foundation.h>

//! Represents the notification posted when the current game is changed
#define kGameChangedNotification				@"gamepack.game.changed"
#define kGamePackListUpdatedNotification		@"gamepack.list.updated"
#define kGamePackFavouritesUpdatedNotification	@"gamepack.favourites.updated"

#define GAMES_FOLDER			[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/games"]
#define SHARED_IMAGES_FOLDER	[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/games/images"]

@class GameInfo;

@interface GamePack : NSObject {
@private
	NSArray					*_favouritesList;
	NSMutableSet			*_favouritesSet;
	NSMutableArray			*gameInfoList;
	GameInfo				*currentGame;
	NSString				*_sharedImagesPath;
	NSArray					*_disabledIds;
	
	NSMutableDictionary		*gameInfoPrefs;
}

#pragma mark -
#pragma mark Static Members
+ (GamePack*)globalGamePack;

#pragma mark -
#pragma mark Instance Members
@property (nonatomic, retain)		NSMutableArray		*gameInfoList;
@property (nonatomic, readonly)		GameInfo			*currentGame;
@property (nonatomic, readonly)		NSArray				*favourites;
@property (readonly)				NSString			*sharedImagesPath;

- (GameInfo*)findByGameId:(NSString*)gameId;
- (void)clearCurrentGame;
- (void)addGameInfo:(GameInfo*)newInfo;

- (BOOL)isFavourite:(GameInfo*)gameInfo;
- (void)addFavourite:(GameInfo*)gameInfo;
- (void)removeFavourite:(GameInfo*)gameInfo;

- (void)updateInactiveGamesWithIds:(NSArray*)inactiveIds;

@end

#import "GameInfo.h"
