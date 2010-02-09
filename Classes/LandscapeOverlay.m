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

#import "LandscapeOverlay.h"
#import "CocoaUtility.h"
#import "C64Defaults.h"

@interface LandscapeOverlay()

- (void)defaultsChanged:(NSNotification*)notification;
- (void)loadViews;

@end

@implementation LandscapeOverlay


- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(defaultsChanged:) 
													 name:NSUserDefaultsDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[fireArea release];
	[stickArea release];
    [super dealloc];
}

- (void)defaultsChanged:(NSNotification*)notification {
	[self setNeedsLayout];
}

#define kInfoTop 10

- (void)layoutSubviews {
	if (!fireArea) [self loadViews];
	
	BOOL joystickOnRight = [C64Defaults shared].joystickOnRight;
	
	if (joystickOnRight) {
		CGRect f = fireArea.frame;
		f.origin.x = 5;
		fireArea.frame = f;
		
		f = stickArea.frame;
		f.origin.x = 475 - f.size.width;
		stickArea.frame = f;
	} else {
		CGRect f = fireArea.frame;
		f.origin.x = 475 - f.size.width;
		fireArea.frame = f;
		
		f = stickArea.frame;
		f.origin.x = 5;
		stickArea.frame = f;
	}
}

- (void)loadViews {
	fireArea = [UIImageView newViewFromImageResource:@"ls-instructions-firearea.png"];
	CGRect f = fireArea.frame;
	f.origin.y = kInfoTop;
	fireArea.frame = f;
	[self addSubview:fireArea];
	
	stickArea = [UIImageView newViewFromImageResource:@"ls-instructions-movearea.png"];
	f = stickArea.frame;
	f.origin.y = kInfoTop;
	stickArea.frame = f;
	[self addSubview:stickArea];
	
	UIView* tmp = [UIImageView newViewFromImageResource:@"ls-instructions-fullscreenarea.png"];
	tmp.center = CGPointMake(240, 270);
	[self addSubview:tmp];
	[tmp release];
}

@end
