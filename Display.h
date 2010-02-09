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
 *  Display.h - C64 graphics display, emulator window handling
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */

#ifndef _DISPLAY_H
#define _DISPLAY_H

#import <CoreGraphics/CoreGraphics.h>

// Display dimensions
#if defined(SMALL_DISPLAY)
const int C64DISPLAY_X = 0x180;
const int DISPLAY_X = 0x140;
const int DISPLAY_Y = 0x110;
#else
const int C64DISPLAY_X = 0x180;
const int DISPLAY_X = 0x180;
const int DISPLAY_Y = 0x110;
#endif

class C64Window;
class C64Screen;
class C64;
class Prefs;

// Class for C64 graphics display
class C64Display {
public:
	C64Display(C64 *the_c64);
	~C64Display();

	void UpdateLEDs(uint8 led);
	uint8 *BitmapBase(void);
	int BitmapXMod(void);

#if FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_32BIT || FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_16BIT
	CGImageRef GetImageBuffer() /*__attribute__((section("__TEXT, __groupme")))*/;
#endif

	void PollKeyboard(uint8 *key_matrix, uint8 *rev_matrix);

	void InitColors(uint8 *colors);
	void NewPrefs(Prefs *prefs);
	void Update();

	C64 *TheC64;

private:
	
	// buffer used by the emulator
	uint8			*pixels;

#if FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_32BIT
#pragma pack(push,1)
	struct ColorPalette2 {
		unsigned char b, g, r, a;
	};
#pragma pack(pop)
	
	CGContextRef	context;
	uint			*imageBuffer;
	ColorPalette2	palette2[16];
#elif FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_16BIT
#pragma pack(push,1)
	struct ColorPalette2 {
		unsigned char b:5;
		unsigned char g:5;
		unsigned char r:5;
	};
#pragma pack(pop)

	CGContextRef	context;
	uint			*imageBuffer;
	ColorPalette2	palette2[16];	
#elif FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_INDEXED
	// image buffer data
	CGImageRef		_image;
#endif
};


// Exported functions
extern long ShowRequester(const char *str, const char *button1, const char *button2 = NULL);


#endif
