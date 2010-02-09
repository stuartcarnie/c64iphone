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

#import "JoystickViewLandscape.h"
#import "debug.h"
#import "CocoaUtility.h"
#import <QuartzCore/QuartzCore.h>
#import "C64Defaults.h"

@interface JoystickViewLandscape()

- (void)defaultsChanged:(NSNotification*)notification;
- (void)initFromDefaults;

@end

@implementation JoystickViewLandscape

CGFloat	kOffsetFromCentre			= -70.0;
CGFloat kDefaultShowHideDuration	= 50.0 / 1000.0;
CGFloat kDefaultShowRotateDuration	= 500.0 / 1000.0;
CGFloat kDefaultRotateDuration		= 50.0 / 1000.0;
CGFloat kOffsetWhenFixed			= 40.0;
#define degreesToRadian(x)			(M_PI * x / 180.0)


- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        // Initialization code
		self.userInteractionEnabled = YES;
		arrows = [UIImageView newViewFromImageResource:@"ls-bgimage.png"];
		arrows.alpha = 0.0;
		[self addSubview:arrows];
		
		arrowDirection = [UIImageView newViewFromImageResource:@"ls-joystick_active.png"];
		arrowDirection.alpha = 0.0;
		[self addSubview:arrowDirection];
		
		stickCentre = [UIImageView newViewFromImageResource:@"ls-joystick_rest.png"];
		stickCentre.alpha = 0.0;
		[self addSubview:stickCentre];
		
		tracking = NO;
		
		[self initFromDefaults];
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(defaultsChanged:) 
													 name:NSUserDefaultsDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[arrows release];
	[arrowDirection release];
    [super dealloc];
}

- (void)defaultsChanged:(NSNotification*)notification {
	[self initFromDefaults];
}

- (void)initFromDefaults {
	C64Defaults *d = [C64Defaults shared];
	
	controlMode = d.controlsMode;
	switch (controlMode) {
		case 2:
		case 1: {  // fixed
			joystickAlpha = 0.4;
			
			arrows.alpha = joystickAlpha;
			stickCentre.alpha = joystickAlpha;
			arrowDirection.alpha = 0.0;
			tracking = YES;
			
			CGPoint pos = d.joystickOnRight ? CGPointMake(480 - kOffsetWhenFixed, kOffsetWhenFixed) : CGPointMake(kOffsetWhenFixed, kOffsetWhenFixed);
			arrows.center = pos;
			stickCentre.center = pos;
			arrowDirection.center = pos;
			
			currentScale = CGAffineTransformMakeScale(0.5, 0.5);
			arrows.transform = currentScale;
			stickCentre.transform = currentScale;
			arrowDirection.transform = currentScale;
			
			break;
		}
		case 0:
		default:
			arrows.alpha			= 0.0;
			stickCentre.alpha		= 0.0;
			arrowDirection.alpha	= 0.0;
			tracking = NO;
			joystickAlpha = 0.6;
			
			currentScale = CGAffineTransformIdentity;
			arrows.transform = currentScale;
			stickCentre.transform = currentScale;
			arrowDirection.transform = currentScale;
			break;
	}
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	if (controlMode == 0) {	
		tracking = YES;
		
		UITouch *touch = [touches anyObject];
		arrows.center = [touch locationInView:self];
		stickCentre.center = arrows.center;
		arrowDirection.center = arrows.center;
		[UIView beginAnimations:@"show" context:nil];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
		[UIView setAnimationDuration:kDefaultShowHideDuration];
		
		arrows.alpha = joystickAlpha;
		stickCentre.alpha = joystickAlpha;
		
		[UIView commitAnimations];
	}
	
	[super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	[super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	if (controlMode == 0) {
		tracking = NO;
		
		[UIView beginAnimations:@"hide" context:nil];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
		[UIView setAnimationDuration:kDefaultShowHideDuration];
		
		arrows.alpha			= 0.0;
		stickCentre.alpha		= 0.0;
		arrowDirection.alpha	= 0.0;
		
		[UIView commitAnimations];
	}
	
	[super touchesEnded:touches withEvent:event];
}

- (void)joystickStateChanged:(TouchStickDPadState)state {
	if (!tracking)
		return;
	
	bool animate = YES;
	if (state == DPadCenter) {
		arrowDirection.alpha = 0.0;
		stickCentre.alpha = joystickAlpha;
		return;
	} else if (stickCentre.alpha > 0.0) {
		stickCentre.alpha = 0.0;
		arrowDirection.alpha = joystickAlpha;
		// means we were back in the centre position, so don't animate.
		animate = NO;
	}
	
	CGAffineTransform transform = CGAffineTransformMakeTranslation(0, kOffsetFromCentre);
	transform = CGAffineTransformConcat(transform, currentScale);
	
	switch (state) {
		case DPadUpRight:
			transform = CGAffineTransformConcat(transform, CGAffineTransformMakeRotation(degreesToRadian(45)));
			break;
		case DPadRight:
			transform = CGAffineTransformConcat(transform, CGAffineTransformMakeRotation(degreesToRadian(90)));
			break;
		case DPadDownRight:
			transform = CGAffineTransformConcat(transform, CGAffineTransformMakeRotation(degreesToRadian(135)));
			break;
		case DPadDown:
			transform = CGAffineTransformConcat(transform, CGAffineTransformMakeRotation(degreesToRadian(180)));
			break;
		case DPadDownLeft:
			transform = CGAffineTransformConcat(transform, CGAffineTransformMakeRotation(degreesToRadian(225)));
			break;
		case DPadLeft:
			transform = CGAffineTransformConcat(transform, CGAffineTransformMakeRotation(degreesToRadian(270)));
			break;
		case DPadUpLeft:
			transform = CGAffineTransformConcat(transform, CGAffineTransformMakeRotation(degreesToRadian(315)));
			break;
	}
	
	if (animate) {
		[UIView beginAnimations:@"rotate" context:nil];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
		[UIView setAnimationDuration:kDefaultRotateDuration];
	}
	
	arrowDirection.transform = transform;
	arrowDirection.alpha = joystickAlpha;
	
	if (animate)
		[UIView commitAnimations];
}

- (void)fireButton:(FireButtonState)state {
	//fireButton.image = firebutton_images[state];
}

@end
