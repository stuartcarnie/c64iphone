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

#import "OpenFeintLuaModule.h"
#import "OFHighScoreService.h"
#import "OFAchievementService.h"

// * openfeint integration

static int post_high_score(lua_State *L) {
	int score = luaL_checkinteger(L, 1);
	size_t len = 0;
	const char *leaderboard = luaL_checklstring(L, 2, &len);
	
	[OFHighScoreService setHighScore:score forLeaderboard:[NSString stringWithCString:leaderboard encoding:[NSString defaultCStringEncoding]] onSuccess:OFDelegate() onFailure:OFDelegate()];
	return 0;
}

static int post_high_score_with_displayText(lua_State *L) {
	int score = luaL_checkinteger(L, 1);
	size_t len = 0;
	const char *displayText = luaL_checklstring(L, 2, &len);
	const char *leaderboard = luaL_checklstring(L, 3, &len);
	
	[OFHighScoreService setHighScore:score withDisplayText:[NSString stringWithCString:displayText encoding:[NSString defaultCStringEncoding]] 
					  forLeaderboard:[NSString stringWithCString:leaderboard encoding:[NSString defaultCStringEncoding]] onSuccess:OFDelegate() onFailure:OFDelegate()];
	return 0;
}

static int unlock_achievement(lua_State *L) {
	size_t len = 0;
	const char *achievement = luaL_checklstring(L, 1, &len);
	
	[OFAchievementService unlockAchievement:[NSString stringWithCString:achievement encoding:[NSString defaultCStringEncoding]]];
	return 0;
}

static const struct luaL_Reg openfeintlib[] = {
	{"post_high_score", post_high_score},
	{"post_high_score_with_displayText", post_high_score_with_displayText},
	{"unlock_achievement", unlock_achievement},
	{NULL, NULL}
};

int luaopen_openfeintlib(lua_State *L) {
	luaL_openlib(L, "of", openfeintlib, 0);
	return 1;
}