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

#import <string>
#import "frodo_lua.h"
#import "OpenFeintLuaModule.h"
#import "frodo.h"
#import "CPUC64.h"
#import "C64AppLuaModule.h"
#import "MMDigitalVerification.h"

static void stackDump (lua_State *L) {
	int i;
	int top = lua_gettop(L);
	for (i = 1; i <= top; i++) {  /* repeat for each level */
        int t = lua_type(L, i);
        switch (t) {
				
			case LUA_TSTRING:  /* strings */
				printf("`%s'", lua_tostring(L, i));
				break;
				
			case LUA_TBOOLEAN:  /* booleans */
				printf(lua_toboolean(L, i) ? "true" : "false");
				break;
				
			case LUA_TNUMBER:  /* numbers */
				printf("%g", lua_tonumber(L, i));
				break;
				
			default:  /* other values */
				printf("%s", lua_typename(L, t));
				break;
				
        }
        printf("  ");  /* put a separator */
	}
	printf("\n");  /* end the listing */
}

typedef struct IntArray {
	const char* type;
	size_t size;
	uint8 *elems;
} IntArray;

static int getmem(lua_State *L) {
	const char* key = luaL_checkstring(L, 1);
	if (strcasecmp("ram", key) == 0) {
		size_t nbytes = sizeof(IntArray);
		IntArray *a = (IntArray*)lua_newuserdata(L, nbytes);
		a->type = "RAM";
		a->size = 65536;
		a->elems = Frodo::Instance->TheC64->RAM;
	} else {
		luaL_argerror(L, 1, "invalid buffer");
	}
	
	luaL_getmetatable(L, "C64.memory");
	lua_setmetatable(L, -2);
	
	return 1;
}

static IntArray *checkmem (lua_State *L) {
	void *ud = luaL_checkudata(L, 1, "C64.memory");
	luaL_argcheck(L, ud != NULL, 1, "`memory buffer' expected");
	return (IntArray *)ud;
}

static uint8 *getelem (lua_State *L) {
	IntArray *a = checkmem(L);
	int index = luaL_checkint(L, 2);
    
	luaL_argcheck(L, 0 <= index && index < a->size, 2, "index out of range");
    
	/* return element address */
	return &a->elems[index];
}

static int setarrayV(lua_State *L) {
	int value = luaL_checkinteger(L, 3);
	luaL_argcheck(L, 0 <= value && value < 255, 3, "value out of range");
    *getelem(L) = value;
	return 0;
}

static int getarrayV (lua_State *L) {
	lua_pushinteger(L, *getelem(L));
	return 1;
}

static int getsize (lua_State *L) {
	IntArray *a = checkmem(L);
	lua_pushinteger(L, a->size);
	return 1;
}

int mem2string (lua_State *L) {
	IntArray *a = checkmem(L);
	lua_pushfstring(L, "%s(%d)", a->type, a->size);
	return 1;
}

struct tagCallData {
	lua_State *L;
	char *fn;
};

void lua_callfunction(lua_State *L, const char* fn) {
	int before = lua_gettop(L);

	lua_getglobal(L, fn);
	if (lua_pcall(L, 0, 1, 0) != 0)
        printf("error running function `f': %s\n", lua_tostring(L, -1));
	
	int elems = before-lua_gettop(L);
	
	if (elems)
		lua_pop(L, elems);
}

static void trap_release(trap_t *trap) {
	tagCallData *data = (tagCallData*)trap->data;
	free(data->fn);
	free(trap);
}

static trap_result_t trap_handler(MOS6510 *TheCPU, tagCallData *data) {
	lua_callfunction(data->L, data->fn);
	return TRAP_REDO;
}

static int add_trap(lua_State *L) {
	int addr = luaL_checkinteger(L, 1);
	luaL_argcheck(L, 0 <= addr && addr < 65536, 1, "address out of range: 0 <= addr < 65536");
	
	int oldInstruction = luaL_checkinteger(L, 2);
	luaL_argcheck(L, 0<=oldInstruction<=255, 2, "invalid instruction");
	
	size_t len = 0;
	const char *fn = luaL_checklstring(L, 3, &len);
	len++;
	
	trap_t *trap = (trap_t*)malloc(sizeof(trap_t) + sizeof(tagCallData));
	bzero(trap, sizeof(trap_t));

	tagCallData *data = (tagCallData*)((char*)trap + sizeof(trap_t));
	data->L = L;
	data->fn = strncpy((char*)malloc(len), fn, len);
	
	trap->addr = addr;
	trap->data = data;
	trap->forceRam = true;
	trap->trap_release = &trap_release;
	trap->handler = (trap_handler_t)&trap_handler;
	trap->org[0] = (uint8)oldInstruction;
	
	Frodo::Instance->TheC64->TheCPU->InstallTrap(trap);
	
	return 0;
}

