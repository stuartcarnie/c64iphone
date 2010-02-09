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

#import "C64Defaults.h"

static C64Defaults *g_c64Defaults;

@interface C64Defaults()

- (void)scheduleSynchronize;
- (void)doSynchronize;

@end

@implementation C64Defaults

+ (C64Defaults*)shared {
	if (!g_c64Defaults)
		g_c64Defaults = [C64Defaults new];
	
	return g_c64Defaults;
}

+ (void)initialize {
	if (self != [C64Defaults class]) return;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	//NSString* currentVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
	//NSString* defVersion = [defaults stringForKey:kSettingDefaultsVersion];
	//if ([currentVersion isEqualToString:defVersion]) return;
		
	NSDictionary* resourceDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], kSettingFullScreenModeDisplaySkin, 
								  [NSNumber numberWithBool:NO], kSettingIsJoystickOnRight,
								  [NSNumber numberWithFloat:30.0], kSettingTouchStickDeadZone,
								  [NSNumber numberWithInt:1], kSettingControlsMode,
								  nil];
	
	[defaults registerDefaults:resourceDict];
	
	//[defaults setObject:currentVersion forKey:kSettingDefaultsVersion];
	[defaults synchronize];	
}

#pragma mark -
#pragma mark properties

- (BOOL)joystickOnRight {
	return [[NSUserDefaults standardUserDefaults] boolForKey:kSettingIsJoystickOnRight];
}

- (void)setJoystickOnRight:(BOOL)v {
	[[NSUserDefaults standardUserDefaults] setBool:v forKey:kSettingIsJoystickOnRight];
	[self scheduleSynchronize];
}

- (CGFloat)touchStickDeadZone {
	return [[NSUserDefaults standardUserDefaults] floatForKey:kSettingTouchStickDeadZone];
}

- (void)setTouchStickDeadZone:(CGFloat)v {
	[[NSUserDefaults standardUserDefaults] setFloat:v forKey:kSettingTouchStickDeadZone];
	[self scheduleSynchronize];
}

- (NSInteger)controlsMode {
	return [[NSUserDefaults standardUserDefaults] floatForKey:kSettingControlsMode];
}

- (void)setControlsMode:(NSInteger)v {
	[[NSUserDefaults standardUserDefaults] setInteger:v forKey:kSettingControlsMode];
	[self scheduleSynchronize];
}

#pragma mark -
#pragma mark synchronization

- (void)scheduleSynchronize {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[self performSelector:@selector(doSynchronize) withObject:nil afterDelay:0.5];
}

- (void)doSynchronize {
	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end
