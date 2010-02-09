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

#import "JoystickView.h"
#import "debug.h"
#import "C64Defaults.h"

@interface JoystickView()

- (UIImageView*)createViewFromImageNamed:(NSString*)name;
- (void)defaultsChanged:(NSNotification*)notification;

@end


@implementation JoystickView

static const char* joystick_files[] = {
	"idle.png",
	"up.png",
	"right_up.png",
	"right.png",
	"right_down.png",
	"down.png",
	"left_down.png",
	"left.png",
	"left_up.png"
};

static const char* firebutton_files[] = {
	"firebutton.png", "firebutton_active.png"
};

const int kJoystickTop			= 7;

#define FireButtonRect(LEFT)	CGRectMake(LEFT, kJoystickTop, 123, 153)
#define JoystickRect(LEFT)		CGRectMake(LEFT, kJoystickTop-5, 182, 168)

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
		self.userInteractionEnabled = NO;
		
		background = [self createViewFromImageNamed:@"bg.png"];
        [self addSubview:background];

		for (int i = 0; i < sizeof(joystick_files) / sizeof(joystick_files[0]); i++) {
			joystick_images[i] = [[UIImage imageNamed:[NSString stringWithCString:joystick_files[i]]] retain];
		}

		for (int i = 0; i < sizeof(firebutton_files) / sizeof(firebutton_files[0]); i++) {
			firebutton_images[i] = [[UIImage imageNamed:[NSString stringWithCString:firebutton_files[i]]] retain];
		}
		
		fireButton = [[UIImageView alloc] initWithFrame:FireButtonRect(0)];
		fireButton.image = firebutton_images[0];
		[self addSubview:fireButton];

		joystick = [[UIImageView alloc] initWithFrame:JoystickRect(140)];
		joystick.image = joystick_images[0];
		[self addSubview:joystick];
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(defaultsChanged:) 
													 name:NSUserDefaultsDidChangeNotification object:nil];
	}
    return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[fireButton release];
	[joystick release];
    [super dealloc];
}

- (void)defaultsChanged:(NSNotification *)notification {
	[self setNeedsLayout];
}

- (void)layoutSubviews {
	BOOL joystickOnRight = [C64Defaults shared].joystickOnRight;
	CGFloat fbLeft, jsLeft;
	if (joystickOnRight) {
		fbLeft = 0;
		jsLeft = 140;
	} else {
		fbLeft = 200;
		jsLeft = 0;
	}
	
	fireButton.frame = FireButtonRect(fbLeft);
	joystick.frame = JoystickRect(jsLeft);

}

- (UIImageView*)createViewFromImageNamed:(NSString*)name {
	UIImageView *view = [[UIImageView alloc] initWithImage:[UIImage imageNamed:name]];
	return view;
}

- (void)joystickStateChanged:(TouchStickDPadState)state {
	DLog(@"JoystickView state changed: %d", state);
	
	joystick.image = joystick_images[state];
}

- (void)fireButton:(FireButtonState)state {
	DLog(@"JoystickView state changed: %d", state);
	
	fireButton.image = firebutton_images[state];
}

- (void)drawRect:(CGRect)rect {
    // Drawing code
}

@end
