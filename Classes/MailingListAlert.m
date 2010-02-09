/*
 Frodo, Commodore 64 emulator for the iPhone
 Copyright (C)	
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


#import "MailingListAlert.h"
#import "DefaultsKeys.h"
#import "SharedBrowserViewController.h"

@interface MailingListAlert()

- (void)checkAndShowAlert:(UIViewController*)controller;

@end

static MailingListAlert *instance;

@implementation MailingListAlert

#pragma mark -
#pragma mark Static Methods

+ (void)tryMailingListAlert:(UIViewController*)controller {
	if (!instance) {
		instance = [MailingListAlert new];
	}
	
	[instance checkAndShowAlert:controller];
}

#pragma mark -
#pragma mark Instance methods

- (void)checkAndShowAlert:(UIViewController*)controller {
	// --------- Remove this after testing
	static BOOL firstTime = YES;
	if (!firstTime) return;
	firstTime = NO;
	// --------- Remove this after testing
	
	_controller = [controller retain];
	// check if this is the first launch
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL hasBeenLaunched = [defaults boolForKey:kdHasBeenLaunched];
	if (hasBeenLaunched) return;

	// --------- TODO: Uncomment this after testing is completed
	// set that we have been launched
	// [defaults setBool:YES forKey:kdHasBeenLaunched];
	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Mailing List" 
													message:@"Want to be notified when new games become available?" 
												   delegate:self 
										  cancelButtonTitle:@"No" 
										  otherButtonTitles:@"Yes", nil];
	[alert show];
	[alert release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == 0) {
		[_controller release];
		return;
	}
	
	SharedBrowserViewController *view = [[SharedBrowserViewController alloc] initWithNibName:@"SharedBrowserViewController" 
																					  bundle:nil
																						 url:[NSURL URLWithString:@"http://c64.manomio.com/index.php/iphone/register/"]];
	
	[_controller presentModalViewController:view animated:YES];
	[view release];
}

@end
