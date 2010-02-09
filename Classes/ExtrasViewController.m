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


#import "ExtrasViewController.h"
#import "MMToolbar.h"
#import "debug.h"
#import "SimpleSettingsViewController.h"
#import "InfoViewController.h"

#define	kToolbarFrame	CGRectMake(0, 5, 320, 20)

@implementation ExtrasViewController

@synthesize content, ss, info;

- (void)viewDidLoad {
    [super viewDidLoad];
	
	NSArray *upImages = [NSArray arrayWithObjects:@"btn_settings_off.png", @"btn_info_off.png", nil];
	NSArray *downImages = [NSArray arrayWithObjects:@"btn_settings_on.png", @"btn_info_on.png", nil];
	MMToolbar *tb = [[MMToolbar alloc] initWithFrame:kToolbarFrame upImages:upImages downImages:downImages];
	tb.delegate = self;
	tb.selectedIndex = 0;
	[self.view addSubview:tb];
	[tb release];
	
	activeController = ss = [[SimpleSettingsViewController alloc] initWithNibName:@"SimpleSettings" bundle:nil];
	[self.content addSubview:ss.view];
}

- (void)changed:(NSUInteger)index {
	DLog(@"changed: %d", index);
	
	UIViewController *disappearing, *appearing;
	
	if (index == 0) {
		appearing		= ss;
		disappearing	= info;
	} else {
		// lazy load the info page
		if (!info) {
			info = [[InfoViewController alloc] init];
		}
		appearing		= info;
		disappearing	= ss;
	}
	
	[disappearing viewWillDisappear:NO];
	[disappearing.view removeFromSuperview];
	[disappearing viewDidDisappear:NO];	
	[appearing viewWillAppear:NO];
	[self.content addSubview:appearing.view];
	[appearing viewDidAppear:NO];
	activeController = appearing;
}

- (void)viewWillDisappear:(BOOL)animated {
	[activeController viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
	[activeController viewDidDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated {
	[activeController viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
	[activeController viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}


- (void)dealloc {
	self.ss = nil;
	self.info = nil;
    [super dealloc];
}


@end