static int to_int(uint8 bcd) {
	return (int)((bcd&0x0f) + ((bcd>>4)&0x0f) * 10);
}

/* convert big-endian BCD to integer
 * @param address
 * @param size (bytes)
 */
static int be_read_bcd(lua_State *L) {
	int addr = luaL_checkinteger(L, 1);
	luaL_argcheck(L, 0 <= addr && addr < 65536, 1, "address out of range: 0 <= addr < 65536");
	int size = luaL_checkinteger(L, 2);
	luaL_argcheck(L, 0 < size && size < 8, 1, "size is of range: 0 < size < 8");
	addr += size-1;
	
	uint8 *ram = Frodo::Instance->TheC64->RAM;
	int result = 0;
	int mag = 1;
	while (size--) {
		uint8 v = ram[addr--];
		result += to_int(v) * mag;
		mag *= 100;
	}
	
	lua_pushinteger(L, result);
	
	return 1;
}

/* convert little-endian BCD to integer
 * @param address
 * @param size (bytes)
 */
static int le_read_bcd(lua_State *L) {
	int addr = luaL_checkinteger(L, 1);
	luaL_argcheck(L, 0 <= addr && addr < 65536, 1, "address out of range: 0 <= addr < 65536");
	int size = luaL_checkinteger(L, 2);
	luaL_argcheck(L, 0 < size && size < 8, 1, "size is of range: 0 < size < 8");
	
	uint8 *ram = Frodo::Instance->TheC64->RAM;
	int result = 0;
	int mag = 1;
	while (size--) {
		uint8 v = ram[addr++];
		result += to_int(v) * mag;
		mag *= 100;
	}
	
	lua_pushinteger(L, result);
	
	return 1;
}

static const struct luaL_Reg cpulib_f[] = {
	{"getmem", getmem},
	{"add_trap", add_trap},				// add_trap(address, function:string)
	{"be_read_bcd", be_read_bcd},		
	{"le_read_bcd", le_read_bcd},		
	{NULL, NULL}
};

static const struct luaL_Reg cpulib_m[] = {
	{"__tostring", mem2string},
	{"set", setarrayV},
	{"get", getarrayV},
	{"size", getsize},
	{NULL, NULL}
};

int luaopen_cpulib(lua_State *L) {
	luaL_newmetatable(L, "C64.memory");
	lua_pushstring(L, "__index");
	lua_pushvalue(L, -2);  /* pushes the metatable */
	lua_settable(L, -3);  /* metatable.__index = metatable */
    
	luaL_openlib(L, NULL, cpulib_m, 0);
	
	luaL_openlib(L, "cpu", cpulib_f, 0);
	
	return 1;
}

#define cStringToNSStringNoCopy(x)	[[NSString alloc] initWithBytesNoCopy:(void*)x length:strlen(x) encoding:NSASCIIStringEncoding freeWhenDone:NO]

lua_State* lua_openFrodo(const char* script) {
	lua_State *L = lua_open();
	
	luaopen_base(L);
	luaopen_cpulib(L);
	luaopen_openfeintlib(L);
	luaopen_C64lib(L);
	
	if (script) {
		// always require digital signature for script files
		NSString* scriptPath = cStringToNSStringNoCopy(script);
		NSString* signPath = [[scriptPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"sign"];

		PKIFileVerification* pki = [MMDigitalVerification sharedManomioPublicKey];
		BOOL isSigned = [pki verifyFile:scriptPath withSignature:signPath];
		if (!isSigned) {
			NSLog(@"Script file must be digitally signed");
			lua_closeFrodo(L);
			return NULL;
		}
		
		int error = luaL_loadfile(L, script) || lua_pcall(L, 0, 0, 0);
		if (error) {
			NSLog(@"Error executing script: %@", cStringToNSStringNoCopy(lua_tostring(L, -1)));
			lua_pop(L, 1);  /* pop error message from the stack */
		}
	}		
	
	return L;
}

void lua_closeFrodo(lua_State *L) {
	lua_close(L);
}