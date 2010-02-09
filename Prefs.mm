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
 *  Prefs.cpp - Global preferences
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */

#include "sysdeps.h"

#include "Prefs.h"
#include "Display.h"
#include "C64.h"

// These are the active preferences
Prefs ThePrefs;

// These are the preferences on disk
Prefs ThePrefsOnDisk;


/*
 *  Constructor: Set up preferences with defaults
 */

Prefs::Prefs()
{
	NormalCycles = 63;
	BadLineCycles = 23;
	CIACycles = 63;
	FloppyCycles = 64;
	SkipFrames = 5;
	
	DriveType = DRVTYPE_DIR;
	DrivePath[0]='\0';
	
	LuaScriptPath[0] = NULL;
	
	SIDType = SIDTYPE_DIGITAL;
	DisplayType = DISPTYPE_WINDOW;
	LatencyMin = 80;
	LatencyMax = 250;

	SpritesOn = true;
	SpriteCollisions = true;
	Joystick1On = true;
	Joystick2On = false;
	JoystickSwap = true;
	LimitSpeed = true;
	FastReset = false;
	CIAIRQHack = false;
	Emul1541Proc = false;
	AdaptiveFrameSkip = true;
	BordersOn = false;
	SingleCycleEmulation = false;
	SIDOn = true;
	SIDFilters = true;
	ShowSpeed = false;
	AutoBoot = true;
	UseCommodoreKeyboard = false;
	OptimizeForSpeedAndBattery = true;
}

void Prefs::ChangeRom(NSString *filename) {
	[filename getCString:DrivePath maxLength:sizeof(DrivePath) encoding:[NSString defaultCStringEncoding]];
	if ([filename rangeOfString:@"d64" options:NSCaseInsensitiveSearch].location == NSNotFound) {
		DriveType = DRVTYPE_T64;
	} else {
		DriveType = DRVTYPE_D64;
	}
}

void Prefs::LuaScript(NSString *filename) {
	if (filename)
		[filename getCString:LuaScriptPath maxLength:sizeof(LuaScriptPath) encoding:[NSString defaultCStringEncoding]];
	else {
		LuaScriptPath[0] = NULL;
	}

}

/*
 *  Check if two Prefs structures are equal
 */

bool Prefs::operator==(const Prefs &rhs) const
{
	return (1
			&& NormalCycles == rhs.NormalCycles
			&& BadLineCycles == rhs.BadLineCycles
			&& CIACycles == rhs.CIACycles
			&& FloppyCycles == rhs.FloppyCycles
			&& SkipFrames == rhs.SkipFrames
			&& DriveType == rhs.DriveType
			&& strcmp(DrivePath, rhs.DrivePath) == 0
			&& SIDType == rhs.SIDType
			&& DisplayType == rhs.DisplayType
			&& SpritesOn == rhs.SpritesOn
			&& SpriteCollisions == rhs.SpriteCollisions
			&& Joystick1On == rhs.Joystick1On
			&& Joystick2On == rhs.Joystick2On
			&& JoystickSwap == rhs.JoystickSwap
			&& LimitSpeed == rhs.LimitSpeed
			&& FastReset == rhs.FastReset
			&& CIAIRQHack == rhs.CIAIRQHack
			&& Emul1541Proc == rhs.Emul1541Proc
			&& SIDFilters == rhs.SIDFilters
			&& SingleCycleEmulation == rhs.SingleCycleEmulation
			&& SIDOn == rhs.SIDOn
			&& ShowSpeed == rhs.ShowSpeed
			&& AutoBoot == rhs.AutoBoot
			&& UseCommodoreKeyboard == rhs.UseCommodoreKeyboard
			&& OptimizeForSpeedAndBattery == rhs.OptimizeForSpeedAndBattery
			);
}

bool Prefs::operator!=(const Prefs &rhs) const
{
	return !operator==(rhs);
}

/*
 *  Check preferences for validity and correct if necessary
 */

void Prefs::Check(void)
{
	if (SkipFrames <= 0) SkipFrames = 1;
	
	if (SIDType < SIDTYPE_NONE || SIDType > SIDTYPE_SIDCARD)
		SIDType = SIDTYPE_NONE;
	
	if (DisplayType < DISPTYPE_WINDOW || DisplayType > DISPTYPE_SCREEN)
		DisplayType = DISPTYPE_WINDOW;
	
	if (DriveType < DRVTYPE_DIR || DriveType > DRVTYPE_T64)
		DriveType = DRVTYPE_DIR;
}

