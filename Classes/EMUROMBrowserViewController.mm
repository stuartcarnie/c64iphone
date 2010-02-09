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

#import "i64ApplicationDelegate.h"
#import "EMUROMBrowserViewController.h"
#import "EMUBrowser.h"
#import "EMUFileInfo.h"
#import "EMUFileGroup.h"
#import "Frodo.h"
#import "C64.h"
#import "Prefs.h"
#import "GamePack.h"

@implementation EMUROMBrowserViewController

@synthesize roms, selectedIndexPath, indexTitles;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
		// Initialization code
	}
	return self;
}

- (void)viewDidLoad {
	self.title = @"Browser";
	
	self.indexTitles = [NSArray arrayWithObjects:@"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I", 
						@"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V",
						@"W", @"X", @"Y", @"Z", @"#", nil];
	
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	for (int i = 0; i < 26; i++) {
		unichar c = i+65;
		EMUFileGroup *g = [[EMUFileGroup alloc] initWithSectionName:[NSString stringWithFormat:@"%c", c]];
		[sections addObject:g];
	}
	[sections addObject:[[EMUFileGroup alloc] initWithSectionName:@"#"]];
	
	EMUBrowser *browser = [[EMUBrowser alloc] initWithBasePath:@""];
	NSArray *files = [browser getFiles];
	for (EMUFileInfo* f in files) {
		unichar c = [[f fileName] characterAtIndex:0];
		if (isdigit(c)) {
			EMUFileGroup *g = (EMUFileGroup*)[sections objectAtIndex:26];
			[g.files addObject:f];
		} else {
			c = toupper(c) - 65;
			EMUFileGroup *g = (EMUFileGroup*)[sections objectAtIndex:c];
			[g.files addObject:f];
		}
	}
	[browser release];
	self.roms = sections;
}

- (void)viewDidAppear:(BOOL)animated {
	if (!prefs)
		prefs = new Prefs();
	
	prefs->Load(Frodo::prefs_path());
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
	// Release anything that's not essential, such as cached data
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.roms.count;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return indexTitles;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	EMUFileGroup *g = (EMUFileGroup*)[self.roms objectAtIndex:section];
	return g.sectionName;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    unichar c = [title characterAtIndex:0];
	if (c > 64 && c < 91)
		return c - 65;
	
    return 26;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
	EMUFileGroup *g = (EMUFileGroup*)[self.roms objectAtIndex:section];
    return g.files.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath == selectedIndexPath)
		return;
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:self.selectedIndexPath];
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	cell = [tableView cellForRowAtIndexPath:indexPath];
	cell.accessoryType = UITableViewCellAccessoryCheckmark;
	self.selectedIndexPath = indexPath;
	
	[[GamePack globalGamePack] clearCurrentGame];
	
	EMUFileGroup *g = (EMUFileGroup*)[self.roms objectAtIndex:indexPath.section];
	prefs->ChangeRom([[g.files objectAtIndex:indexPath.row] path]);
	prefs->Save(Frodo::prefs_path());
	
	if (Frodo::Instance && Frodo::Instance->TheC64) {
		Prefs *newPrefs = Frodo::reload_prefs();
		Frodo::Instance->TheC64->NewPrefs(newPrefs);
		ThePrefs = *newPrefs;
	}
	
	if (prefs->AutoBoot) {
		if (Frodo::Instance && Frodo::Instance->TheC64)
			Frodo::Instance->TheC64->ResetAndAutoboot();
		else
			Frodo::AutoBoot = true;
		[g_application launchEmulator];
	}
}

#define CELL_ID @"DiskCell"

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CELL_ID];
	if (cell == nil)
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CELL_ID] autorelease];
	
    cell.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	if ([indexPath compare:self.selectedIndexPath] == NSOrderedSame)
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	else
		cell.accessoryType = UITableViewCellAccessoryNone;
	
	EMUFileGroup *g = (EMUFileGroup*)[self.roms objectAtIndex:indexPath.section];
	cell.textLabel.text = [(EMUFileInfo *)[g.files objectAtIndex:indexPath.row] fileName];
	
    return cell;
}


- (void)dealloc {
	if (prefs)
		delete prefs;
	
	self.roms = nil;
	self.indexTitles = nil;
	self.selectedIndexPath = nil;
	[super dealloc];
}


@end
