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

#import "ControlsToolbarView.h"
#import "CocoaUtility.h"

#import "debug.h"

@interface ControlsToolbarView()
- (void)ensureGameModeButtons;
- (void)ensureStandardModeButtons;
- (UIButton*)createToolButtonWithImage:(NSString*)imageName andSelectedImage:(NSString*)selectedImageName;
- (CGSize)getSizeFromImage:(UIButton*)button;
- (void)frameButton:(UIButton*)button atX:(float*)x;
- (void)unsetAllButtons;
@end

@implementation ControlsToolbarView

const double kButtonYPosition = 0.0;

@synthesize delegate, state, showGameMode;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    return self;
}

- (void)frameButton:(UIButton*)button atX:(float*)x {
	CGSize buttonSize = [self getSizeFromImage:button];
	button.frame = CGRectMake(*x, kButtonYPosition, buttonSize.width, buttonSize.height);
	*x += buttonSize.width;
}

- (void)layoutSubviews {
	float totalWidth = 0;
	for(UIButton* button in currentButtons)
		totalWidth += [self getSizeFromImage:button].width;
		
	float startX = (self.frame.size.width / 2.0) - (totalWidth / 2.0);
	for(UIButton* button in currentButtons)
		[self frameButton:button atX:&startX];
}

- (void)setShowGameMode:(BOOL)value {
	showGameMode = value;
	if (value) {
		buttonAlpha.hidden		= YES;
		buttonNumeric.hidden	= YES;
		buttonFunction.hidden	= YES;
		
		buttonControls.hidden	= NO;
		
		[self ensureGameModeButtons];
	} else {
		buttonControls.hidden	= YES;

		buttonAlpha.hidden		= NO;
		buttonNumeric.hidden	= NO;
		buttonFunction.hidden	= NO;
		
		[self ensureStandardModeButtons];
	}

	[self setNeedsLayout];
}

- (IBAction)selected:(UIButton*)sender {
	[self unsetAllButtons];

	sender.selected = YES;
	state = (ControlsToolbarState)sender.tag;
	
	[delegate changed];
}

- (void)unsetAllButtons {
	if (showGameMode) {
		buttonControls.selected = NO;
	} else {
		// deselect current buttons
		buttonAlpha.selected	= NO;
		buttonNumeric.selected	= NO;
		buttonFunction.selected = NO;
	}
	
	buttonJoystick.selected	= NO;		
}

- (void)setState:(ControlsToolbarState)value {
	if (state == value)
		return;
	
	[self unsetAllButtons];
	state = value;
	switch (state) {
		case ControlsStateAlpha:
			if (showGameMode)
				buttonControls.selected = YES;
			else
				buttonAlpha.selected = YES;
			break;
			
		case ControlsStateJoystick:
			buttonJoystick.selected = YES;
			break;
			
		case ControlsStateNumeric:
			buttonNumeric.selected = YES;
			break;
			
		case ControlsStateFunction:
			buttonFunction.selected = YES;
			break;
	}
}

- (void)ensureGameModeButtons {
	state = ControlsStateAlpha;
	showGameMode = YES;
	if (!buttonControls) {
		buttonControls = [self createToolButtonWithImage:@"btn_controls.png" andSelectedImage:@"btn_controls_active.png"];
		buttonControls.tag = ControlsStateAlpha;	
		buttonControls.selected = YES;
	}

	if (!buttonJoystick) {
		buttonJoystick = [self createToolButtonWithImage:@"joystick.png" andSelectedImage:@"joystick_active.png"];
		buttonJoystick.tag = ControlsStateJoystick;
	}
	
	[currentButtons release];
	currentButtons = [[NSArray arrayWithObjects:buttonControls, buttonJoystick, nil] retain];
}

- (void)ensureStandardModeButtons {
	state = ControlsStateAlpha;
	showGameMode = NO;
	if (!buttonAlpha) {
		buttonAlpha = [self createToolButtonWithImage:@"alpha.png" andSelectedImage:@"alpha_active.png"];
		buttonAlpha.tag = ControlsStateAlpha;
		buttonAlpha.selected = YES;
	}
	
	if (!buttonNumeric) {
		buttonNumeric = [self createToolButtonWithImage:@"numeric.png" andSelectedImage:@"numeric_active.png"];
		buttonNumeric.tag = ControlsStateNumeric;
	}
	
	if (!buttonFunction) {
		buttonFunction = [self createToolButtonWithImage:@"extra.png" andSelectedImage:@"extra_active.png"];
		buttonFunction.tag = ControlsStateFunction;
	}
	
	if (!buttonJoystick) {
		buttonJoystick = [self createToolButtonWithImage:@"joystick.png" andSelectedImage:@"joystick_active.png"];
		buttonJoystick.tag = ControlsStateJoystick;
	}	

	[currentButtons release];
	currentButtons = [[NSArray arrayWithObjects:buttonAlpha, buttonNumeric, buttonFunction, buttonJoystick, nil] retain];
}

const int UIControlStateAllNormal = (UIControlStateNormal | UIControlStateHighlighted | UIControlStateDisabled);

- (UIButton*)createToolButtonWithImage:(NSString*)imageName andSelectedImage:(NSString*)selectedImageName {
	UIButton *view = [UIButton buttonWithType:UIButtonTypeCustom];
	[view setImage:[UIImage imageFromResource:imageName] forState:UIControlStateNormal];
	[view setImage:[UIImage imageFromResource:selectedImageName] forState:UIControlStateSelected];
	[view addTarget:self action:@selector(selected:) forControlEvents:UIControlEventTouchUpInside];
	[self addSubview:view];
	return view;
}

- (CGSize)getSizeFromImage:(UIButton*)button {
	return button.currentImage.size;
}

- (void)dealloc {
	[buttonAlpha release];
	[buttonNumeric release];
	[buttonFunction release];
	[buttonJoystick release];
	[buttonControls release];
	
    [super dealloc];
}

@end
