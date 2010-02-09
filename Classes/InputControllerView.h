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

#import <UIKit/UIKit.h>
#import "CGVector.h"
#import "JoyStick.h"

@protocol InputControllerChangedDelegate

- (void)joystickStateChanged:(TouchStickDPadState)state;
- (void)fireButton:(FireButtonState)state;

@end

@class FireButtonView;

@interface InputControllerView : UIView {
	FireButtonView						*button;
	CGPoint								_stickCenter;
	CGPoint								_stickLocation;
	CGVector2D							*_stickVector;
	BOOL								_trackingStick;
	CJoyStick							*TheJoyStick;
	
	float								_deadZone;		// represents the deadzone radius, where the DPad state will be considered DPadCenter
	
	id<InputControllerChangedDelegate>	delegate;
	
	UIAccelerationValue					*accel;
	BOOL								useAccel;
	BOOL								isLandscape;
}

@property (nonatomic)				BOOL isLandscape;
@property (nonatomic, assign)		id<InputControllerChangedDelegate>	delegate;
@property (nonatomic)				UIAccelerationValue* accel;
@property (nonatomic)				BOOL useAccel;

- (void)setStick;


@end
