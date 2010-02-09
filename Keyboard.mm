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

#include "Keyboard.h"
#import "CNSRecursiveLock.h"

KeyEvent Keyboard::HoldKey = { KeyCode_HOLD_KEY, KeyStateUp };

Keyboard::Keyboard() {
	_lock = [NSRecursiveLock alloc];
}

Keyboard::~Keyboard() {
	[_lock release];
}

void Keyboard::QueueKeyEvent(KeyCode code, KeyState state) {
	CNSRecursiveLock autolock(_lock);	// this ensures the lock is released on function exit
	
	KeyEvent event = { code, state };
	_events.push(event);
}


void Keyboard::QueueKeyEvent(KeyEvent &event) {
	CNSRecursiveLock autolock(_lock);	// this ensures the lock is released on function exit
	
	_events.push(event);
}

bool Keyboard::PollKeyEvent(KeyEvent *event) {
	CNSRecursiveLock autolock(_lock);	// this ensures the lock is released on function exit, regardless of how it exits
	
	if (_events.size() > 0) {
		*event = _events.front();
		_events.pop();
		return event->code != KeyCode_HOLD_KEY;
	}
	
	return false;
}