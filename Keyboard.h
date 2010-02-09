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

/*
 C64 keyboard matrix:
 
 Bit   7   6   5   4   3   2   1   0
 0    CUD  F5  F3  F1  F7 CLR RET DEL
 1    SHL  E   S   Z   4   A   W   3
 2     X   T   F   C   6   D   R   5
 3     V   U   H   B   8   G   Y   7
 4     N   O   K   M   0   J   I   9
 5     ,   @   :   .   -   L   P   +
 6     /   ^   =  SHR HOM  ;   *   £
 7    R/S  Q   C= SPC  2  CTL  <-  1
 */

#define MATRIX(a,b) (((a) << 3) | (b))

#import <Foundation/Foundation.h>

#include <queue>
using std::queue;

#include "Commodore64KeyCodes.h"
/*
enum KeyCode {
	KeyCode_CUP				= MATRIX(0,7) | 0x80,
	KeyCode_CDN				= MATRIX(0,7),
	KeyCode_F5				= MATRIX(0,6),
	KeyCode_F3				= MATRIX(0,5),
	KeyCode_F1				= MATRIX(0,4),
	KeyCode_F7				= MATRIX(0,3),
	KeyCode_CLT				= MATRIX(0,2) | 0x80,
	KeyCode_CRT				= MATRIX(0,2),
	KeyCode_RET				= MATRIX(0,1),
	KeyCode_DEL				= MATRIX(0,0),
	
	KeyCode_SHL				= MATRIX(1,7),
	KeyCode_E				= MATRIX(1,6),
	KeyCode_S				= MATRIX(1,5),
	KeyCode_Z				= MATRIX(1,4),
	KeyCode_N4				= MATRIX(1,3),
	KeyCode_A				= MATRIX(1,2),
	KeyCode_W				= MATRIX(1,1),
	KeyCode_N3				= MATRIX(1,0),
	
	KeyCode_X				= MATRIX(2,7),
	KeyCode_T				= MATRIX(2,6),
	KeyCode_F				= MATRIX(2,5),
	KeyCode_C				= MATRIX(2,4),
	KeyCode_N6				= MATRIX(2,3),
	KeyCode_D				= MATRIX(2,2),
	KeyCode_R				= MATRIX(2,1),
	KeyCode_N5				= MATRIX(2,0),
	
	KeyCode_V				= MATRIX(3,7),
	KeyCode_U				= MATRIX(3,6),
	KeyCode_H				= MATRIX(3,5),
	KeyCode_B				= MATRIX(3,4),
	KeyCode_N8				= MATRIX(3,3),
	KeyCode_G				= MATRIX(3,2),
	KeyCode_Y				= MATRIX(3,1),
	KeyCode_N7				= MATRIX(3,0),
	
	KeyCode_N				= MATRIX(4,7),
	KeyCode_O				= MATRIX(4,6),
	KeyCode_K				= MATRIX(4,5),
	KeyCode_M				= MATRIX(4,4),
	KeyCode_N0				= MATRIX(4,3),
	KeyCode_J				= MATRIX(4,2),
	KeyCode_I				= MATRIX(4,1),
	KeyCode_N9				= MATRIX(4,0),
	
	KeyCode_COMMA			= MATRIX(5,7),
	KeyCode_AT				= MATRIX(5,6),
	KeyCode_COLON			= MATRIX(5,5),
	KeyCode_PERIOD			= MATRIX(5,4),
	KeyCode_MINUS			= MATRIX(5,3),
	KeyCode_L				= MATRIX(5,2),
	KeyCode_P				= MATRIX(5,1),
	KeyCode_PLUS			= MATRIX(5,0),
	
	KeyCode_DIVIDE			= MATRIX(6,7),
	KeyCode_CARET			= MATRIX(6,6),
	KeyCode_EQUALS			= MATRIX(6,5),
	KeyCode_SHR				= MATRIX(6,4),
	KeyCode_HOM				= MATRIX(6,3),
	KeyCode_SEMICOLON		= MATRIX(6,2),
	KeyCode_ASTERISK		= MATRIX(6,1),
	KeyCode_POUND			= MATRIX(6,0),
	
	KeyCode_RUNSTOP			= MATRIX(7,7),
	KeyCode_Q				= MATRIX(7,6),
	KeyCode_COMMODORE		= MATRIX(7,5),
	KeyCode_SPACE			= MATRIX(7,4),
	KeyCode_N2				= MATRIX(7,3),
	KeyCode_CONTROL			= MATRIX(7,2),
	KeyCode_BACKSPACE		= MATRIX(7,1),
	KeyCode_N1				= MATRIX(7,0),
	
	KeyCode_TOGGLE_SPEED	= 0xfe00,
	KeyCode_RESTORE			= 0xff00
};
*/

/*
 C64 keyboard matrix:
 
 Bit   7   6   5   4   3   2   1   0
 0    CUD  F5  F3  F1  F7 CLR RET DEL
 1    SHL  E   S   Z   4   A   W   3
 2     X   T   F   C   6   D   R   5
 3     V   U   H   B   8   G   Y   7
 4     N   O   K   M   0   J   I   9
 5     ,   @   :   .   -   L   P   +
 6     /   ^   =  SHR HOM  ;   *   £
 7    R/S  Q   C= SPC  2  CTL  <-  1
 */


enum KeyState {
	KeyStateUp = 0,
	KeyStateDown = 1
};

struct KeyEvent {
	KeyCode		code;
	KeyState	state;
};

class Keyboard  {
public:
	static KeyEvent HoldKey;		// push this event to hold the key down until the next keyboard poll
	
	Keyboard();
	~Keyboard();
	
	void QueueKeyEvent(KeyCode code, KeyState state);
	void QueueKeyEvent(KeyEvent &event);
	
	bool PollKeyEvent(KeyEvent *event);
	
private:
	queue<KeyEvent>		_events;
	NSRecursiveLock		*_lock;
};
