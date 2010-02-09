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


#import "C64AppLuaModule.h"
#import "GamePack.h"

static int currentGameUsingTrainer(lua_State *L) {
	GamePack* g = [GamePack globalGamePack];
	BOOL usingTrainer = NO;
	if (g.currentGame) {
		usingTrainer = g.currentGame.useTrainer;
	}
	lua_pushboolean(L, usingTrainer);
	return 1;
}


static const struct luaL_Reg c64lib[] = {
	{"currentGameUsingTrainer", currentGameUsingTrainer},
	{NULL, NULL}
};

int luaopen_C64lib(lua_State *L) {
	luaL_openlib(L, "C64", c64lib, 0);
	return 1;
}