void Prefs::DisableCommodoreKeyboard() {
	// for now, Commodore keyboard is always disabled after load
	UseCommodoreKeyboard = false;
}

void replacechr(char *path, char find, char repl) {
	do {
		if (*path == find)
			*path = repl;
	} while (*path++);
}

void toStore(char *path) {
	replacechr(path, ' ', ':');
}

void fromStore(char *path) {
	replacechr(path, ':', ' ');
}

/*
 *  Load preferences from file
 */

void Prefs::Load(const char *filename)
{
	FILE *file;
	char line[256], keyword[256], value[256];
	
	if ((file = fopen(filename, "r")) != NULL) {
		while(fgets(line, 255, file)) {
			if (sscanf(line, "%s = %s\n", keyword, value) == 2) {
				if (!strcmp(keyword, "NormalCycles"))
					NormalCycles = atoi(value);
				else if (!strcmp(keyword, "BadLineCycles"))
					BadLineCycles = atoi(value);
				else if (!strcmp(keyword, "CIACycles"))
					CIACycles = atoi(value);
				else if (!strcmp(keyword, "FloppyCycles"))
					FloppyCycles = atoi(value);
				else if (!strcmp(keyword, "SkipFrames"))
					SkipFrames = atoi(value);
				else if (!strcmp(keyword, "LatencyMin"))
					LatencyMin = atoi(value);
				else if (!strcmp(keyword, "LatencyMax"))
					LatencyMax = atoi(value);
				else if (!strcmp(keyword, "DriveType8"))
					if (!strcmp(value, "DIR"))
						DriveType = DRVTYPE_DIR;
					else if (!strcmp(value, "D64"))
						DriveType = DRVTYPE_D64;
					else
						DriveType = DRVTYPE_T64;
				else if (!strcmp(keyword, "DrivePath8")) {
						fromStore(value);
						strcpy(DrivePath, value);
				}
				else if (!strcmp(keyword, "LuaScriptPath")) {
					fromStore(value);
					strcpy(LuaScriptPath, value);
				}
				else if (!strcmp(keyword, "SIDType"))
					if (!strcmp(value, "DIGITAL"))
						SIDType = SIDTYPE_DIGITAL;
					else if (!strcmp(value, "SIDCARD"))
						SIDType = SIDTYPE_SIDCARD;
					else
						SIDType = SIDTYPE_NONE;
				else if (!strcmp(keyword, "BordersOn"))
					BordersOn = !strcmp(value, "TRUE");
				else if (!strcmp(keyword, "SpritesOn"))
					SpritesOn = !strcmp(value, "TRUE");
				else if (!strcmp(keyword, "SpriteCollisions"))
					SpriteCollisions = !strcmp(value, "TRUE");
				else if (!strcmp(keyword, "Joystick1On"))
					Joystick1On = !strcmp(value, "TRUE");
				else if (!strcmp(keyword, "Joystick2On"))
					Joystick2On = !strcmp(value, "TRUE");
				else if (!strcmp(keyword, "JoystickSwap"))
					JoystickSwap = !strcmp(value, "TRUE");
				else if (!strcmp(keyword, "LimitSpeed"))
					LimitSpeed = !strcmp(value, "TRUE");
				else if (!strcmp(keyword, "FastReset"))
					FastReset = !strcmp(value, "TRUE");
				else if (!strcmp(keyword, "CIAIRQHack"))
					CIAIRQHack = !strcmp(value, "TRUE");
				else if (!strcmp(keyword, "Emul1541Proc"))
					Emul1541Proc = !strcmp(value, "TRUE");
				else if (!strcmp(keyword, "SIDFilters"))
					SIDFilters = !strcmp(value, "TRUE");
				else if (!strcmp(keyword, "SingleCycleEmulation"))
					SingleCycleEmulation = !strcmp(value, "TRUE");
				else if (!strcmp(keyword, "SIDOn"))
					SIDOn = !strcmp(value, "TRUE");
				else if (!strcmp(keyword, "ShowSpeed"))
					ShowSpeed = !strcmp(value, "TRUE");
				else if (!strcmp(keyword, "AutoBoot"))
					AutoBoot = !strcmp(value, "TRUE");
				else if (!strcmp(keyword, "UseCommodoreKeyboard"))
					UseCommodoreKeyboard = !strcmp(value, "TRUE");
				else if (!strcmp(keyword, "OptimizeForSpeedAndBattery"))
					OptimizeForSpeedAndBattery = !strcmp(value, "TRUE");
			}
		}
		fclose(file);
	}
	Check();
	ConfigureOptimizations();
	DisableCommodoreKeyboard();
	ThePrefsOnDisk = *this;
}

