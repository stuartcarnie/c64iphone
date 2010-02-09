/*
 Frodo, Commodore 64 emulator for the iPhone
 Copyright (C) 2007,2008 Stuart Carnie
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

typedef unsigned char uint8;
typedef unsigned int uint32;
typedef unsigned short uint16;

enum trap_result_t {
	TRAP_REDO,					// retrieves the original opcode and continues normal execution, leaving trap in place 
	TRAP_REPLACE_AND_REDO,		// replaces break with original opcode and continues execution of original routine
	TRAP_DO_BREAK,				// executes trap, followed by BRK
};

typedef trap_result_t (*trap_handler_t)(void *, void *data) ;

typedef struct __trap
{
	struct __trap *next_trap;
	bool forceRam;
	int addr;
	int org[3];
	trap_handler_t handler;
	void* data;
	void (*trap_release)(struct __trap *trap);		// called when trap handler is being released
} trap_t;

struct trap_result2_t {
	trap_result_t result;
	trap_t *trap;
};

