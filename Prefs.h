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
 *  Prefs.h - Global preferences
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */

#ifndef _PREFS_H
#define _PREFS_H

#define SNAPSHOT_VERSION 3
const int SNAPSHOT_SIZE_1 = 0x9200L;
const int SNAPSHOT_SIZE_2 = 0x8f00L;

class NSString;

// Drive types
enum {
	DRVTYPE_DIR,	// 1541 emulation in host file system
	DRVTYPE_D64,	// 1541 emulation in .d64 file
	DRVTYPE_T64		// 1541 emulation in .t64 file
};


// SID types
enum {
	SIDTYPE_NONE,		// SID emulation off
	SIDTYPE_DIGITAL,	// Digital SID emulation
	SIDTYPE_SIDCARD		// SID card
};



// Display types (BeOS)
enum {
	DISPTYPE_WINDOW,	// BWindow
	DISPTYPE_SCREEN		// BWindowScreen
};


// Preferences data
class Prefs {
public:
	Prefs();
	bool ShowEditor(bool startup, char *prefs_name);
	void Check(void);
	void Load(const char *filename);
	bool Save(const char *filename);
	
	void ChangeRom(NSString *filename);
	
	void LuaScript(NSString *filename);

	bool operator==(const Prefs &rhs) const;
	bool operator!=(const Prefs &rhs) const;

	int NormalCycles;		// Available CPU cycles in normal raster lines
	int BadLineCycles;		// Available CPU cycles in Bad Lines
	int CIACycles;			// CIA timer ticks per raster line
	int FloppyCycles;		// Available 1541 CPU cycles per line
	int SkipFrames;			// Draw every n-th frame
	int OldSkipFrames;		// when LimitSpeed = false, SkipFrames = 5, and old value is copied here

	int DriveType;		// Type of drive 8

	char DrivePath[256];	// Path for drive 8
	char LuaScriptPath[256];	// Path to lua boot script

	int SIDType;			// SID emulation type
	int DisplayType;		// Display type (BeOS)
	int LatencyMin;			// Min msecs ahead of sound buffer (Win32)
	int LatencyMax;			// Max msecs ahead of sound buffer (Win32)

	bool ShowSpeed;			// Show speed index
	bool SpritesOn;			// Sprite display is on
	bool SpriteCollisions;	// Sprite collision detection is on
	bool Joystick1On;		// Joystick connected to port 1 of host
	bool Joystick2On;		// Joystick connected to port 2 of host
	bool JoystickSwap;		// Swap joysticks 1<->2
	bool LimitSpeed;		// Limit speed to 100%
	bool FastReset;			// Skip RAM test on reset
	bool CIAIRQHack;		// Write to CIA ICR clears IRQ
	bool Emul1541Proc;		// Enable processor-level 1541 emulation
	bool SIDFilters;		// Emulate SID filters

	bool AdaptiveFrameSkip;
	bool BordersOn;
	bool SingleCycleEmulation;
	bool SIDOn;
	bool AutoBoot;
	bool UseCommodoreKeyboard;			// determines whether to always show Commodore keyboard
	bool OptimizeForSpeedAndBattery;

	void ConfigureOptimizations();
	void DisableCommodoreKeyboard();
};


// These are the active preferences
extern Prefs ThePrefs;

// Theses are the preferences on disk
extern Prefs ThePrefsOnDisk;

#endif
