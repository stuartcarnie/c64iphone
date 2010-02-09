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

#import "DebugSupport.h"

@implementation DebugSupport

static DebugSupport *instance;

- (void)promptForDebugger {
	waiting = YES;
	NSString *prompt = [NSString stringWithFormat:@"Attach Debuger, PID %d", getpid()];
	UIAlertView *view = [[UIAlertView alloc] initWithTitle:@"Debug" message:prompt delegate:self cancelButtonTitle:nil otherButtonTitles:@"Ok", nil];
	[view show];
	[view release];
	
	while(waiting) {
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, false);
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	waiting = NO;
}

+ (void)waitForDebugger {
	if (instance == nil) {
		instance = [[DebugSupport alloc] init];
	}
	[instance promptForDebugger];
}

@end
