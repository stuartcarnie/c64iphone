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
 *  Display.cpp - C64 graphics display, emulator window handling
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */

#include "sysdeps.h"
#include "Prefs.h"
#include "Display.h"
#include "DisplayView.h"
#include "C64.h"
#include "Keyboard.h"
#include "debug.h"

#import <Foundation/Foundation.h>

extern void UpdateScreen();
extern void SetImage(CGImageRef image);
extern void SetPixels(uint8 *pixels);

// LED states
enum {
	LED_OFF,		// LED off
	LED_ON,			// LED on (green)
	LED_ERROR_ON,	// LED blinking (red), currently on
	LED_ERROR_OFF	// LED blinking, currently off
};

// Colors for speedometer/drive LEDs
enum {
	black = 0,
	white = 1,
	fill_gray = 16,
	shine_gray = 17,
	shadow_gray = 18,
	red = 19,
	green = 20,
	PALETTE_SIZE = 21
};

struct ColorPalette {
	unsigned char r, g, b;
};


#undef USE_THEORETICAL_COLORS

#ifdef USE_THEORETICAL_COLORS

// C64 color palette (theoretical values)
const uint8 palette_red[16] = {
	0x00, 0xff, 0xff, 0x00, 0xff, 0x00, 0x00, 0xff, 0xff, 0x80, 0xff, 0x40, 0x80, 0x80, 0x80, 0xc0
};

const uint8 palette_green[16] = {
	0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0x80, 0x40, 0x80, 0x40, 0x80, 0xff, 0x80, 0xc0
};

const uint8 palette_blue[16] = {
	0x00, 0xff, 0x00, 0xff, 0xff, 0x00, 0xff, 0x00, 0x00, 0x00, 0x80, 0x40, 0x80, 0x80, 0xff, 0xc0
};

#else

// C64 color palette (more realistic looking colors)
const uint8 palette_red[16] = {
	0x00, 0xff, 0x99, 0x00, 0xcc, 0x44, 0x11, 0xff, 0xaa, 0x66, 0xff, 0x40, 0x80, 0x66, 0x77, 0xc0
};

const uint8 palette_green[16] = {
	0x00, 0xff, 0x00, 0xff, 0x00, 0xcc, 0x00, 0xff, 0x55, 0x33, 0x66, 0x40, 0x80, 0xff, 0x77, 0xc0
};

const uint8 palette_blue[16] = {
	0x00, 0xff, 0x00, 0xcc, 0xcc, 0x44, 0x99, 0x00, 0x00, 0x00, 0x66, 0x40, 0x80, 0x66, 0xff, 0xc0
};

#endif

/*
 *  Update drive LED display (deferred until Update())
 */

void C64Display::UpdateLEDs(uint8 led) {
}

#if FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_16BIT
const int kBytesPerPixel			= 2;
const int kBitsPerComponent			= 5;
const unsigned int kFormat			= kCGBitmapByteOrder16Little | kCGImageAlphaNoneSkipFirst;
#elif FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_32BIT
const int kBytesPerPixel			= 4;
const int kBitsPerComponent			= 8;
const unsigned int kFormat			= kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst;
#endif


/*
 *  Display constructor
 */