/*
 * Reconfigures the prefs after load or setting properties
 */

void Prefs::ConfigureOptimizations() {
	SIDFilters = true;
	
	if (OptimizeForSpeedAndBattery) {
	} else {
	}
#if defined(_ARM_ARCH_7) || TARGET_IPHONE_SIMULATOR
	SkipFrames = 1;
#endif
}

/*
 *  Save preferences to file
 *  true: success, false: error
 */

bool Prefs::Save(const char *filename)
{
	FILE *file;
	
	Check();
	if ((file = fopen(filename, "w")) != NULL) {
		fprintf(file, "NormalCycles = %d\n", NormalCycles);
		fprintf(file, "BadLineCycles = %d\n", BadLineCycles);
		fprintf(file, "CIACycles = %d\n", CIACycles);
		fprintf(file, "FloppyCycles = %d\n", FloppyCycles);
		fprintf(file, "SkipFrames = %d\n", SkipFrames);
		fprintf(file, "LatencyMin = %d\n", LatencyMin);
		fprintf(file, "LatencyMax = %d\n", LatencyMax);
		fprintf(file, "DriveType%d = ", 8);
		switch (DriveType) {
			case DRVTYPE_DIR:
				fprintf(file, "DIR\n");
				break;
			case DRVTYPE_D64:
				fprintf(file, "D64\n");
				break;
			case DRVTYPE_T64:
				fprintf(file, "T64\n");
				break;
		}
		toStore(DrivePath);
		fprintf(file, "DrivePath%d = %s\n", 8, DrivePath);
		fromStore(DrivePath);
		
		toStore(LuaScriptPath);
		fprintf(file, "LuaScriptPath = %s\n", LuaScriptPath);
		fromStore(LuaScriptPath);
		
		fprintf(file, "SIDType = ");
		switch (SIDType) {
			case SIDTYPE_NONE:
				fprintf(file, "NONE\n");
				break;
			case SIDTYPE_DIGITAL:
				fprintf(file, "DIGITAL\n");
				break;
			case SIDTYPE_SIDCARD:
				fprintf(file, "SIDCARD\n");
				break;
		}
		fprintf(file, "BordersOn = %s\n", BordersOn ? "TRUE" : "FALSE");
		fprintf(file, "SpritesOn = %s\n", SpritesOn ? "TRUE" : "FALSE");
		fprintf(file, "SpriteCollisions = %s\n", SpriteCollisions ? "TRUE" : "FALSE");
		fprintf(file, "Joystick1On = %s\n", Joystick1On ? "TRUE" : "FALSE");
		fprintf(file, "Joystick2On = %s\n", Joystick2On ? "TRUE" : "FALSE");
		fprintf(file, "JoystickSwap = %s\n", JoystickSwap ? "TRUE" : "FALSE");
		fprintf(file, "LimitSpeed = %s\n", LimitSpeed ? "TRUE" : "FALSE");
		fprintf(file, "FastReset = %s\n", FastReset ? "TRUE" : "FALSE");
		fprintf(file, "CIAIRQHack = %s\n", CIAIRQHack ? "TRUE" : "FALSE");
		fprintf(file, "Emul1541Proc = %s\n", Emul1541Proc ? "TRUE" : "FALSE");
		fprintf(file, "SIDFilters = %s\n", SIDFilters ? "TRUE" : "FALSE");
		fprintf(file, "SingleCycleEmulation = %s\n", SingleCycleEmulation ? "TRUE" : "FALSE");
		fprintf(file, "SIDOn = %s\n", SIDOn ? "TRUE" : "FALSE");
		fprintf(file, "SIDFilters = %s\n", SIDFilters ? "TRUE" : "FALSE");
		fprintf(file, "ShowSpeed = %s\n", ShowSpeed ? "TRUE" : "FALSE");
		fprintf(file, "AutoBoot = %s\n", AutoBoot ? "TRUE" : "FALSE");
		fprintf(file, "UseCommodoreKeyboard = %s\n", UseCommodoreKeyboard ? "TRUE" : "FALSE");
		fprintf(file, "OptimizeForSpeedAndBattery = %s\n", OptimizeForSpeedAndBattery ? "TRUE" : "FALSE");
		fclose(file);
		ThePrefsOnDisk = *this;
		return true;
	}
	return false;
}

