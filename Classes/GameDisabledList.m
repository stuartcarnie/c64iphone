/*
 Frodo, Commodore 64 emulator for the iPhone
 Copyright (C)	
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


#import "GameDisabledList.h"
#import "MMProductStatusRequest.h"

static GameDisabledList* g_gameIgnoreList = nil;

#define INACTIVE_GAMES_FILE		[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/inactiveGames.plist"]

#define kSecondsIn24Hours				60*60*24
#define kSettingLastDisabledIdsCheck	@"c64.lastDisabledIdsCheck"

@interface GameDisabledList()

@property (nonatomic, retain) NSArray* inactiveGames;

@end

@implementation GameDisabledList

+ (GameDisabledList*)defaultList {
	if (!g_gameIgnoreList) {
		g_gameIgnoreList = [GameDisabledList new];
	}
	
	return g_gameIgnoreList;
}

- (id)init {
	self = [super init];
	if (!self) return nil;
	
	self.inactiveGames = [NSMutableArray arrayWithContentsOfFile:INACTIVE_GAMES_FILE];
	if (!_inactiveGames)
		self.inactiveGames = [NSArray array];
	
	return self;
}

- (void)dealloc {
	self.inactiveGames = nil;
	
	[super dealloc];
}

- (NSArray*)getDisabledIdsWithBlock:(void(^)(NSArray* ids))block {
	NSDate *last = [[NSUserDefaults standardUserDefaults] objectForKey:kSettingLastDisabledIdsCheck];
	if (!last || abs([last timeIntervalSinceNow]) > kSecondsIn24Hours) {
		[[MMProductStatusRequest alloc] initWithSuccessBlock:^(NSArray *prods, BOOL succeeded) {
			if (!succeeded) return;
			
			// only update the checked date if the request was successful
#ifdef _DISTRIBUTION
			[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kSettingLastDisabledIdsCheck];
#endif
			if ([prods isEqualToArray:_inactiveGames]) return;
			
			NSString* fileName = INACTIVE_GAMES_FILE;
			[prods writeToFile:fileName atomically:NO];
			self.inactiveGames = prods;
			block(_inactiveGames);
		}
												andFailBlock:nil];
	}
	
	return _inactiveGames;
}

@synthesize inactiveGames=_inactiveGames;

@end