C64Display::C64Display(C64 *the_c64) : TheC64(the_c64)
{
	// create indexed color palette
	CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();

	// allocate image buffer
	pixels = (uint8*)malloc(DISPLAY_X * (DISPLAY_Y));

#if FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_32BIT || FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_16BIT
	
	imageBuffer = (uint*)malloc(DISPLAY_X * DISPLAY_Y * kBytesPerPixel + 16);
	context = CGBitmapContextCreate(imageBuffer, 
									DISPLAY_X, DISPLAY_Y, kBitsPerComponent, 
									DISPLAY_X * kBytesPerPixel, rgbColorSpace, kFormat);
	
#if FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_32BIT
	for (int i = 0; i < sizeof(palette2) / sizeof(palette2[0]); i++) {
		palette2[i].a = 0;
		palette2[i].r = palette_red[i];
		palette2[i].g = palette_green[i];
		palette2[i].b = palette_blue[i];
	}
#else
	for (int i = 0; i < sizeof(palette2) / sizeof(palette2[0]); i++) {
		palette2[i].r = palette_red[i] >> 3;
		palette2[i].g = palette_green[i] >> 3;
		palette2[i].b = palette_blue[i] >> 3;
	}
#endif
	SetImage(nil);
	
#elif FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_INDEXED
	
	ColorPalette palette[PALETTE_SIZE];
	for (int i = 0; i < 16; i++) {
		palette[i].r = palette_red[i];
		palette[i].g = palette_green[i];
		palette[i].b = palette_blue[i];
	}
	
	palette[fill_gray].r = palette[fill_gray].g = palette[fill_gray].b = 0xd0;
	palette[shine_gray].r = palette[shine_gray].g = palette[shine_gray].b = 0xf0;
	palette[shadow_gray].r = palette[shadow_gray].g = palette[shadow_gray].b = 0x80;
	palette[red].r = 0xf0;
	palette[red].g = palette[red].b = 0;
	palette[green].g = 0xf0;
	palette[green].r = palette[green].b = 0;
	CGColorSpaceRef colorSpace = CGColorSpaceCreateIndexed(rgbColorSpace, PALETTE_SIZE, (unsigned char*)palette);
		
	// 
	CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixels, DISPLAY_X * (DISPLAY_Y), NULL);
	_image = CGImageCreate(DISPLAY_X, DISPLAY_Y, 8, 8, DISPLAY_X, colorSpace, 
						   kCGBitmapByteOrderDefault,
						   provider, NULL, false, kCGRenderingIntentDefault);
	
	CGDataProviderRelease(provider);
	CGColorSpaceRelease(colorSpace);
	SetImage(_image);
	
#endif
	CGColorSpaceRelease(rgbColorSpace);
}


/*
 *  Display destructor
 */

C64Display::~C64Display() {
#if FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_32BIT || FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_16BIT
	CFRelease(context);
	free(imageBuffer);
#elif FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_INDEXED
	CFRelease(_image);
	free(pixels);
#endif
}

#if FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_32BIT

#if !TARGET_IPHONE_SIMULATOR

extern "C" void create_bgra(void* dst, size_t size, void* src, void* palette);

CGImageRef C64Display::GetImageBuffer() {
	int		size = DISPLAY_X * DISPLAY_Y;
	uint	*dst = imageBuffer;
	uint8	*src = pixels;
	uint	*pal = (uint *)&palette2;
	
	create_bgra(dst, size, src, pal);
	
	return CGBitmapContextCreateImage(context);
}

#else

CGImageRef C64Display::GetImageBuffer() {
	int		size = DISPLAY_X * DISPLAY_Y;
	uint	*dst = imageBuffer;
	uint8	*src = pixels;
	uint	*pal = (uint *)&palette2;
	do {
		*dst = *(pal + *src);
		dst++; src++;
	} while (--size);
	
	return CGBitmapContextCreateImage(context);
}

#endif

#elif FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_16BIT

#if TARGET_IPHONE_SIMULATOR

CGImageRef C64Display::GetImageBuffer() {
	int		size = DISPLAY_X * DISPLAY_Y >> 2;
	uint	*dst = imageBuffer;
	uint	*src = (uint*)pixels;
	ushort	*pal = (ushort *)&palette2;
	do {
		uint upx = *src++;
		ushort px = upx & 0xFFFF;
		*dst++ = *(pal + (px & 0x1f)) | *(pal + (px >> 8)) << 16;
		px = upx >> 16;
		*dst++ = *(pal + (px & 0x1f)) | *(pal + (px >> 8)) << 16;
	} while (--size);
	
	return CGBitmapContextCreateImage(context);
}

#else

extern "C" void create_bgrx5551(void* dst, size_t size, void* src, void* palette);

