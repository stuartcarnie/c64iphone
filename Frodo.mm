/*
 Frodo, Commodore 64 emulator for the iPhone
 Copyright (C) 1994-1997,2002 Christian Bauer
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
 *  Frodo.cpp
 *  iFrodo
 *
 *  Created by Stuart Carnie on 5/5/08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

#include "Frodo.h"

#include "sysdeps.h"

#include "C64.h"
#include "Display.h"
#include "Prefs.h"
#include "Version.h"

#import "cf_typeref.h"

extern int init_graphics(void);

NSString* Frodo::s_path = nil;
Frodo *Frodo::Instance;
bool Frodo::AutoBoot = false;

static uint8 BROM[] = {
#include "BASIC_ROM.i"
};

uint32 BROM_size = sizeof(BROM) / sizeof(BROM[0]);

Frodo::Frodo()
{
	TheC64 = NULL;
	Instance = this;
}

bool Frodo::load_rom_files(void)
{
	NSBundle *mainBundle = [NSBundle mainBundle];
	try {
		
		NSString *path;
		NSData *data;
		
		// BASIC ROM
		memcpy(TheC64->Basic, BROM, BROM_size);
		
		// Load Kernal ROM
		path = [mainBundle pathForResource:@"Kernal.ROM" ofType:nil];
		data = [NSData dataWithContentsOfFile:path];
		if ([data length] != 0x2000){
			[data release];
			throw "Unable to load 'Kernal ROM'";
		}
		[data getBytes:TheC64->Kernal];
		[data release];
			
		// Load Char ROM
		path = [mainBundle pathForResource:@"Char.ROM" ofType:nil];
		data = [NSData dataWithContentsOfFile:path];
		if ([data length] != 0x1000){
			[data release];
			throw "Unable to load 'Char ROM'";
		}
		[data getBytes:TheC64->Char];
		[data release];
		
		// Load 1541 ROM
		path = [mainBundle pathForResource:@"1541.ROM" ofType:nil];
		data = [NSData dataWithContentsOfFile:path];
		if ([data length] != 0x4000){
			[data release];
			throw "Unable to load '1541 ROM'";
		}
		[data getBytes:TheC64->ROM1541];
		[data release];
		
	}
	catch (const char * str) {
		ShowRequester((char*)str, "Quit");
		return false;
	}
	return true;
}

const char* Frodo::prefs_path() {
	if (s_path == nil)
		s_path = [[DOCUMENTS_FOLDER stringByAppendingPathComponent:@"frodo.prefs"] retain];
	return [s_path cStringUsingEncoding:[NSString defaultCStringEncoding]];
}

void Frodo::ReadyToRun(void)
{
	ThePrefs.Load(prefs_path());
	
	// Create and start C64
	TheC64 = new C64;
	if (load_rom_files()) {
		eventInitialized(this);
		TheC64->Run(AutoBoot);
	}
		
	delete TheC64;
}


Prefs *Frodo::reload_prefs(void)
{
	static Prefs newprefs;
	newprefs.Load(prefs_path());
	return &newprefs;
}
