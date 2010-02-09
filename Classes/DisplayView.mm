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

#import "DisplayView.h"
#import "debug.h"
#import "Frodo.h"
#import "C64.h"
#import "Prefs.h"
#import <QuartzCore/QuartzCore.h>
#import "Display.h"

static DisplayView *sharedInstance = nil;

void UpdateScreen() {
	[sharedInstance performSelectorOnMainThread:@selector(updateScreen) withObject:nil waitUntilDone:NO];
}

void SetImage(CGImageRef image) {
	[sharedInstance setImage:image];
}

@implementation DisplayView

void OnFrodoInitialized(Frodo *frodo) {
	[sharedInstance performSelectorOnMainThread:@selector(onFrodoInitialized) withObject:nil waitUntilDone:NO];
}

- (id)initWithFrame:(CGRect)frame {
	if (self = [super initWithFrame:frame]) {
		// Initialization code
		sharedInstance = self;
		initialized = NO;
		self.opaque = YES;
		isPortrait = YES;
	}
	return self;
}

- (void)onFrodoInitialized {
	theC64 = Frodo::Instance->TheC64;
	initialized = YES;
}

- (void)setImage:(CGImageRef)image {
	Frodo::Instance->eventInitialized += new InitializedEvent::S(&OnFrodoInitialized);
	_image = image;
}

- (void)layoutSubviews {
	UIInterfaceOrientation orientation = (UIInterfaceOrientation)[[UIDevice currentDevice] orientation];
	isPortrait = !UIInterfaceOrientationIsLandscape(orientation);
}

- (void)updateScreen {
	CALayer *layer = self.layer;
#if FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_INDEXED
	CGImageRef image = CGImageCreateCopy(_image);
	layer.contents = (id)image;
	if (ThePrefs.BordersOn)
		layer.contentsRect = CGRectMake(32.0/DISPLAY_X, 35.0/DISPLAY_Y, 320.0/DISPLAY_X, 217.0/DISPLAY_Y);
	else
		layer.contentsRect = CGRectMake(32.0/DISPLAY_X, 0, 320.0/DISPLAY_X, 217.0/DISPLAY_Y);
	CFRelease(image);
	
#elif FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_32BIT || FRODO_DISPLAY_FORMAT == DISPLAY_FORMAT_16BIT
	
	CGImageRef image = theC64->TheDisplay->GetImageBuffer();
	layer.contents = (id)image;
	if (ThePrefs.BordersOn)
		layer.contentsRect = CGRectMake(32.0/DISPLAY_X, 35.0/DISPLAY_Y, 320.0/DISPLAY_X, 217.0/DISPLAY_Y);
	else
		layer.contentsRect = CGRectMake(32.0/DISPLAY_X, 0, 320.0/DISPLAY_X, 217.0/DISPLAY_Y);
	CFRelease(image);	
#endif
	 
}

- (void)dealloc {
	[super dealloc];
}


@end
