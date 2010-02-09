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

/*! Specifies whether the full screen mode should display the skin or not
 *	@type		BOOL
 *	@default	YES
 */
#define kSettingFullScreenModeDisplaySkin		@"c64.fullScreenSkin"

/*! Specifies whether the controls are left or right-handed
 *	@type		BOOL
 *	@default	YES
 */
#define kSettingIsJoystickOnRight				@"c64.controls.isJoystickOnRight"
#define kSettingTouchStickDeadZone				@"c64.controls.touchStick.deadZone"

/*! 0 = Floating
 *	1 = Fixed
 *	2 = Tilt
 */
#define kSettingControlsMode					@"c64.controls.mode"

#define kSettingDefaultsVersion					@"c64.defaultsVersion"

/*! Provides easy access to well-known user preferences
 */
@interface C64Defaults : NSObject
{}

+ (C64Defaults*)shared;

@property (nonatomic) BOOL joystickOnRight;
@property (nonatomic) CGFloat touchStickDeadZone;
@property (nonatomic) NSInteger controlsMode;

@end