CGImageRef C64Display::GetImageBuffer() {
	int			size = DISPLAY_X * DISPLAY_Y >> 2;
	uint	*dst = imageBuffer;
	uint	*src = (uint*)pixels;
	ushort	*pal = (ushort *)&palette2;
	create_bgrx5551(dst, size, src, pal);
	return CGBitmapContextCreateImage(context);
}

#endif

#endif

/*
 *  Redraw bitmap
 */

void C64Display::Update(void) {
	UpdateScreen();
}

static void translate_key(int c64_key, bool key_up, uint8 *key_matrix, uint8 *rev_matrix)
{
	if (c64_key < 0)
		return;
	
	// Handle other keys
	bool shifted = c64_key & 0x80;
	int c64_byte = (c64_key >> 3) & 7;
	int c64_bit = c64_key & 7;
	if (key_up) {
		if (shifted) {
			key_matrix[6] |= 0x10;
			rev_matrix[4] |= 0x40;
		}
		key_matrix[c64_byte] |= (1 << c64_bit);
		rev_matrix[c64_bit] |= (1 << c64_byte);
	} else {
		if (shifted) {
			key_matrix[6] &= 0xef;
			rev_matrix[4] &= 0xbf;
		}
		key_matrix[c64_byte] &= ~(1 << c64_bit);
		rev_matrix[c64_bit] &= ~(1 << c64_byte);
	}
}

void C64Display::PollKeyboard(uint8 *key_matrix, uint8 *rev_matrix)
{
	KeyEvent event;
	while (TheC64->TheKeyboard->PollKeyEvent(&event)) {
		DLog(@"Received key event: %d(%@)", event.code,
			 event.state == KeyStateDown ? @"down" : @"up");
		
		if (event.state == KeyStateDown && event.code > KeyCode_SPECIALKEYSBASE) {
			if (event.code == KeyCode_RESTORE) {
				TheC64->NMI();
				return;
			}
			else if (event.code == KeyCode_TOGGLE_SPEED) {
				if (ThePrefs.LimitSpeed) {
					ThePrefs.LimitSpeed = false;
					ThePrefs.OldSkipFrames = ThePrefs.SkipFrames;
					ThePrefs.SkipFrames = 10;
				} else {
					ThePrefs.LimitSpeed = true;
					ThePrefs.SkipFrames = ThePrefs.OldSkipFrames;
				}
				return;
			} else if (event.code == KeyCode_RESET) {
				TheC64->Reset();
				return;
			}
		}
		
		translate_key((int)event.code, (event.state == KeyStateUp), key_matrix, rev_matrix);
	}	
}



/*
 *  Prefs may have changed
 */

void C64Display::NewPrefs(Prefs *prefs)
{
}


/*
 *  Allocate C64 colors
 */
void C64Display::InitColors(uint8 *colors)
{
	for (int i=0; i<256; i++)
		colors[i] = i & 0x0f;
}



/*
 *  Return pointer to bitmap data
 */

uint8 *C64Display::BitmapBase(void)
{
	return pixels;
}


/*
 *  Return number of bytes per row
 */

int C64Display::BitmapXMod(void)
{
	return DISPLAY_X;
}

BOOL showingRequester;

@interface RequesterDelegate : NSObject<UIAlertViewDelegate>
{

}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex;

@end

@implementation RequesterDelegate

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
	showingRequester = NO;
}

@end




/*
 *  Show a requester (error message)
 */

long int ShowRequester(const char *a, const char *b, const char *)
{
	NSString *msg = [NSString stringWithCString:a];
	NSString *buttonText = [NSString stringWithCString:b];
	
	RequesterDelegate *theDelegate = [[RequesterDelegate alloc] init];
	// open an alert with just an OK button
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:msg
												   delegate:theDelegate cancelButtonTitle:buttonText otherButtonTitles: nil];
	
	showingRequester = YES;
	[alert show];
	while (CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.5, false) == kCFRunLoopRunTimedOut && showingRequester == YES) {
	}
	[alert release];
	[msg release];
	[buttonText release];
	[theDelegate release];
	return 1;
}